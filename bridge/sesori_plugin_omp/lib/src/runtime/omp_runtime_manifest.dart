import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/omp_linux_libc.dart";
import "../omp_identity.dart";

class const OmpRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "17.2.13");

  /// The Oh My Pi release targeted by this plugin.
  static const String targetVersion = "18.22.0";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, DirectBinaryRuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-arm64",
        sha256: "d185113d63eba23925e5d70ab661a424b827c06c98f8e766c3bf4ad62ddaff9a",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-x64",
        sha256: "a1933196fe54bac3d518ccf7e5cc11849dd207b710cda431c465a12d173ff035",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-arm64.exe",
        sha256: "384667e3bec511ced2a4f5b07ae7ea8ccffd138da0e45910768161b95813e6a2",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-x64.exe",
        sha256: "3987213b123ff424d66aa061f916314007bcb07226fafe15da70e3abd87569d7",
      ),
    },
  };

  static const Map<OmpLinuxLibc, Map<PlatformArch, DirectBinaryRuntimeAsset>> _linuxAssets = {
    OmpLinuxLibc.glibc: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-arm64",
        sha256: "7238dd213d5c61bc9bf51735d552bc71901fdd44329f862b0a971146b1cdac3e",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-x64",
        sha256: "f706b27ba845834d8f8360705a2e9ba1534f3593fa24411d41358272de33642b",
      ),
    },
    OmpLinuxLibc.musl: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-arm64",
        sha256: "6292b4f1be508599a415f98c960d3ea52835a6b103967b316b8708263b283d8b",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-x64",
        sha256: "79ec62c929e1b341c14a5dff35c480dc2db5bbd3740b31c4f1b854c075ae4806",
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
