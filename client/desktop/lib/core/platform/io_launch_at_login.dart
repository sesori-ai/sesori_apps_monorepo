import "dart:io";

import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:win32_registry/win32_registry.dart";

import "desktop_launch_arguments.dart";

@visibleForTesting
typedef LaunchAtLoginProcessRunner = Future<ProcessResult> Function({
  required String executable,
  required List<String> arguments,
});

@visibleForTesting
typedef LaunchAtLoginWindowsValueReader = String? Function();

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
  required final String? _xdgConfigHome,
  required final String _executablePath,
  required final LaunchAtLoginWindowsValueReader _windowsValueReader,
  required final LaunchAtLoginProcessRunner _runProcess,
}) implements LaunchAtLogin {
  new()
    : this.forTesting(
        isMacOS: Platform.isMacOS,
        isWindows: Platform.isWindows,
        isLinux: Platform.isLinux,
        homeDirectory: _resolveUserHomeDirectory(),
        xdgConfigHome: Platform.environment["XDG_CONFIG_HOME"]?.trim(),
        executablePath: Platform.resolvedExecutable,
        windowsValueReader: _readWindowsRegistryValue,
        runProcess: ({required String executable, required List<String> arguments}) =>
            Process.run(executable, arguments),
      );

  @visibleForTesting
  this;

  static const String _appName = "Sesori";
  static const String _registrationId = "com.sesori.desktop";
  static const String _windowsRunKey = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";
  static const String _windowsRunSubKey = r"Software\Microsoft\Windows\CurrentVersion\Run";

  File get _macOsRegistration => File(path.join(_homeDirectory, "Library", "LaunchAgents", "$_registrationId.plist"));

  File get _linuxRegistration => File(
    path.join(_linuxConfigHome, "autostart", "$_registrationId.desktop"),
  );

  String get _linuxConfigHome {
    final String? configuredHome = _xdgConfigHome?.trim();
    return configuredHome == null || configuredHome.isEmpty ? path.join(_homeDirectory, ".config") : configuredHome;
  }

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
      _deleteRegistration(file: _macOsRegistration);
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

  Future<bool> _isWindowsEnabled() async => _windowsValueReader() == _windowsCommand;

  Future<bool> _windowsValueExists() async => _windowsValueReader() != null;

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

  // Use the native API so missing values are identified by stable status codes,
  // rather than localized reg.exe diagnostics.
  static String? _readWindowsRegistryValue() => CURRENT_USER.getString(_appName, path: _windowsRunSubKey);

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
      '"${value.replaceAll(r"\", r"\\").replaceAll('"', r'\"').replaceAll(r"$", r"\$").replaceAll("`", r"\`").replaceAll("%", "%%")}"';
}
