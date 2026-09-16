import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../deepseek_identity.dart";

/// Pinned Sesori DeepSeek ACP package archives used by managed installation.
class const DeepSeekRuntimeManifest() extends RuntimeManifest {
  static const String minimumVersion = "0.1.5";
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: minimumVersion);

  /// The latest stable adapter release targeted by this plugin.
  static const String targetVersion = "0.1.7";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "800c054403a9be01a68ff71a0315c05cf3a854891c7b004f24cc9514a697d67b",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "74b2ed9a630f84b804c7d3184eda62125f9c9cb9723957a5c166d657af9586ce",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "d356a85050d1c1525c41ed29ea327ea0df6888983cfab32ed5c452ef57e7d79b",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ace7c89372d40e358ddc804292056a8260b8acd0337b88b87aec7034f583a5ec",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "642723f499f4452d09bd75ab1b67c70894e65383c0b08e82597e89e86b77f3a7",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.7-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "9a342a51535cdd876aa6084a3e80d08f3e6f8fe5ea91a64eba8a2a34b2c3f14c",
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
