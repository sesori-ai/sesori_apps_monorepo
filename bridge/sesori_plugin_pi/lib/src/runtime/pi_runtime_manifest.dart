import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../pi_identity.dart";

/// Pinned official Pi package archives used by managed installation.
class const PiRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.84.1");

  /// The latest stable Pi release targeted by this plugin.
  static const String targetVersion = "0.87.1";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "4f8d288b78c9768d3a4ac6f61f06cd34394b82ac17d5b42d1e44a437add401b7",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "01d8ee28d7114fec4f4eeedbb7561f790853040e9bfbdeebe79437ab66ea51f5",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "364b4a9f8491450b27a4857d4e3c780dbaf696790821c176a873e860cbbc3b89",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "80d78dd62d50049a006b981d994c61255bcc10e730b0c278d4ea0a755909764c",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "2e0d544999a765018ee5c2ff1a8b1a7e0f5d5b6b1e00b32d8c025d6c1dbcc833",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "aab2ba67baf8ff97a52d05b62d88e9e65a840c6ea8fa1029a28d62d210d4e5fc",
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
