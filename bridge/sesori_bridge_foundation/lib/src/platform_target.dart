import "dart:io" show Platform;

import "package:meta/meta.dart";

/// Operating systems a managed runtime can be published for.
enum PlatformOs {
  macos,
  linux,
  windows;

  String get value => name;

  static PlatformOs fromOperatingSystem({required String operatingSystem}) {
    switch (operatingSystem) {
      case "macos":
        return PlatformOs.macos;
      case "linux":
        return PlatformOs.linux;
      case "windows":
        return PlatformOs.windows;
    }

    throw ArgumentError("Unsupported operating system: $operatingSystem");
  }
}

/// CPU architectures a managed runtime can be published for.
enum PlatformArch {
  arm64,
  x64;

  String get value => name;

  static PlatformArch fromDartVersion({required String dartVersion}) {
    final version = dartVersion.toLowerCase();
    if (version.contains("arm64") || version.contains("aarch64")) {
      return PlatformArch.arm64;
    }
    if (version.contains("x86_64") || version.contains("x64")) {
      return PlatformArch.x64;
    }

    throw ArgumentError("Unsupported runtime architecture: $dartVersion");
  }
}

/// The (os, arch) pair identifying the host's release target.
///
/// A neutral detection primitive: consumers map a [PlatformTarget] to their own
/// published asset name/format/checksum (the bridge updater and the OpenCode
/// runtime manifest each key their own asset tables off this).
@immutable
final class PlatformTarget {
  const PlatformTarget({required this.os, required this.arch});

  factory PlatformTarget.current() {
    return PlatformTarget(
      os: PlatformOs.fromOperatingSystem(operatingSystem: Platform.operatingSystem),
      arch: PlatformArch.fromDartVersion(dartVersion: Platform.version),
    );
  }

  final PlatformOs os;
  final PlatformArch arch;

  String get key => "${os.value} ${arch.value}";

  @override
  bool operator ==(Object other) =>
      other is PlatformTarget && other.os == os && other.arch == arch;

  @override
  int get hashCode => Object.hash(os, arch);

  @override
  String toString() => "PlatformTarget($key)";
}
