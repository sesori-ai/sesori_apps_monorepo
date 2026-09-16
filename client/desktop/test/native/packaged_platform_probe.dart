// CI-only release fixture. Never initialize account, bridge or session services.
import "dart:io";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop/core/di/register_module.dart";
import "package:sesori_desktop/core/platform/io_launch_at_login.dart";
import "package:window_manager/window_manager.dart";

enum _ProbePhase() {
  write,
  read,
}

class _ProbeModule() extends RegisterModule;

Future<void> main() async {
  if (!Platform.isMacOS || Platform.environment["GITHUB_ACTIONS"] != "true") {
    throw StateError("This fixture may only run on an isolated macOS Actions runner");
  }
  final String output = Platform.environment["SESORI_PACKAGED_PROBE_OUTPUT"]!;
  final _ProbePhase phase = _ProbePhase.values.byName(Platform.environment["SESORI_PACKAGED_PROBE_PHASE"]!);
  final File report = File(output);
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    runApp(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text("Sesori packaged platform probe"))),
      ),
    );
    await windowManager.show();
    await WidgetsBinding.instance.endOfFrame;

    final FlutterSecureStorage storage = _ProbeModule().secureStorage;
    const String key = "sesori-distribution-ci-probe";
    switch (phase) {
      case _ProbePhase.write:
        _require(
          condition: await storage.read(key: key) == null,
          message: "Fixture key already exists",
        );
        await storage.write(key: key, value: "first");
        _require(
          condition: await storage.read(key: key) == "first",
          message: "Keychain write/read failed",
        );
        await storage.write(key: key, value: "persisted");
        await report.writeAsString("PASS Keychain write/read/update; awaiting a second process\n");
      case _ProbePhase.read:
        _require(
          condition: await storage.read(key: key) == "persisted",
          message: "Keychain relaunch read failed",
        );
        await storage.delete(key: key);
        _require(
          condition: await storage.read(key: key) == null,
          message: "Keychain delete failed",
        );
        final IoLaunchAtLogin login = IoLaunchAtLogin();
        await login.enable();
        try {
          _require(condition: await login.isEnabled(), message: "Login registration readback failed");
        } finally {
          await login.disable();
        }
        _require(condition: !await login.isEnabled(), message: "Login registration cleanup failed");
        final File data = File("${report.parent.path}/owned-file-probe");
        await data.writeAsString("owned fixture data");
        _require(condition: await data.readAsString() == "owned fixture data", message: "File readback failed");
        await data.delete();
        await report.writeAsString("PASS Keychain relaunch/delete, login registration and owned file access\n");
    }
    exit(0); // Fixture-only exit: no supervised helper or production Quit claim.
  } on Object catch (error, stackTrace) {
    await report.writeAsString("FAIL $error\n$stackTrace\n");
    exit(1);
  }
}

void _require({required bool condition, required String message}) {
  if (!condition) {
    throw StateError(message);
  }
}
