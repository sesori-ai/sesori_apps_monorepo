import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

enum DistributionPlatformOs {
  macos,
  linux,
  windows
  ;

  String get value => name;

  static DistributionPlatformOs fromPlatform({required String operatingSystem}) {
    switch (operatingSystem) {
      case 'macos':
        return DistributionPlatformOs.macos;
      case 'linux':
        return DistributionPlatformOs.linux;
      case 'windows':
        return DistributionPlatformOs.windows;
    }

    throw ArgumentError('Unsupported operating system: $operatingSystem');
  }
}

enum DistributionPlatformArch {
  arm64,
  x64
  ;

  String get value => name;

  static DistributionPlatformArch detectCurrent({required String platformVersion}) {
    final version = platformVersion.toLowerCase();
    if (version.contains('arm64') || version.contains('aarch64')) {
      return DistributionPlatformArch.arm64;
    }
    if (version.contains('x86_64') || version.contains('x64')) {
      return DistributionPlatformArch.x64;
    }

    throw ArgumentError('Unsupported runtime architecture: $platformVersion');
  }
}

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

/// Returns the archive asset name for the current runtime target.
String getCurrentAssetName() {
  return currentDistributionTarget().assetName;
}

/// Returns the installation root directory.
///
/// On Unix (macOS, Linux): ~/.sesori/
/// On Windows: %LOCALAPPDATA%\sesori\
String getInstallRoot() {
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError('LOCALAPPDATA environment variable not set');
    }
    return p.join(localAppData, 'sesori');
  }

  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw StateError('HOME environment variable not set');
  }
  return p.join(home, '.sesori');
}

/// Returns the path to the sesori-bridge binary.
///
/// On Unix: ~/.sesori/bin/sesori-bridge
/// On Windows: %LOCALAPPDATA%\sesori\bin\sesori-bridge.exe
String getBinaryPath() {
  final root = getInstallRoot();
  if (Platform.isWindows) {
    return p.join(root, 'bin', 'sesori-bridge.exe');
  }
  return p.join(root, 'bin', 'sesori-bridge');
}

/// Returns the cache directory for sesori-bridge.
///
/// On Unix: ~/.config/sesori-bridge/
/// On Windows: %LOCALAPPDATA%\sesori\cache\
String getCacheDirectory() {
  if (Platform.isWindows) {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    if (localAppData == null || localAppData.isEmpty) {
      throw StateError('LOCALAPPDATA environment variable not set');
    }
    return p.join(localAppData, 'sesori', 'cache');
  }

  final home = Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    throw StateError('HOME environment variable not set');
  }
  return p.join(home, '.config', 'sesori-bridge');
}
