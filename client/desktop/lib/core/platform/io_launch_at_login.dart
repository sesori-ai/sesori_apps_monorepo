import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";

import "desktop_launch_arguments.dart";

@visibleForTesting
typedef LaunchAtLoginProcessRunner = Future<ProcessResult> Function({
  required String executable,
  required List<String> arguments,
});

/// Per-user login registration for the three desktop platforms.
///
/// macOS and Linux use one fixed registration file; Windows uses one fixed
/// value under the current user's Run key. Re-enabling therefore replaces the
/// same registration instead of accumulating duplicates. Every registration
/// launches this exact executable with [desktopHiddenLaunchArgument].
@LazySingleton(as: LaunchAtLogin)
class IoLaunchAtLogin.forTesting({
  required final bool _isMacOS,
  required final bool _isWindows,
  required final bool _isLinux,
  required final String _homeDirectory,
  required final String _executablePath,
  required final String _userId,
  required final LaunchAtLoginProcessRunner _runProcess,
}) implements LaunchAtLogin {
  new()
    : this.forTesting(
        isMacOS: Platform.isMacOS,
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
        homeDirectory: _resolveUserHomeDirectory(),
        executablePath: Platform.resolvedExecutable,
        userId: Platform.isMacOS ? _resolveUserId() : "",
        runProcess: ({required String executable, required List<String> arguments}) =>
            Process.run(executable, arguments),
      );

  @visibleForTesting
  this;

  static const String _appName = "Sesori";
  static const String _registrationId = "com.sesori.desktop";
  static const String _windowsRunKey = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";

  File get _macOsRegistration => File(path.join(_homeDirectory, "Library", "LaunchAgents", "$_registrationId.plist"));

  File get _linuxRegistration => File(path.join(_homeDirectory, ".config", "autostart", "$_registrationId.desktop"));

  @override
  Future<bool> isEnabled() async {
    if (_isMacOS) {
      return _fileMatches(file: _macOsRegistration, expectedContents: _macOsContents);
    }
    if (_isLinux) {
      return _fileMatches(file: _linuxRegistration, expectedContents: _linuxContents);
    }
    if (_isWindows) {
      return await _isWindowsEnabled();
    }
    throw UnsupportedError("Launch at login is unsupported on this platform");
  }

  @override
  Future<void> enable() async {
    if (_isMacOS) {
      _writeRegistration(file: _macOsRegistration, contents: _macOsContents);
      return;
    }
    if (_isLinux) {
      _writeRegistration(file: _linuxRegistration, contents: _linuxContents);
      return;
    }
    if (_isWindows) {
      await _enableWindows();
      return;
    }
    throw UnsupportedError("Launch at login is unsupported on this platform");
  }

  @override
  Future<void> disable() async {
    if (_isMacOS) {
      await _disableMacOS();
      return;
    }
    if (_isLinux) {
      _deleteRegistration(file: _linuxRegistration);
      return;
    }
    if (_isWindows) {
      await _disableWindows();
      return;
    }
    throw UnsupportedError("Launch at login is unsupported on this platform");
  }

  String get _macOsContents => <String>[
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">',
    '<plist version="1.0">',
    '<dict>',
    '  <key>Label</key>',
    '  <string>$_registrationId</string>',
    '  <key>ProgramArguments</key>',
    '  <array>',
    '    <string>${_xmlEscape(_executablePath)}</string>',
    '    <string>$desktopHiddenLaunchArgument</string>',
    '  </array>',
    '  <key>RunAtLoad</key>',
    '  <true/>',
    '  <key>ProcessType</key>',
    '  <string>Interactive</string>',
    '  <key>LimitLoadToSessionType</key>',
    '  <string>Aqua</string>',
    '</dict>',
    '</plist>',
    '',
  ].join("\n");

  String get _linuxContents => <String>[
    "[Desktop Entry]",
    "Type=Application",
    "Version=1.0",
    "Name=$_appName",
    "Exec=${_desktopEntryQuote(_executablePath)} ${_desktopEntryQuote(desktopHiddenLaunchArgument)}",
    "Terminal=false",
    "StartupNotify=false",
    "X-GNOME-Autostart-enabled=true",
    "",
  ].join("\n");

  String get _windowsCommand => '"${_executablePath.replaceAll('"', r'\"')}" $desktopHiddenLaunchArgument';

  bool _fileMatches({required File file, required String expectedContents}) {
    if (!file.existsSync()) {
      return false;
    }
    return file.readAsStringSync() == expectedContents;
  }

  void _writeRegistration({required File file, required String contents}) {
    if (_fileMatches(file: file, expectedContents: contents)) {
      return;
    }
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(contents, flush: true);
  }

  void _deleteRegistration({required File file}) {
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  Future<ProcessResult> _queryWindows() =>
      _runProcess(executable: "reg.exe", arguments: <String>["QUERY", _windowsRunKey, "/v", _appName]);

  Future<bool> _isWindowsEnabled() async {
    final ProcessResult result = await _queryWindows();
    return result.exitCode == 0 && result.stdout.toString().contains(_windowsCommand);
  }

  Future<bool> _windowsValueExists() async {
    final ProcessResult result = await _queryWindows();
    return result.exitCode == 0;
  }

  Future<void> _enableWindows() async {
    if (await _isWindowsEnabled()) {
      return;
    }
    final List<String> arguments = <String>[
      "ADD",
      _windowsRunKey,
      "/v",
      _appName,
      "/t",
      "REG_SZ",
      "/d",
      _windowsCommand,
      "/f",
    ];
    final ProcessResult result = await _runProcess(executable: "reg.exe", arguments: arguments);
    _requireSuccess(executable: "reg.exe", arguments: arguments, result: result);
  }

  Future<void> _disableWindows() async {
    if (!await _windowsValueExists()) {
      return;
    }
    final List<String> arguments = <String>["DELETE", _windowsRunKey, "/v", _appName, "/f"];
    final ProcessResult result = await _runProcess(executable: "reg.exe", arguments: arguments);
    _requireSuccess(executable: "reg.exe", arguments: arguments, result: result);
  }

  Future<void> _disableMacOS() async {
    final File registration = _macOsRegistration;
    if (!registration.existsSync()) {
      return;
    }
    if (await _isMacOSLoaded()) {
      final List<String> arguments = <String>["bootout", "gui/$_userId/$_registrationId"];
      final ProcessResult result = await _runProcess(executable: "launchctl", arguments: arguments);
      _requireSuccess(executable: "launchctl", arguments: arguments, result: result);
    }
    _deleteRegistration(file: registration);
  }

  Future<bool> _isMacOSLoaded() async {
    final List<String> arguments = <String>["print", "gui/$_userId/$_registrationId"];
    final ProcessResult result = await _runProcess(executable: "launchctl", arguments: arguments);
    if (result.exitCode == 0) {
      return true;
    }
    if (result.exitCode == 113 || result.stderr.toString().contains("Could not find service")) {
      return false;
    }
    _requireSuccess(executable: "launchctl", arguments: arguments, result: result);
    return false;
  }

  void _requireSuccess({
    required String executable,
    required List<String> arguments,
    required ProcessResult result,
  }) {
    if (result.exitCode == 0) {
      return;
    }
    final String stderr = result.stderr.toString().trim();
    final String stdout = result.stdout.toString().trim();
    throw ProcessException(
      executable,
      arguments,
      stderr.isNotEmpty ? stderr : stdout,
      result.exitCode,
    );
  }

  static String _resolveUserId() {
    final ProcessResult result = Process.runSync("id", <String>["-u"]);
    if (result.exitCode != 0) {
      throw ProcessException("id", const <String>["-u"], result.stderr.toString(), result.exitCode);
    }
    final String userId = result.stdout.toString().trim();
    if (userId.isEmpty) {
      throw StateError("Cannot register launch at login because the user id is unavailable");
    }
    return userId;
  }

  static String _resolveUserHomeDirectory() {
    final List<String> keys = Platform.isWindows
        ? const <String>["USERPROFILE", "HOME"]
        : const <String>["HOME", "USERPROFILE"];
    for (final String key in keys) {
      final String? value = Platform.environment[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    throw StateError("Cannot register launch at login because the user home directory is unavailable");
  }

  static String _xmlEscape(String value) => value
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&apos;");

  static String _desktopEntryQuote(String value) =>
      '"${value.replaceAll(r"\", r"\\").replaceAll('"', r'\"').replaceAll(r"$", r"\$").replaceAll("`", r"\`")}"';
}
