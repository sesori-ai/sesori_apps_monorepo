import "dart:io";

import "process_runner.dart";

/// Abstracts platform checks so they can be mocked in tests.
abstract class PlatformChecker {
  bool get isMacOS;
  bool get isWindows;
  bool get isLinux;
}

class _DefaultPlatformChecker implements PlatformChecker {
  @override
  bool get isMacOS => Platform.isMacOS;

  @override
  bool get isWindows => Platform.isWindows;

  @override
  bool get isLinux => Platform.isLinux;
}

/// Detects whether the current device is a laptop (as opposed to a desktop
/// or server). Used to show platform-specific wake-lock limitations.
class DeviceTypeDetector {
  final ProcessRunner _processRunner;
  final PlatformChecker _platformChecker;

  DeviceTypeDetector({
    required ProcessRunner processRunner,
    PlatformChecker? platformChecker,
  }) : _processRunner = processRunner,
       _platformChecker = platformChecker ?? _DefaultPlatformChecker();

  Future<bool> isLaptop() async {
    if (_platformChecker.isMacOS) {
      return _isMacOSLaptop();
    }
    if (_platformChecker.isWindows) {
      return _isWindowsLaptop();
    }
    if (_platformChecker.isLinux) {
      return _isLinuxLaptop();
    }
    return false;
  }

  Future<bool> _isMacOSLaptop() async {
    try {
      final result = await _processRunner.run("sysctl", <String>["-n", "hw.model"]);
      if (result.exitCode != 0) {
        return false;
      }
      final model = (result.stdout as String).trim().toLowerCase();
      return model.contains("macbook");
    } on Object {
      return false;
    }
  }

  Future<bool> _isWindowsLaptop() async {
    try {
      final result = await _processRunner.run(
        "powershell.exe",
        <String>[
          "-Command",
          "Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count",
        ],
      );
      if (result.exitCode != 0) {
        return false;
      }
      final count = int.tryParse((result.stdout as String).trim()) ?? 0;
      return count > 0;
    } on Object {
      return false;
    }
  }

  Future<bool> _isLinuxLaptop() async {
    try {
      final dir = Directory("/sys/class/power_supply/");
      if (!dir.existsSync()) {
        return false;
      }
      return dir
          .listSync()
          .any((e) => e.path.split("/").last.startsWith("BAT"));
    } on Object {
      return false;
    }
  }
}
