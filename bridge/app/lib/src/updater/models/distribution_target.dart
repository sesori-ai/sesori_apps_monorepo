import 'dart:io' show Platform;

import '../foundation/platform_info.dart';

final class DistributionTarget {
  factory DistributionTarget({
    required DistributionPlatformOs os,
    required DistributionPlatformArch arch,
  }) {
    switch ((os, arch)) {
      case (DistributionPlatformOs.macos, DistributionPlatformArch.arm64):
      case (DistributionPlatformOs.macos, DistributionPlatformArch.x64):
      case (DistributionPlatformOs.linux, DistributionPlatformArch.arm64):
      case (DistributionPlatformOs.linux, DistributionPlatformArch.x64):
      case (DistributionPlatformOs.windows, DistributionPlatformArch.x64):
        return DistributionTarget._(os: os, arch: arch);
      case _:
        throw ArgumentError('Unsupported platform: ${os.value} ${arch.value}');
    }
  }

  factory DistributionTarget.current() {
    return DistributionTarget(
      os: DistributionPlatformOs.fromPlatform(
        operatingSystem: Platform.operatingSystem,
      ),
      arch: DistributionPlatformArch.detectCurrent(
        platformVersion: Platform.version,
      ),
    );
  }

  const DistributionTarget._({required this.os, required this.arch});

  final DistributionPlatformOs os;
  final DistributionPlatformArch arch;

  String get key => '${os.value} ${arch.value}';

  String get assetName {
    switch ((os, arch)) {
      case (DistributionPlatformOs.macos, DistributionPlatformArch.arm64):
        return 'sesori-bridge-macos-arm64.tar.gz';
      case (DistributionPlatformOs.macos, DistributionPlatformArch.x64):
        return 'sesori-bridge-macos-x64.tar.gz';
      case (DistributionPlatformOs.linux, DistributionPlatformArch.x64):
        return 'sesori-bridge-linux-x64.tar.gz';
      case (DistributionPlatformOs.linux, DistributionPlatformArch.arm64):
        return 'sesori-bridge-linux-arm64.tar.gz';
      case (DistributionPlatformOs.windows, DistributionPlatformArch.x64):
        return 'sesori-bridge-windows-x64.zip';
      case _:
        throw ArgumentError('Unsupported platform: $key');
    }
  }
}

DistributionTarget currentDistributionTarget() {
  return DistributionTarget.current();
}

String getCurrentAssetName() {
  return currentDistributionTarget().assetName;
}
