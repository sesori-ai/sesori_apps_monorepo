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
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: true,
        isWindows: false,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: "${temporaryDirectory.path}/Sesori & Tools.app/Contents/MacOS/Sesori",
        windowsValueReader: _unusedWindowsValueReader,
        runProcess: _unusedProcessRunner,
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

    test("macOS disables login without booting out the current app", () async {
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: true,
        isWindows: false,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: "${temporaryDirectory.path}/Sesori",
        windowsValueReader: _unusedWindowsValueReader,
        runProcess: _unusedProcessRunner,
      );

      await launchAtLogin.enable();
      await launchAtLogin.disable();

      expect(await launchAtLogin.isEnabled(), isFalse);
    });

    test("Linux writes one quoted XDG autostart entry and removes it", () async {
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: false,
        isLinux: true,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: "${temporaryDirectory.path}/Sesori Desktop",
        windowsValueReader: _unusedWindowsValueReader,
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

    test("Linux honors XDG_CONFIG_HOME for autostart registration", () async {
      final String xdgConfigHome = "${temporaryDirectory.path}/xdg-config";
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: false,
        isLinux: true,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: xdgConfigHome,
        executablePath: "${temporaryDirectory.path}/Sesori",
        windowsValueReader: _unusedWindowsValueReader,
        runProcess: _unusedProcessRunner,
      );

      await launchAtLogin.enable();

      expect(
        File("$xdgConfigHome/autostart/com.sesori.desktop.desktop").existsSync(),
        isTrue,
      );
      expect(
        File("${temporaryDirectory.path}/.config/autostart/com.sesori.desktop.desktop").existsSync(),
        isFalse,
      );
    });

    test("Linux escapes percent field codes in autostart paths", () async {
      final String executablePath = "${temporaryDirectory.path}/Sesori %f";
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: false,
        isLinux: true,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: executablePath,
        windowsValueReader: _unusedWindowsValueReader,
        runProcess: _unusedProcessRunner,
      );

      await launchAtLogin.enable();

      final File registration = File(
        "${temporaryDirectory.path}/.config/autostart/com.sesori.desktop.desktop",
      );
      expect(await registration.readAsString(), contains('Exec="${temporaryDirectory.path}/Sesori %%f" "--hidden"'));
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
        xdgConfigHome: null,
        executablePath: "${temporaryDirectory.path}/Sesori",
        windowsValueReader: _unusedWindowsValueReader,
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
        xdgConfigHome: null,
        executablePath: r"C:\Program Files\Sesori\Sesori.exe",
        windowsValueReader: registry.readValue,
        runProcess: registry.run,
      );

      await launchAtLogin.disable();

      expect(registry.value, isNull);
      expect(registry.deleteCalls, 1);
    });

    test("Windows surfaces registry query failures", () async {
      final _FakeWindowsRegistry registry = _FakeWindowsRegistry();
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: r"C:\Program Files\Sesori\Sesori.exe",
        windowsValueReader: _throwingWindowsValueReader,
        runProcess: registry.run,
      );

      await expectLater(launchAtLogin.isEnabled(), throwsA(isA<StateError>()));
      await expectLater(launchAtLogin.disable(), throwsA(isA<StateError>()));
      expect(registry.deleteCalls, 0);
    });

    test("Windows owns one Run value containing the hidden argument", () async {
      final _FakeWindowsRegistry registry = _FakeWindowsRegistry();
      final IoLaunchAtLogin launchAtLogin = IoLaunchAtLogin.forTesting(
        isMacOS: false,
        isWindows: true,
        isLinux: false,
        homeDirectory: temporaryDirectory.path,
        xdgConfigHome: null,
        executablePath: r"C:\Program Files\Sesori\Sesori.exe",
        windowsValueReader: registry.readValue,
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

String? _unusedWindowsValueReader() => throw StateError("The Windows registry reader must not be used");

String? _throwingWindowsValueReader() => throw StateError("The Windows registry query failed");

class _FakeWindowsRegistry() {
  String? value;
  int addCalls = 0;
  int deleteCalls = 0;

  String? readValue() => value;

  Future<ProcessResult> run({required String executable, required List<String> arguments}) async {
    expect(executable, "reg.exe");
    switch (arguments.first) {
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
