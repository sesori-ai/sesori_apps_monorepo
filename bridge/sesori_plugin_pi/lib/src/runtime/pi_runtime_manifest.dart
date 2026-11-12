import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../pi_identity.dart";

/// Pinned official Pi package archives used by managed installation.
class const PiRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.99.0");

  /// The latest stable Pi release targeted by this plugin.
  static const String targetVersion = "1.5.2";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "56b5e194d485ced555667b8ba3276157a8272e9ecde9e001e428af80985bdd9b",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "f997a088613514ac97d913aeea7642094d84fe6d46854ff7e64e2c12e536dc50",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "42805cd5615952fcbbfc9c56b04f8feb84395134952e169a6cdc8d7676975666",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "811c6f2c9e7aaee252b5404252e556fb713aa209c1f7f924226aa77d4ef70cb5",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e83404bc5a6003ac950683edd9b6cf499dac91ec890d8439a8c32528de534a77",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e6adb8cb8c84eca14391ad24b363de9d2be98a89ca3ba3fdee1fa4de32b7f2e8",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
  };

  @override
  String get runtimeId => PiPluginIdentity.id;

  @override
  String get displayName => PiPluginIdentity.displayName;

  @override
  String get installDocsUrl => "https://github.com/earendil-works/pi";

  @override
  String get pathExecutableName => "pi";

  @override
  String get binaryFileName => Platform.isWindows ? "pi.exe" : "pi";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) => SemanticRuntimeVersion.tryParse(value: value);

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _assets[target.os]?[target.arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      githubReleaseAssetUrl(repository: "earendil-works/pi", tag: "v${bundledVersion.raw}", asset: asset);
}
