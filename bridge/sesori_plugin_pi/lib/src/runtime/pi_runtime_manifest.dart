import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../pi_identity.dart";

/// Pinned official Pi package archives used by managed installation.
class const PiRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.99.0");

  /// The latest stable Pi release targeted by this plugin.
  static const String targetVersion = "1.6.1";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "d8fd8e24c2a5054ae383d83b26f6eb6f950edf613917e434a52394f44cd4d933",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "5c2df5744c7828cc8b78c5665a3a785cc073130005c711d35017c6a5c419169a",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "afde641d6c5904d26960ddb4223bf563b0860cf1a0ebc443b85deff67d048753",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "3c7f00715eb512e165c0da8cad314d73c83b54d5bf7748be4adc618fc8357b68",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "1d573e8b02f92d3cc3d386481710144f9091a93775d211663919da9ed4c9d31d",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "dbb007c8c50782de1642382fed777c60252aab080f36eef7823324c574c1f3e4",
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
