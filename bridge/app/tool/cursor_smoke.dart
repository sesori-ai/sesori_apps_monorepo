// Local smoke test for the Cursor backend. Drives CursorPlugin directly
// against a real `agent acp` — no relay, no Sesori account needed.
//
// Prereqs: the Cursor CLI (`agent`) on PATH, authenticated (`agent login`),
// and recent enough to expose the `acp` subcommand (`agent update`).
//
// Usage:
//   dart run tool/cursor_smoke.dart "Reply with exactly: hello world"
import "dart:io";

import "package:cursor_plugin/cursor_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

Future<void> main(List<String> args) async {
  final prompt = args.isEmpty ? "Reply with exactly: hello world" : args.first;
  final cwd = Directory.current.path;
  final plugin = CursorPlugin(
    launchDirectory: cwd,
    sessionCleanupService: CursorSessionCleanupService(
      repository: CursorSessionStorageRepository(
        api: const CursorSessionStorageApi(),
      ),
      environment: Platform.environment,
      isWindows: Platform.isWindows,
    ),
  );
  final assistant = StringBuffer();

  plugin.events.listen((e) {
    if (e is BridgeSseMessagePartDelta) assistant.write(e.delta);
    if (e is BridgeSsePermissionAsked) {
      stdout.writeln("[permission asked] ${e.tool}: ${e.description}");
    }
    if (e is BridgeSseQuestionAsked) {
      stdout.writeln("[question asked] ${e.questions}");
    }
  });

  stdout.writeln("healthCheck: ${await plugin.healthCheck()}");

  final session = await plugin.createSession(
    directory: cwd,
    parentSessionId: null,
    parts: [PluginPromptPart.text(text: prompt)],
    variant: null,
    agent: null,
    model: null,
  );
  stdout.writeln("session: ${session.id}");

  // Wait for the turn to finish (status flips back to idle).
  final statuses = await _waitIdle(plugin, session.id, const Duration(seconds: 90));
  stdout.writeln("status: $statuses");
  stdout.writeln("assistant: ${assistant.toString().trim()}");

  final agents = await plugin.getAgents(projectId: cwd);
  stdout.writeln("agents: ${agents.map((a) => '${a.name} (${a.model?.modelID})').toList()}");
  final providers = await plugin.getProviders(projectId: cwd);
  stdout.writeln(
    "providers: ${providers.providers.length}, "
    "models: ${providers.providers.isEmpty ? 0 : providers.providers.first.models.length}",
  );

  await plugin.dispose();
  exit(0);
}

Future<String> _waitIdle(BridgePluginApi plugin, String sessionId, Duration timeout) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final statuses = await plugin.getSessionStatuses();
    final status = statuses[sessionId];
    if (status is PluginSessionStatusIdle) return "idle";
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return "timeout";
}
