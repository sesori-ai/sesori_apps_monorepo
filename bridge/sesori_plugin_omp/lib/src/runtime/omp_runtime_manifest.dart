import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/omp_linux_libc.dart";
import "../omp_identity.dart";

class const OmpRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "17.2.13");

  /// The Oh My Pi release targeted by this plugin.
  static const String targetVersion = "18.22.2";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, DirectBinaryRuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-arm64",
        sha256: "d02253f9f5e13bafa2af6a6a773cf7531019d37379b073a204b1be128b961458",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-x64",
        sha256: "f534936d69a3e0a75ac48d1a53c078c605f1c5646d25eeba4dbae31a1aeae43b",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-arm64.exe",
        sha256: "20dda87e4d66005ae8128e3a28f9cc64181c74b94fc3fb88c33c6c0131eef457",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-x64.exe",
        sha256: "bab49acf7e0bca6fc98213b1f9f21bc7bfdb5070afa52eb494ec400337395848",
      ),
    },
  };

  static const Map<OmpLinuxLibc, Map<PlatformArch, DirectBinaryRuntimeAsset>> _linuxAssets = {
    OmpLinuxLibc.glibc: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-arm64",
        sha256: "82a880ba04d73f1c81a12931447f9f9ed8945581998564eae900c1238f4502e2",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-x64",
        sha256: "80a692c5adb9c71124bb11e77bd7edb3cf8fbbab6980db3206dcb6a4cb2905b5",
      ),
    },
    OmpLinuxLibc.musl: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-arm64",
        sha256: "a8c3cc9a0c8c24470fafee8c94bb1cbe30e979772784237f9025db5515990166",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-x64",
        sha256: "0777c24ca757acf67c5b3ca4da0653233247cd191fe6a55bb2d41c8613ea1fc6",
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
