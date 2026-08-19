// Live end-to-end smoke test for the Hermes Agent backend over ACP.
//
// Drives the REAL `hermes acp` binary through HermesPlugin: real ACP
// handshake, real session creation, a real prompt turn that must stream live
// text deltas, then a single history replay fetch. Exit code 0 = PASS.
//
// Run:
//   dart run tool/live_smoke_test.dart [--bin <hermes path>] [--cwd <dir>]
import "dart:async";
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

const String _prompt = "Reply with exactly this token and nothing else: SESORI-E2E-ACK";

Future<void> main(List<String> args) async {
  String bin = HermesBinary.defaultBinary;
  String? cwd;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == "--bin" && i + 1 < args.length) {
      bin = args[i + 1];
      i++;
    } else if (args[i] == "--cwd" && i + 1 < args.length) {
      cwd = args[i + 1];
      i++;
    } else {
      bin = args[i];
    }
  }
  final workdir = cwd ?? Directory.current.path;

  stdout.writeln("[smoke] binary=$bin cwd=$workdir prompt='$_prompt'");
  final plugin = HermesPlugin(
    binaryPath: bin,
    launchDirectory: workdir,
    processFactory: defaultAcpProcessFactory,
  );

  final events = <BridgeSseEvent>[];
  final sub = plugin.events.listen(events.add);
  final failures = <String>[];

  try {
    // 1. Real ACP handshake (initialize + authenticate against configured provider).
    stdout.writeln("[smoke] connecting to real hermes acp...");
    final ok = await plugin
        .ensureConnected()
        .timeout(const Duration(seconds: 90));
    if (!ok) {
      failures.add("ACP ensureConnected() returned false (handshake/auth failed)");
      _finish(failures);
      return;
    }
    stdout.writeln("[smoke] ACP handshake succeeded");
    stdout.writeln("[smoke] events after connect: ${events.length}");

    // 2. Real session creation with the prompt as its first (and only) turn.
    stdout.writeln("[smoke] creating session + dispatching prompt...");
    final created = await plugin
        .createSession(
          directory: workdir,
          parentSessionId: null,
          parts: const [PluginPromptPart.text(text: _prompt)],
          userVisibleText: _prompt,
          variant: null,
          agent: null,
          model: null,
        )
        .timeout(const Duration(seconds: 60));
    stdout.writeln("[smoke] session created: ${created.id}");

    // 3. Settle from the LIVE event stream: >=1 part delta, then a quiet
    //    window with no new deltas (never poll getSessionMessages in a loop).
    stdout.writeln("[smoke] awaiting live streaming + settlement...");
    final settled = await _settleFromEvents(events, timeout: const Duration(seconds: 240));
    stdout.writeln("[smoke] settlement=$settled (total events=${events.length})");

    final deltas = events.whereType<BridgeSseMessagePartDelta>().toList();
    final streamed = deltas.map((e) => e.delta).join();
    stdout.writeln("[smoke] part-delta events=${deltas.length} streamedText='${streamed.trim()}'");

    if (deltas.isEmpty) {
      failures.add("no live BridgeSseMessagePartDelta events streamed (broken streaming path)");
    }
    if (settled == "timeout") {
      failures.add("turn did not settle from live stream within timeout");
    }

    // 4. History replay via getSessionMessages (one fetch, fresh replay client).
    stdout.writeln("[smoke] fetching history via session replay...");
    final messages = await plugin
        .getSessionMessages(created.id)
        .timeout(const Duration(minutes: 3));
    final textParts = <String>[];
    for (final m in messages) {
      for (final p in m.parts) {
        final t = p.text;
        if (t != null && p.type == PluginMessagePartType.text) textParts.add(t);
      }
    }
    final historyText = textParts.join("\n");
    stdout.writeln("[smoke] history messages=${messages.length} textParts=${textParts.length}");
    stdout.writeln("[smoke] history text:\n$historyText");

    if (!historyText.contains("SESORI-E2E-ACK")) {
      failures.add(
          "history replay did not contain the expected token 'SESORI-E2E-ACK'");
    }
    if (streamed.isEmpty || !streamed.contains("SESORI-E2E-ACK")) {
      failures.add("live streamed text was empty or missing the expected token");
    }

    _finish(failures);
  } on Object catch (e, st) {
    failures.add("exception: $e\n$st");
    _finish(failures);
  } finally {
    await sub.cancel();
    try {
      await plugin.dispose();
    } on Object catch (e) {
      stdout.writeln("[smoke] dispose warning: $e");
    }
  }
}

/// Returns "settled" once a part delta is seen followed by a [quiet] window,
/// or "timeout" if [timeout] elapses.
Future<String> _settleFromEvents(
  List<BridgeSseEvent> events, {
  required Duration timeout,
  Duration quiet = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  DateTime? lastDeltaSeen;
  while (DateTime.now().isBefore(deadline)) {
    final hasDelta = events.whereType<BridgeSseMessagePartDelta>().isNotEmpty;
    if (hasDelta) {
      // A delta exists. Once none arrive for `quiet`, the turn has settled.
      lastDeltaSeen ??= DateTime.now();
      if (DateTime.now().difference(lastDeltaSeen) >= quiet) return "settled";
    } else {
      lastDeltaSeen = null;
    }
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return "timeout";
}

void _finish(List<String> failures) {
  if (failures.isEmpty) {
    stdout.writeln("RESULT: PASS — Hermes Agent over Sesori ACP works end-to-end (live)");
    exit(0);
  } else {
    stdout.writeln("RESULT: FAIL");
    for (final f in failures) {
      stdout.writeln("  - $f");
    }
    exit(1);
  }
}
