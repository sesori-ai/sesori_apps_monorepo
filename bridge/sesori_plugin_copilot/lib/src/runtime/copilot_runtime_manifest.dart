import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";

/// Version, path, and pinned managed-release policy for GitHub Copilot CLI.
class const CopilotRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.0.78");

  static const String targetVersion = "1.0.83";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "80a5ded6f1db484b4661af676ea914605ecfbcaf49f6b4bed81e6df16cbd56bd",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "7e4f7236b0cd5ee474e6ab6d35ea67b8c33d5ec6483498e0fdd0218f458b2d53",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "213b3a267042dbac3cd8ae22c82f5ea04ff3cabc008108c0f895055d46be4473",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ffbe1c429664b8a05efed67ecdb467123e40fcaa3c6c14ef9a98ba74da4687b7",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "63f35c0ce1a5fdcc6f3e584890d689b1ede8f930933394aaf7b5e139b53d2cc1",
        archiveBinaryName: "copilot.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "0e07221a275fdf7e61619c53566e3a421fd646d74d8e9ca491dbbff221f22945",
        archiveBinaryName: "copilot.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
  };

  @override
  String get runtimeId => CopilotPluginIdentity.id;

  @override
  String get displayName => CopilotPluginIdentity.displayName;

  @override
  String get installDocsUrl =>
      "https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli";

  @override
  String get pathExecutableName => CopilotBinary.defaultBinary;

  @override
  String get binaryFileName => Platform.isWindows ? "copilot.exe" : "copilot";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) {
    final trimmed = value.trim();
    final candidate = trimmed.endsWith(".") ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return SemanticRuntimeVersion.tryParse(value: candidate);
  }

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _assets[target.os]?[target.arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => githubReleaseAssetUrl(
    repository: "github/copilot-cli",
    tag: "v${bundledVersion.raw}",
    asset: asset,
  );
}
