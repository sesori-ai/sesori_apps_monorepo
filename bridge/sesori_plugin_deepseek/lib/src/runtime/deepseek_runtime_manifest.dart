import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../deepseek_identity.dart";

/// Pinned Sesori DeepSeek ACP package archives used by managed installation.
class const DeepSeekRuntimeManifest() extends RuntimeManifest {
  static const String minimumVersion = "0.1.5";
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: minimumVersion);

  /// The latest stable adapter release targeted by this plugin.
  static const String targetVersion = "0.2.1";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "3ca8d94553514796f59f890282f2b065d1d639434fd2125c4869088e8e2703da",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "294edfd30f42f661166efa473e9376dd9575deff5e27d8b1aec06b34945f362a",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "9010b419f477aa4af4286e5a0ba396ee3fd0fb9ea5cee7d7a23c41833c989499",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ea0a220e9962c0f0becb6e4f35b9fe819aa59af272e721098444df6c626bfcba",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "72e21092c59f92d84a4590be3b6c449b229342cb21cba864ccb4988684bfe3d6",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.1-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "21d764720fdd55cfa360fe762c94bdcd5ce1ca58189368943ed0c83ed302a6b5",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
  };

  @override
  String get runtimeId => DeepSeekIdentity.id;

  @override
  String get displayName => "Sesori DeepSeek adapter";

  @override
  String get installDocsUrl => "https://github.com/sesori-ai/sesori-deepseek-acp";

  @override
  String get pathExecutableName => "sesori-deepseek-acp";

  @override
  String get binaryFileName => Platform.isWindows ? "sesori-deepseek-acp.cmd" : "sesori-deepseek-acp";

  @override
  RuntimeVersion get minPathVersion => _minPathVersion;

  @override
  RuntimeVersion get bundledVersion => _bundledVersion;

  @override
  RuntimeVersion? parseVersion({required String value}) {
    const prefix = "sesori-deepseek-acp/";
    final candidate = value.startsWith(prefix) ? value.substring(prefix.length) : value;
    return SemanticRuntimeVersion.tryParse(value: candidate);
  }

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _assets[target.os]?[target.arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) =>
      "https://github.com/sesori-ai/sesori-deepseek-acp/releases/download/v${bundledVersion.raw}/${asset.assetName}";
}
