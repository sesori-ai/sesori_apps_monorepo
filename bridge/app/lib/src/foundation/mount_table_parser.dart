import "dart:convert";

/// The volumes in `/Volumes`, read from macOS `mount` output, that Finder shows
/// and a project can be written to, in path order. Read-only leaves out
/// mounted installer disk images; `nobrowse` leaves out system volumes such as
/// Recovery. The boot disk's `/Volumes` entry is a link to `/`, not a mount,
/// so it never appears.
List<String> parseMacosVolumes({required String mountTable}) {
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
List<String> parseLinuxVolumes({required String mountTable}) {
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
