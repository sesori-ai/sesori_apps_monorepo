import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../deepseek_identity.dart";

/// Pinned Sesori DeepSeek ACP package archives used by managed installation.
class const DeepSeekRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "0.1.3");

  /// The latest stable adapter release targeted by this plugin.
  static const String targetVersion = "0.1.3";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "049fbefba7df7ef49a2903aa49f323f923d087417a313708d489c8cefee2f970",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "87fb9745676a974b20259218100880fdd2d73c862632fcf8e1742b1f08aef55b",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "58f1e99af263f472560ef174540c72c25300261912088a7aee63dafcdf110531",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        sha256: "415a20b0d3905d5463de341b1cdc2077eabed03a0fccce5065b48858b5fdf0f8",
        archiveBinaryName: "sesori-deepseek-acp",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-windows-arm64.zip",
        format: ArchiveFormat.zip,
        sha256: "360f343ba567884414b678d5cda8ca5b65bcddd828ca199b43aa3eb16efbcba3",
        archiveBinaryName: "sesori-deepseek-acp.cmd",
        layout: RuntimeArchiveLayout.packageDirectory,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "sesori-deepseek-acp-v0.1.3-windows-x64.zip",
        format: ArchiveFormat.zip,
        sha256: "8ed39e6ca18b78ab12477fc94514b80a13dcd8970ccb1f1dea26bf3854d1c993",
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
