import "dart:async";
import "dart:io";

import "package:meta/meta.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "process_runner.dart";

/// Detects whether the current device is a laptop (as opposed to a desktop
/// or server). Used to show platform-specific wake-lock limitations.
class DeviceTypeDetector({
  required final ProcessRunner _processRunner,
  required final PlatformOs _platform,
  @visibleForTesting final String _linuxPowerSupplyPath = "/sys/class/power_supply/",
}) {
  Future<bool>? _isLaptop;

  Future<bool> isLaptop() async => await (_isLaptop ??= _computeIsLaptop());

  Future<bool> _computeIsLaptop() => switch (_platform) {
    PlatformOs.macos => _isMacOSLaptop(),
    PlatformOs.windows => _isWindowsLaptop(),
    PlatformOs.linux => _isLinuxLaptop(),
  };

  Future<bool> _isMacOSLaptop() async {
    try {
      final result = await _processRunner.run(
        executable: "sysctl",
        arguments: <String>["-n", "hw.model"],
        workingDirectory: null,
        environment: null,
      );
      if (result.exitCode != 0) {
        Log.w(
          "[device-type] sysctl failed (exit ${result.exitCode}): "
          "${result.stderr}",
        );
        return false;
      }
      final model = result.stdout.toString().trim().toLowerCase();
      return model.contains("macbook");
    } on Object catch (error) {
      Log.w("[device-type] failed to detect macOS laptop", error);
      return false;
    }
  }

  Future<bool> _isWindowsLaptop() async {
    try {
      final result = await _processRunner.run(
        executable: "powershell.exe",
        arguments: <String>[
          "-Command",
          "Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count",
        ],
        workingDirectory: null,
        environment: null,
      );
      if (result.exitCode != 0) {
        Log.w(
          "[device-type] powershell failed (exit ${result.exitCode}): "
          "${result.stderr}",
        );
        return false;
      }
      final count = int.tryParse(result.stdout.toString().trim()) ?? 0;
      return count > 0;
    } on Object catch (error) {
      Log.w("[device-type] failed to detect Windows laptop", error);
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
      Log.w("[device-type] failed to detect Linux laptop", error);
      return false;
    }
  }
}
