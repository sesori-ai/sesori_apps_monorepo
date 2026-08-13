import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../models/omp_linux_libc.dart";
import "../omp_identity.dart";

class const OmpRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _version = SemanticRuntimeVersion.parse(value: "17.2.13");

  static const Map<PlatformOs, Map<PlatformArch, DirectBinaryRuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-arm64",
        sha256: "2841151eb3381cfe094aaefef3fb7be3c926075821ba6bf3fa77dcb2ffbb8db7",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-darwin-x64",
        sha256: "07d5f9603b9e3dc0dc918d94cbfd5c6ed50c13f72faed6eec83d677580739d7c",
      ),
    },
    PlatformOs.windows: {
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-windows-x64.exe",
        sha256: "1f8077b14df8d010533d4fb814de83709215f39d0d550559417eca0c3c1d01dc",
      ),
    },
  };

  static const Map<OmpLinuxLibc, Map<PlatformArch, DirectBinaryRuntimeAsset>> _linuxAssets = {
    OmpLinuxLibc.glibc: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-arm64",
        sha256: "f8d22cfc74d51b41185e4d7188ad88eb0e1e5e388f762ae2f90c21b095d039dd",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-x64",
        sha256: "9c6a0ceb2995da1ba0524fc858f85c39127fd0784226ec91d54e556b8028b951",
      ),
    },
    OmpLinuxLibc.musl: {
      PlatformArch.arm64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-arm64",
        sha256: "c199ec7b4ac4e59c86b570bae3e9fd3e95843f79fa5807354de8997438107fee",
      ),
      PlatformArch.x64: DirectBinaryRuntimeAsset(
        assetName: "omp-linux-musl-x64",
        sha256: "fbba26125946d1a98ced8fc84c55e381ffb60ef568487e13788ec9690664b0eb",
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
  RuntimeVersion get minPathVersion => _version;

  @override
  RuntimeVersion get bundledVersion => _version;

  @override
  RuntimeVersion? parseVersion({required String value}) {
    if (!value.startsWith("omp/")) return null;
    return SemanticRuntimeVersion.tryParse(value: value.substring(4));
  }

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return null;
    return _assets[target.os]?[target.arch];
  }

  /// Whether this release publishes an asset for [target]. Linux support is
  /// known before the host's libc variant is selected asynchronously.
  bool hasAssetFor({required PlatformTarget target}) {
    if (target.os == PlatformOs.linux) return _linuxAssets.values.any((assets) => assets.containsKey(target.arch));
    return assetFor(target: target) != null;
  }

  RuntimeAsset? assetForLinux({required PlatformArch arch, required OmpLinuxLibc libc}) => _linuxAssets[libc]?[arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      "https://github.com/can1357/oh-my-pi/releases/download/v${bundledVersion.raw}/${asset.assetName}";
}
