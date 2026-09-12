import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../deepseek_identity.dart";

/// Pinned Sesori DeepSeek ACP package archives used by managed installation.
class const DeepSeekRuntimeManifest() extends RuntimeManifest {
  static const String minimumVersion = "0.1.5";
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: minimumVersion);

  /// The latest stable adapter release targeted by this plugin.
  static const String targetVersion = "0.1.6";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "c0763ea25a2ebe85bfa0327e4d75492fc2d3e40c7af6694f3fdf8b1eee8befce",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "54eb6d599307b16808ed47322b48b93fb94083d90816fb32de93c393042414b9",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "eae26c2091cca61d9aeea363caea425bbad7c5b7b8bcab9df5ff77d26e817047",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "7746c6d6a9dfb142c8f7c7f5d1c849dc82cea0de34b29ce6703c9e7dca3afea1",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "591eb5fb1105672e64845770e6db86604431d0fdcb54328fcd49a5452da5e24c",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.6-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "0fc4a31940cb61798d79fd849b469b7f2484e78fc58091cceeec392748bce660",
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
