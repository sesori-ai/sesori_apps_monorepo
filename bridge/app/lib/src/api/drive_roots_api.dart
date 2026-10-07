import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;

import "../foundation/mount_table_parser.dart";
import "../foundation/process_runner.dart";

/// The folders a host offers as drives in the folder browser, before they are
/// probed: Windows drive letters, or the volumes and mounts in a macOS or
/// Linux mount table.
sealed class DriveRootsApi {
  /// Throws when the mount table cannot be read.
  Future<List<String>> listCandidates();

  factory forPlatform({
    required PlatformOs platform,
    required ProcessRunner processRunner,
  }) => switch (platform) {
    PlatformOs.windows => _WindowsDriveRootsApi(),
    PlatformOs.macos => _MacosDriveRootsApi(processRunner: processRunner),
    PlatformOs.linux => _LinuxDriveRootsApi(),
  };
}

final class _WindowsDriveRootsApi() implements DriveRootsApi {
  @override
  Future<List<String>> listCandidates() async => [
    for (var letter = "A".codeUnitAt(0); letter <= "Z".codeUnitAt(0); letter++) "${String.fromCharCode(letter)}:\\",
  ];
}

final class _MacosDriveRootsApi({required final ProcessRunner _processRunner}) implements DriveRootsApi {
  @override
  Future<List<String>> listCandidates() async {
    final result = await _processRunner.run("/sbin/mount", const []);
    if (result.exitCode != 0) {
      throw ProcessException("/sbin/mount", const [], "${result.stderr}", result.exitCode);
    }
    return parseMacosVolumes(mountTable: "${result.stdout}");
  }
}

final class _LinuxDriveRootsApi() implements DriveRootsApi {
  @override
  Future<List<String>> listCandidates() async {
    return parseLinuxVolumes(mountTable: await File("/proc/mounts").readAsString());
  }
}
