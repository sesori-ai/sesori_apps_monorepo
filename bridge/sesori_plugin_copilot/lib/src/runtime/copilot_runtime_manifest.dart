import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";

/// Version, path, and pinned managed-release policy for GitHub Copilot CLI.
class const CopilotRuntimeManifest() extends RuntimeManifest {
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.0.78");

  static const String targetVersion = "1.0.115";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

  static const Map<PlatformOs, Map<PlatformArch, RuntimeAsset>> _assets = {
    PlatformOs.macos: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "f0858bbff5e35c4fe92d97a0061cb4a2a12b06defacf5512b77ca294175a12cf",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-darwin-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e6fb406eea63683563bb9420d4c1c6c09c53156ccd819b9c45560ddf014a7ee9",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.linux: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-arm64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "889b423ce7e0dd41a298b95716d3d8fe80dc30f1fd9cf5419a95b6fb8d4e1bc8",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-linux-x64.tar.gz",
        format: ArchiveFormat.tarGz,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "e01975bf3a73791b0c0adfdf0d7093b8616186db61b78b33604b124806808816",
        archiveBinaryName: "copilot",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
    },
    PlatformOs.windows: {
      PlatformArch.arm64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-arm64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "cc3accfcf3bbce431cf9cd41198aec1e81c11908542825a6031726e6eac215cc",
        archiveBinaryName: "copilot.exe",
        layout: RuntimeArchiveLayout.singleBinary,
      ),
      PlatformArch.x64: ArchiveRuntimeAsset(
        assetName: "copilot-win32-x64.zip",
        format: ArchiveFormat.zip,
        archiveCommandTimeout: Duration(minutes: 2),
        sha256: "256de3c3b8c00cbe5f738c9830f30b1d790d6693563689baade984295606af2c",
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
