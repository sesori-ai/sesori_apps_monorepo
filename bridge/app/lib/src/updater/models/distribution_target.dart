import 'package:sesori_plugin_runtime/sesori_plugin_runtime.dart';

/// Maps the host [PlatformTarget] to the bridge's own published release asset
/// (name + archive format). Platform detection and the os/arch vocabulary are
/// shared via [PlatformTarget]; the bridge-specific asset table lives here.
final class DistributionTarget {
  factory DistributionTarget({
    required PlatformOs os,
    required PlatformArch arch,
  }) {
    return DistributionTarget._(platform: PlatformTarget(os: os, arch: arch));
  }

  factory DistributionTarget.current() {
    return DistributionTarget._(platform: PlatformTarget.current());
  }

  const DistributionTarget._({required this.platform});

  final PlatformTarget platform;

  PlatformOs get os => platform.os;
  PlatformArch get arch => platform.arch;

  String get key => platform.key;

  /// The archive container the bridge publishes for this platform: a `.zip` on
  /// Windows, a `.tar.gz` everywhere else. Single source of truth for the
  /// updater's extraction format.
  ArchiveFormat get archiveFormat =>
      os == PlatformOs.windows ? ArchiveFormat.zip : ArchiveFormat.tarGz;

  String get assetName {
    switch ((os, arch)) {
      case (PlatformOs.macos, PlatformArch.arm64):
        return 'sesori-bridge-macos-arm64.tar.gz';
      case (PlatformOs.macos, PlatformArch.x64):
        return 'sesori-bridge-macos-x64.tar.gz';
      case (PlatformOs.linux, PlatformArch.x64):
        return 'sesori-bridge-linux-x64.tar.gz';
      case (PlatformOs.linux, PlatformArch.arm64):
        return 'sesori-bridge-linux-arm64.tar.gz';
      case (PlatformOs.windows, PlatformArch.x64):
        return 'sesori-bridge-windows-x64.zip';
      case (PlatformOs.windows, PlatformArch.arm64):
        return 'sesori-bridge-windows-arm64.zip';
    }
  }
}

DistributionTarget currentDistributionTarget() {
  return DistributionTarget.current();
}

String getCurrentAssetName() {
  return currentDistributionTarget().assetName;
}
