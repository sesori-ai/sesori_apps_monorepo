import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart" show PlatformOs;

import "../foundation/process_runner.dart";
import "filesystem_api.dart";

/// The folders a host offers as drives in the folder browser, before they are
/// probed: Windows drive letters, or the volumes and mounts in a macOS or
/// Linux mount table.
sealed class DriveRootsApi {
  /// Throws when the mount table cannot be read.
  Future<List<String>> listCandidates();

  factory forPlatform({
    required PlatformOs platform,
    required ProcessRunner processRunner,
    required FilesystemApi filesystemApi,
  }) => switch (platform) {
    PlatformOs.windows => _WindowsDriveRootsApi(),
    PlatformOs.macos => _MacosDriveRootsApi(processRunner: processRunner),
    PlatformOs.linux => _LinuxDriveRootsApi(filesystemApi: filesystemApi),
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
    return _parseMacosVolumes(mountTable: "${result.stdout}");
  }
}

final class _LinuxDriveRootsApi({required final FilesystemApi _filesystemApi}) implements DriveRootsApi {
  @override
  Future<List<String>> listCandidates() async {
    final mountTable = _filesystemApi.readFileIfExists("/proc/mounts");
    if (mountTable == null) throw const FileSystemException("No mount table", "/proc/mounts");
    return _parseLinuxVolumes(mountTable: mountTable);
  }
}

/// The volumes in `/Volumes`, read from macOS `mount` output, that Finder shows
/// and a project can be written to, in path order. Read-only leaves out
/// mounted installer disk images; `nobrowse` leaves out system volumes such as
/// Recovery. The boot disk's `/Volumes` entry is a link to `/`, not a mount,
/// so it never appears.
List<String> _parseMacosVolumes({required String mountTable}) {
  final volumes = [
    for (final line in LineSplitter.split(mountTable))
      if (_macosMountLine.firstMatch(line)?.groups([1, 2]) case [final String path, final String options])
        if (!options.split(", ").any(const {"read-only", "nobrowse"}.contains)) path,
  ];
  return volumes..sort();
}

/// `<device> on <path> (<type>, <option>, ...)`.
final _macosMountLine = RegExp(r"^.+? on (/Volumes/.+) \(([^()]*)\)$");

/// The writable disks and partitions mounted in the usual Linux mount folders,
/// read from `/proc/mounts`, in path order. This includes a WSL host's Windows
/// drives under `/mnt`. Read-only leaves out mounted ISO images; tmpfs and
/// anything nested inside another mount there leave out WSL's own `/mnt/wsl`
/// and `/mnt/wslg` plumbing.
List<String> _parseLinuxVolumes({required String mountTable}) {
  final mounts = [
    for (final line in LineSplitter.split(mountTable))
      if (line.split(" ") case [_, final path, final type, final options, ...])
        (path: _unescapeLinuxMountPath(path: path), type: type, options: options.split(",")),
  ].where((mount) => _linuxMountFolders.any(mount.path.startsWith)).toList();
  final volumes = [
    for (final mount in mounts)
      if (mount.type != "tmpfs" &&
          !mount.options.contains("ro") &&
          !mounts.any((other) => mount.path.startsWith("${other.path}/")))
        mount.path,
  ];
  return volumes..sort();
}

const _linuxMountFolders = ["/media/", "/run/media/", "/mnt/"];

/// `/proc/mounts` writes a space, tab, newline, or backslash in a path as a
/// three-digit octal escape such as `\040`.
String _unescapeLinuxMountPath({required String path}) {
  return path.replaceAllMapped(
    RegExp(r"\\[0-7]{3}"),
    (match) => String.fromCharCode(int.parse(path.substring(match.start + 1, match.end), radix: 8)),
  );
}
