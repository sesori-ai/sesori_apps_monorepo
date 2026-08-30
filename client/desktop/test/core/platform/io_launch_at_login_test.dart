import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/desktop_launch_arguments.dart";
import "package:sesori_desktop/core/platform/io_launch_at_login.dart";

void main() {
  group("IoLaunchAtLogin", () {
    late Directory temporaryDirectory;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp("sesori-launch-at-login-");
    });

    tearDown(() async {
      await temporaryDirectory.delete(recursive: true);
    });

    test("macOS writes one launch agent with the hidden argument and removes it", () async {
      final _FakeMacOSLaunchctl launchctl = _FakeMacOSLaunchctl(loaded: false);
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: true,
        isWindows: false,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        executablePath: "${temporaryDirectory.path}/Sesori & Tools.app/Contents/MacOS/Sesori",
        userId: "501",
        runProcess: launchctl.run,
      );

      await launchAtLogin.enable();
      await launchAtLogin.enable();

      final File registration = File(
        "${temporaryDirectory.path}/Library/LaunchAgents/com.sesori.desktop.plist",
      );
      final String contents = await registration.readAsString();
      expect(await launchAtLogin.isEnabled(), isTrue);
      expect(contents, contains("<string>--hidden</string>"));
      expect(contents, contains("Sesori &amp; Tools.app"));
      expect(registration.parent.listSync().whereType<File>(), hasLength(1));

      await launchAtLogin.disable();
      expect(await launchAtLogin.isEnabled(), isFalse);
    });

    test("macOS unloads a loaded launch agent before deleting its registration", () async {
      final _FakeMacOSLaunchctl launchctl = _FakeMacOSLaunchctl(loaded: true);
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: true,
        isWindows: false,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        executablePath: "${temporaryDirectory.path}/Sesori",
        userId: "501",
        runProcess: launchctl.run,
      );

      await launchAtLogin.enable();
      await launchAtLogin.disable();

      expect(launchctl.commands, <List<String>>[
        <String>["print", "gui/501/com.sesori.desktop"],
        <String>["bootout", "gui/501/com.sesori.desktop"],
      ]);
      expect(await launchAtLogin.isEnabled(), isFalse);
    });

    test("Linux writes one quoted XDG autostart entry and removes it", () async {
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: false,
        isLinux: true,
        homeDirectory: temporaryDirectory.path,
        executablePath: "${temporaryDirectory.path}/Sesori Desktop",
        userId: "501",
        runProcess: _unusedProcessRunner,
      );

      await launchAtLogin.enable();
      await launchAtLogin.enable();

      final File registration = File(
        "${temporaryDirectory.path}/.config/autostart/com.sesori.desktop.desktop",
      );
      final String contents = await registration.readAsString();
      expect(await launchAtLogin.isEnabled(), isTrue);
      expect(contents, contains('Exec="${temporaryDirectory.path}/Sesori Desktop" "--hidden"'));
      expect(registration.parent.listSync().whereType<File>(), hasLength(1));

      await launchAtLogin.disable();
      expect(await launchAtLogin.isEnabled(), isFalse);
    });

    test("a stale file is disabled until enable replaces its executable", () async {
      final File registration = File(
        "${temporaryDirectory.path}/.config/autostart/com.sesori.desktop.desktop",
      );
      await registration.parent.create(recursive: true);
      await registration.writeAsString("stale registration");
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: false,
        isLinux: true,
        homeDirectory: temporaryDirectory.path,
        executablePath: "${temporaryDirectory.path}/Sesori",
        userId: "501",
        runProcess: _unusedProcessRunner,
      );

      expect(await launchAtLogin.isEnabled(), isFalse);
      await launchAtLogin.enable();
      expect(await launchAtLogin.isEnabled(), isTrue);
      expect(await registration.readAsString(), contains(desktopHiddenLaunchArgument));
    });

    test("disabling Windows removes a stale Run value", () async {
      final _FakeWindowsRegistry registry = _FakeWindowsRegistry()..value = r'"C:\old\Sesori.exe" --hidden';
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        executablePath: r"C:\Program Files\Sesori\Sesori.exe",
        userId: "501",
        runProcess: registry.run,
      );

      await launchAtLogin.disable();

      expect(registry.value, isNull);
      expect(registry.deleteCalls, 1);
    });

    test("Windows owns one Run value containing the hidden argument", () async {
      final _FakeWindowsRegistry registry = _FakeWindowsRegistry();
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        executablePath: r"C:\Program Files\Sesori\Sesori.exe",
        userId: "501",
        runProcess: registry.run,
      );

      expect(await launchAtLogin.isEnabled(), isFalse);
      await launchAtLogin.enable();
      await launchAtLogin.enable();

      expect(await launchAtLogin.isEnabled(), isTrue);
      expect(registry.value, r'"C:\Program Files\Sesori\Sesori.exe" --hidden');
      expect(registry.addCalls, 1);

      await launchAtLogin.disable();
      await launchAtLogin.disable();
      expect(await launchAtLogin.isEnabled(), isFalse);
      expect(registry.deleteCalls, 1);
    });
  });
}

Future<ProcessResult> _unusedProcessRunner({required String executable, required List<String> arguments}) =>
    throw StateError("The process runner must not be used");

class _FakeMacOSLaunchctl({required final bool loaded}) {
  final List<List<String>> commands = <List<String>>[];

  Future<ProcessResult> run({required String executable, required List<String> arguments}) async {
    expect(executable, "launchctl");
    commands.add(arguments);
    if (arguments.first == "print") {
      return ProcessResult(1, loaded ? 0 : 113, "", loaded ? "" : "Could not find service");
    }
    return ProcessResult(1, 0, "", "");
  }
}

class _FakeWindowsRegistry() {
  String? value;
  int addCalls = 0;
  int deleteCalls = 0;

  Future<ProcessResult> run({required String executable, required List<String> arguments}) async {
    expect(executable, "reg.exe");
    switch (arguments.first) {
      case "QUERY":
        final String? stored = value;
        return ProcessResult(1, stored == null ? 1 : 0, stored == null ? "" : "REG_SZ    $stored", "");
      case "ADD":
        addCalls++;
        value = arguments[arguments.indexOf("/d") + 1];
        return ProcessResult(1, 0, "", "");
      case "DELETE":
        deleteCalls++;
        value = null;
        return ProcessResult(1, 0, "", "");
    }
    throw StateError("Unexpected registry command: ${arguments.first}");
  }
}
