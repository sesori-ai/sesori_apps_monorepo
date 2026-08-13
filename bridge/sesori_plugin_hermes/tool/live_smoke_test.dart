// Live end-to-end smoke test for the Hermes plugin.
//
// Drives the REAL `hermes acp` binary through HermesPlugin — no fakes, no
// injected process factories. Proves the wire contract end to end: ACP
// handshake (initialize + authenticate), session creation, a real prompt
// turn against the user's configured provider, streamed events, and history
// replay via session/load.
//
// Run from bridge/sesori_plugin_hermes/:
//   dart run tool/live_smoke_test.dart [--bin /path/to/hermes] [--cwd /dir]
//
// Exit code 0 = PASS. Requires a configured Hermes install (hermes setup /
// hermes model must point at a working provider); makes one real LLM call.

import "dart:async";
import "dart:io";

import "package:hermes_plugin/hermes_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

Future<void> main(List<String> args) async {
  var bin = "hermes";
  var cwd = Directory.current.path;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == "--bin" && i + 1 < args.length) bin = args[i + 1];
    if (args[i] == "--cwd" && i + 1 < args.length) cwd = args[i + 1];
  }
  stdout.writeln("== hermes live smoke test ==");
  stdout.writeln("binary: $bin");
  stdout.writeln("cwd:    $cwd");

  final plugin = HermesPlugin(binaryPath: bin, launchDirectory: cwd);
  final events = <BridgeSseEvent>[];
  final subscription = plugin.events.listen(events.add);

  try {
    // 1. ACP handshake (initialize + authenticate).
    stdout.writeln("[1] connecting to `$bin acp` ...");
    final connected = await plugin
        .ensureConnected()
        .timeout(const Duration(seconds: 90));
    if (!connected) {
      stderr.writeln("FAIL: handshake returned false");
      exitCode = 1;
      return;
    }
    stdout.writeln("    connected");

    // 2. Create a session.
    stdout.writeln("[2] creating session ...");
    final session = await plugin
        .createSession(
          directory: cwd,
          parentSessionId: null,
          parts: const [],
          userVisibleText: null,
          variant: null,
          agent: null,
          model: null,
        )
        .timeout(const Duration(seconds: 30));
    stdout.writeln("    session id: ${session.id}");

    // 3. Send a real prompt (one LLM call against the configured provider).
    stdout.writeln("[3] sending prompt ...");
    await plugin
        .sendPrompt(
          sessionId: session.id,
          parts: const [PluginPromptPart.text(text: "Reply with exactly: OK")],
          variant: null,
          agent: null,
          model: null,
        )
        .timeout(const Duration(seconds: 180));
    stdout.writeln("    prompt accepted");

    // 4. Let streamed deltas settle, then fetch the final history (replay
    //    via a fresh `session/load` client — the same path getSessionMessages
    //    uses on the phone).
    await Future<void>.delayed(const Duration(seconds: 3));
    final messages = await plugin
        .getSessionMessages(session.id)
        .timeout(const Duration(seconds: 90));
    stdout.writeln("[4] session messages: ${messages.length}");
    for (final entry in messages) {
      final role = switch (entry.info) {
        PluginMessageUser() => "user",
        PluginMessageAssistant() => "assistant",
        _ => "error",
      };
      final text = entry.parts.map((part) => part.text ?? "").join().trim();
      stdout.writeln("    - $role: ${text.isEmpty ? "(no text)" : text}");
    }
    final assistantText = messages
        .where((entry) => entry.info is PluginMessageAssistant)
        .map((entry) => entry.parts.map((part) => part.text ?? "").join())
        .join(" ");
    if (assistantText.trim().isEmpty) {
      stderr.writeln("FAIL: no assistant text in replayed history");
      exitCode = 1;
    } else if (!assistantText.toLowerCase().contains("ok")) {
      stderr.writeln("FAIL: assistant reply did not match the requested 'OK' (got: ${assistantText.trim()})");
      exitCode = 1;
    } else {
      stdout.writeln("    assistant reply present");
    }

    // 5. Live event summary (what the phone would have received).
    final partDeltas = events.whereType<BridgeSseMessagePartDelta>().length;
    final messageUpdates = events.whereType<BridgeSseMessageUpdated>().length;
    final partUpdates = events.whereType<BridgeSseMessagePartUpdated>().length;
    stdout.writeln(
      "[5] live events: ${events.length} total "
      "($messageUpdates message envelopes, $partDeltas part deltas, $partUpdates part updates)",
    );
    if (events.isEmpty) {
      stderr.writeln("FAIL: no live SSE events were delivered (streaming path broken)");
      exitCode = 1;
    } else if (partDeltas == 0) {
      stderr.writeln("FAIL: no streamed part deltas were delivered");
      exitCode = 1;
    } else {
      stdout.writeln("    live streaming delivered");
    }
  } on TimeoutException catch (error) {
    stderr.writeln("FAIL: timeout — $error");
    exitCode = 1;
  } on Object catch (error, stack) {
    stderr.writeln("FAIL: $error");
    stderr.writeln("$stack");
    exitCode = 1;
  } finally {
    await subscription.cancel();
    await plugin.dispose();
    stdout.writeln(exitCode == 0 ? "PASS" : "FAILED");
  }
}
