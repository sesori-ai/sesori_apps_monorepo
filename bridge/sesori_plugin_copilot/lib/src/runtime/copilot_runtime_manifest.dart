import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";

/// Version, path, and pinned managed-release policy for GitHub Copilot CLI.
class const CopilotRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.0.78");

  static const String targetVersion = "1.0.116";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "acaa227712860978d8a73a7a64395f64dba2c77fcab2304fa21a995f12355584",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "86ed34686e86e6685e21e7fc318c0aaaea30a6a214926925a4665b7ed7ec7682",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ba3207afd858a93b63c5ccd83c53f43fdb20fc00fd43260a532fb14b5f8d0776",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "ffea833980a9767a18aff7fd8459085a044266c26ca6a9edafe59cdcff718c79",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "977f63d1f5e8c1df433d01c6258974ee7dc0bcf905b74962465d132baebd43b8",
        archiveBinaryName: "copilot.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "5de1c201158582252f915cd375badfde7d54ff247cf15dc97db97f71d4a4e1a7",
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

  // The launcher can hand off to a newer package it cached; the session runs
  // with `--no-auto-update`, so the probe must too to report the same binary.
  @override
  List<String> get versionProbeArguments => const ["--no-auto-update", "--version"];

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => _assets[target.os]?[target.arch];

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => githubReleaseAssetUrl(
    repository: "github/copilot-cli",
    tag: "v${bundledVersion.raw}",
    asset: asset,
  );
}
