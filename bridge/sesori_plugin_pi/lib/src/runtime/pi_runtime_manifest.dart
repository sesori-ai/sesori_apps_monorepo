import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../pi_plugin_impl.dart";

/// Pinned official Pi package archives used by managed installation.
class const PiRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.84.1");
  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: "0.84.2");

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "c996e888b7f7dce44bcf24f69176ac646c44139d3916bd49a6b28e5a8c5e3a65",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "808cf02a93cd601d3ea05d47dc15c45074b120ac81decc8644cd3e40a35824e6",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "d15372da9e4b4c5fef9fd15bed76d7f5f1720dd39fe7cde0ec62e5b65ad63ef1",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "906fbe787fd225c4ac624fe7ebd5b1d55a60e0f5c7ef51795d231564f9ee1c13",
        archiveBinaryName: "pi",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "pi-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "092e2b276e0066efcb3d860465591c2e32ea48ee90395d34ceda0d84d8ff4470",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "pi-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "741fc1ae1afecb573ac2888e011188ff446b3940f4aabe1583f60bf55be8a3d0",
        archiveBinaryName: "pi.exe",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
  };

  @override
  String get runtimeId => PiPlugin.pluginId;

  @override
  String get displayName => "Pi";

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
      "https://github.com/earendil-works/pi/releases/download/v${bundledVersion.raw}/${asset.assetName}";
}
