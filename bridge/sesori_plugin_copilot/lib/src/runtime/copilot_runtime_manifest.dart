import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";

/// Version, path, and pinned managed-release policy for GitHub Copilot CLI.
class const CopilotRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.0.78");

  static const String targetVersion = "1.0.80";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "2346bb691981c2997d65c1c5bc3cef1aeddc9edd37dcb2f970b911aa597e59f6",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "a1a9c1f25740f9a27b34eb14b70b5d3175794dc8bb410875531aa198b3abc18f",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "3ed85e711955e13be523bf492bc6c93b40b69925bcb7f817c9d08abf4839cf89",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "039933c9247686131c4406abb1d439bdbf68103edc1ff585bd70d5b0dc940f72",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "c551da2377b99f08ff95cca6c1603c0006295c2ca7786ba1c8be7c05dc7943a7",
        archiveBinaryName: "copilot.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "e9ea2063913faa8a9f1cf374529c5fea075da0545a894d7469026166f854c541",
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
