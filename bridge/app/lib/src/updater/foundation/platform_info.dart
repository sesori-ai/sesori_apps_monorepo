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
