import "dart:async";
import "dart:io";

import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "process_runner.dart";

/// Abstracts platform checks so they can be mocked in tests.
abstract class PlatformChecker {
  bool get isMacOS;
  bool get isWindows;
  bool get isLinux;
}

class DefaultPlatformChecker implements PlatformChecker {
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
  final String _linuxPowerSupplyPath;
  Future<bool>? _isLaptop;

  DeviceTypeDetector({
    required ProcessRunner processRunner,
    required PlatformChecker platformChecker,
    @visibleForTesting String linuxPowerSupplyPath = "/sys/class/power_supply/",
  }) : _processRunner = processRunner,
       _platformChecker = platformChecker,
       _linuxPowerSupplyPath = linuxPowerSupplyPath;

  Future<bool> isLaptop() async => _isLaptop ??= _computeIsLaptop();

  Future<bool> _computeIsLaptop() {
    if (_platformChecker.isMacOS) {
      return _isMacOSLaptop();
    } else if (_platformChecker.isWindows) {
      return _isWindowsLaptop();
    } else if (_platformChecker.isLinux) {
      return _isLinuxLaptop();
    } else {
      return Future.value(false);
    }
  }

  Future<bool> _isMacOSLaptop() async {
    try {
      final result = await _processRunner.run(
        "sysctl",
        <String>["-n", "hw.model"],
      );
      if (result.exitCode != 0) {
        Log.w(
          "[device-type] sysctl failed (exit ${result.exitCode}): "
          "${result.stderr}",
        );
        return false;
      }
      final model = (result.stdout as String).trim().toLowerCase();
      return model.contains("macbook");
    } on Object catch (error) {
      Log.w("[device-type] failed to detect macOS laptop: $error");
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
        Log.w(
          "[device-type] powershell failed (exit ${result.exitCode}): "
          "${result.stderr}",
        );
        return false;
      }
      final count = int.tryParse((result.stdout as String).trim()) ?? 0;
      return count > 0;
    } on Object catch (error) {
      Log.w("[device-type] failed to detect Windows laptop: $error");
      return false;
    }
  }

  Future<bool> _isLinuxLaptop() async {
    try {
      final dir = Directory(_linuxPowerSupplyPath);
      if (!dir.existsSync()) {
        return false;
      }
      final dirsStream = dir.list();
      return await dirsStream.any(
        (e) => e.path.split("/").last.startsWith("BAT"),
      );
    } on Object catch (error) {
      Log.w("[device-type] failed to detect Linux laptop: $error");
      return false;
    }
  }
}
