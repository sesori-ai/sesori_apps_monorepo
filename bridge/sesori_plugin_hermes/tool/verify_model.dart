// Temporary live verification: confirm the Hermes model surfaces in providers.
// Run: dart run tool/verify_model.dart  (inside sesori_plugin_hermes)
import "dart:io";

import "package:acp_plugin/acp_plugin.dart";
import "package:hermes_plugin/hermes_plugin.dart";

Future<void> main() async {
  final plugin = HermesPlugin(
    binaryPath: _resolveBin(),
    launchDirectory: Directory.current.path,
    processFactory: defaultAcpProcessFactory,
  );
  try {
    final ok = await plugin.ensureConnected().timeout(const Duration(seconds: 90));
    if (!ok) {
      stdout.writeln("VERIFY: connect=false (handshake/auth failed)");
      exit(1);
    }
    stdout.writeln("connected");
    final created = await plugin
        .createSession(
          directory: Directory.current.path,
          parentSessionId: null,
          parts: const [],
          userVisibleText: null,
          variant: null,
          agent: null,
          model: null,
        )
        .timeout(const Duration(seconds: 60));
    stdout.writeln("session created: ${created.id}");
    final providers = await plugin.getProviders(projectId: Directory.current.path);
    for (final p in providers.providers) {
      stdout.writeln("provider=${p.id} defaultModel=${p.defaultModelID}");
      for (final m in p.models) {
        stdout.writeln("   model id=${m.id} name=${m.name} available=${m.isAvailable}");
      }
    }
    final nonEmpty = providers.providers.any((p) => p.models.isNotEmpty);
    stdout.writeln(nonEmpty
        ? "VERIFY: PASS — Hermes model(s) surfaced in providers"
        : "VERIFY: FAIL — providers empty");
    if (!nonEmpty) exit(1);
  } finally {
    await plugin.dispose();
  }
}

String _resolveBin() {
  final env = Platform.environment;
  final home = env["HOME"] ?? "";
  final candidate = "$home/.local/bin/hermes";
  return File(candidate).existsSync() ? candidate : "hermes";
}
