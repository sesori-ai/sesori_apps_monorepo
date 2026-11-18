import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../deepseek_identity.dart";

/// Pinned Sesori DeepSeek ACP package archives used by managed installation.
class const DeepSeekRuntimeManifest() extends RuntimeManifest {
  static const String minimumVersion = "0.1.5";
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: minimumVersion);

  /// The latest stable adapter release targeted by this plugin.
  static const String targetVersion = "0.2.5";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "199569c89f77ad955cc4c22535fae9348ff9817ef72a75d4810ac2e8e45f5787",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "aa87abff46dd13f8f8a1b79d138b97f7a8baab208c5eb0bdfa0a0213985df1bd",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "2d9d3a9b7aae9f3fea9e82d036240018b1e92a28b81bedd5a62a33ac7c180776",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "f3b8348a2b3060ba2f5173dee053b313af9ff097643fe8c191c2864bb831e4f9",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-windows-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "f97075c7ad3d6ce69158c5339ffd3476d674a67f891d48a8945b8256336ff465",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.2.5-windows-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "79d18242405872258f17ae87a0aab8a3fb6e890ee2696c104d04bd72e61432a5",
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
