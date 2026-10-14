import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../foundation/process_runner.dart";

/// Reads the operating system's stable identifier for this computer, which
/// survives a bridge reinstall. Every read goes through the injected
/// [ProcessRunner], so one seam fakes all three platforms in tests.
sealed class MachineIdApi {
  /// The trimmed identifier, or null when it is missing, blank, or cannot be
  /// read. A read failure is logged and never thrown.
  Future<String?> readMachineId();

  factory forPlatform({
    required PlatformOs platform,
    required ProcessRunner processRunner,
  }) => switch (platform) {
    PlatformOs.macos => _MacosMachineIdApi(processRunner: processRunner),
    PlatformOs.linux => _LinuxMachineIdApi(processRunner: processRunner),
    PlatformOs.windows => _WindowsMachineIdApi(processRunner: processRunner),
  };
}

final class _MacosMachineIdApi({required final ProcessRunner _processRunner}) implements MachineIdApi {
  @override
  Future<String?> readMachineId() async {
    final output = await _runOrNull(
      processRunner: _processRunner,
      executable: "/usr/sbin/ioreg",
      arguments: const ["-rd1", "-c", "IOPlatformExpertDevice"],
    );
    return _nonBlank(value: _macosPlatformUuid.firstMatch(output ?? "")?.group(1));
  }
}

/// `"IOPlatformUUID" = "<uuid>"` in `ioreg` output.
final _macosPlatformUuid = RegExp('"IOPlatformUUID" = "([^"]*)"');

final class _LinuxMachineIdApi({required final ProcessRunner _processRunner}) implements MachineIdApi {
  @override
  Future<String?> readMachineId() async {
    // The D-Bus copy covers distributions without systemd's file.
    for (final path in const ["/etc/machine-id", "/var/lib/dbus/machine-id"]) {
      final machineId = _nonBlank(
        value: await _runOrNull(processRunner: _processRunner, executable: "cat", arguments: [path]),
      );
      if (machineId != null) return machineId;
    }
    return null;
  }
}

final class _WindowsMachineIdApi({required final ProcessRunner _processRunner}) implements MachineIdApi {
  @override
  Future<String?> readMachineId() async {
    final output = await _runOrNull(
      processRunner: _processRunner,
      executable: "reg",
      arguments: const ["query", r"HKLM\SOFTWARE\Microsoft\Cryptography", "/v", "MachineGuid", "/reg:64"],
    );
    return _nonBlank(value: _windowsMachineGuid.firstMatch(output ?? "")?.group(1));
  }
}

/// `MachineGuid    REG_SZ    <guid>` in `reg query` output.
final _windowsMachineGuid = RegExp(r"MachineGuid\s+REG_SZ\s+(\S+)");

/// The command's stdout, or null (logged) when it fails to run or exits non-zero.
Future<String?> _runOrNull({
  required ProcessRunner processRunner,
  required String executable,
  required List<String> arguments,
}) async {
  final command = [executable, ...arguments].join(" ");
  try {
    final result = await processRunner.run(executable, arguments);
    if (result.exitCode != 0) {
      Log.w("[machine-id] `$command` exited ${result.exitCode}: ${result.stderr}");
      return null;
    }
    return "${result.stdout}";
  } on Object catch (error, stackTrace) {
    Log.w("[machine-id] `$command` failed", error, stackTrace);
    return null;
  }
}

String? _nonBlank({required String? value}) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
