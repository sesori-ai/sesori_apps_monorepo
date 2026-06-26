import "dart:convert" show LineSplitter;

/// Derives a short, human-friendly OS-version label (e.g. "macOS 14.5",
/// "Windows 11", "Ubuntu 22.04") from raw host platform facts.
///
/// Pure: callers supply the raw `Platform.operatingSystem` /
/// `Platform.operatingSystemVersion` strings and, on Linux, the contents of
/// `/etc/os-release` (the only place the distro name+version lives — the raw
/// version string there is just the kernel). Marketing codenames ("Sonoma",
/// "Tahoe") are intentionally NOT derived: no OS API exposes them.
///
/// Returns null when no meaningful version can be parsed, so the cosmetic
/// field is simply omitted rather than echoing the OS family already conveyed
/// by `clientType`. The result is trimmed and clamped to [maxLength].
class OsVersionFormatter {
  const OsVersionFormatter();

  /// Hard limit matching the auth server's `device.osVersion` schema (<= 40).
  static const int maxLength = 40;

  String? format({
    required String operatingSystem,
    required String operatingSystemVersion,
    required String? osReleaseContents,
  }) {
    final raw = switch (operatingSystem) {
      "macos" => _macos(operatingSystemVersion),
      "windows" => _windows(operatingSystemVersion),
      "linux" => _linux(osReleaseContents),
      _ => null,
    };
    if (raw == null) return null;

    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > maxLength ? trimmed.substring(0, maxLength).trim() : trimmed;
  }

  /// "Version 14.5 (Build 23F79)" -> "macOS 14.5".
  String? _macos(String operatingSystemVersion) {
    final version = RegExp(r"(\d+(?:\.\d+)*)").firstMatch(operatingSystemVersion)?.group(1);
    return version == null ? null : "macOS $version";
  }

  /// Windows 11 still reports major 10.0; the build number is the only
  /// discriminator (>= 22000 is Windows 11).
  String? _windows(String operatingSystemVersion) {
    final build = RegExp(r"Build\s+(\d+)").firstMatch(operatingSystemVersion)?.group(1) ??
        RegExp(r"\b(\d{5,})\b").firstMatch(operatingSystemVersion)?.group(1);
    final buildNumber = build == null ? null : int.tryParse(build);
    if (buildNumber == null) return null;
    return buildNumber >= 22000 ? "Windows 11" : "Windows 10";
  }

  /// Reads the distro name+version from `/etc/os-release` contents, preferring
  /// `PRETTY_NAME` (e.g. "Ubuntu 22.04.3 LTS") and falling back to
  /// `NAME`+`VERSION_ID`.
  String? _linux(String? osReleaseContents) {
    if (osReleaseContents == null) return null;

    final values = _parseOsRelease(osReleaseContents);
    final pretty = values["PRETTY_NAME"];
    if (pretty != null && pretty.isNotEmpty) return pretty;

    final name = values["NAME"];
    if (name != null && name.isNotEmpty) {
      final versionId = values["VERSION_ID"];
      return (versionId != null && versionId.isNotEmpty) ? "$name $versionId" : name;
    }
    return null;
  }

  Map<String, String> _parseOsRelease(String contents) {
    final result = <String, String>{};
    for (final line in const LineSplitter().convert(contents)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith("#")) continue;

      final eq = trimmed.indexOf("=");
      if (eq <= 0) continue;

      final key = trimmed.substring(0, eq).trim();
      var value = trimmed.substring(eq + 1).trim();
      // Strip the surrounding single/double quotes os-release(5) allows.
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      result[key] = value;
    }
    return result;
  }
}
