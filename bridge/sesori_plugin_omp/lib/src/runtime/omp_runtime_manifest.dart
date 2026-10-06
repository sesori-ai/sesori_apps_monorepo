import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/omp_linux_libc.dart";
import "../omp_identity.dart";

class const OmpRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "17.2.13");

  /// The latest stable Oh My Pi release targeted by this plugin.
  static const String targetVersion = "18.6.3";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, DirectBinaryRuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-arm64",
        sha256: "ab52491643e21b270682691b1319f1161fe2a2658ae4e9a4e3958b1aeb12dcf4",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-x64",
        sha256: "e46cb6bd129870eea80d77e4a5963b2208e3ca1997249d06c0a1add11d835cdd",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-arm64.exe",
        sha256: "edecce8ab10d46af18f3ca057ece173e0c0c4d404dd1a5747732aa18f6e7f9ad",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-x64.exe",
        sha256: "453e8ecd17f36e0b7faba2abc761206fe72d16b97fbacbe1281831ad9fa86482",
      ),
    },
  };

  static const Map<OmpLinuxLibc, Map<PlatformArch, DirectBinaryRuntimeAsset>> _linuxAssets = {
    OmpLinuxLibc.glibc: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-arm64",
        sha256: "56cb0174c38ebacb0590e14c69eb62c91681b90a995b45b083ec9d38b3fd3fc3",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-x64",
        sha256: "5972347a0afa983333151e1f27461bc441929a22ab5ec65dfed248eb2108ddaf",
      ),
    },
    OmpLinuxLibc.musl: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-arm64",
        sha256: "1d71c23cda6291065874f5ff5b5010e752ef7c0437bc0122cd97f6242c13e29e",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-x64",
        sha256: "f76e5cbbd25a566e30b4767fefcba96a5a41654d4cfa934a1ee91811d311b275",
      ),
    },
  };

  @override
  String get runtimeId => OmpPluginIdentity.id;

  @override
  String get displayName => OmpPluginIdentity.displayName;

  @override
  String get installDocsUrl => "https://github.com/can1357/oh-my-pi";

  @override
  String get pathExecutableName => "omp";

  @override
  String get binaryFileName => Platform.isWindows ? "omp.exe" : "omp";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) {
    if (!value.startsWith("omp/")) return null;
    return SemanticRuntimeVersion.tryParse(value: value.substring(4));
  }

  /// `omp --version` prints `omp/<semver>` and the prefix is required so an
  /// unrelated semver token in that output is not mistaken for the runtime
  /// version. Version directories carry the bare semver, so they parse here.
  @override
  RuntimeVersion? parseInstalledVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return null;
    return _assets[target.os]?[target.arch];
  }

  /// Whether this release publishes an asset for [target]. Linux support is
  /// known before the host's libc variant is selected asynchronously.
  @override
  bool supportsManagedInstallOn({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return _linuxAssets.values.any((assets) => assets.containsKey(target.arch));
    return assetFor(target: target) != null;
  }

  RuntimeAsset? assetForLinux({required PlatformArch arch, required OmpLinuxLibc libc}) => _linuxAssets[libc]?[arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "can1357/oh-my-pi", tag: "v${bundledVersion.raw}", asset: asset);
}
