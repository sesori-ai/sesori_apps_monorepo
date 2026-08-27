import "dart:io" show Platform;

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";

import "../copilot_binary.dart";
import "../copilot_identity.dart";

/// Version and path policy for GitHub Copilot CLI.
///
/// Managed release assets are added separately from lifecycle/setup support;
/// until then [assetFor] intentionally returns null and installation is not
/// advertised. Existing compatible PATH and explicit runtimes remain usable.
class const CopilotRuntimeManifest() extends RuntimeManifest {
  /// Copilot 1.0.78 added the ACP `session/close` capability used by Sesori's
  /// standard session lifecycle.
  static final SemanticRuntimeVersion _minPathVersion = SemanticRuntimeVersion.parse(value: "1.0.78");

  /// Stable release validated against this plugin's ACP surface.
  static const String targetVersion = "1.0.80";

  static final SemanticRuntimeVersion _bundledVersion = SemanticRuntimeVersion.parse(value: targetVersion);

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

  /// Copilot prints `GitHub Copilot CLI 1.0.80.`. The shared validator tries
  /// each whitespace-delimited token, so this parser accepts both a bare
  /// semantic version and Copilot's sentence-final version token.
  @override
  RuntimeVersion? parseVersion({required String value}) {
    final trimmed = value.trim();
    final candidate = trimmed.endsWith(".") ? trimmed.substring(0, trimmed.length - 1) : trimmed;
    return SemanticRuntimeVersion.tryParse(value: candidate);
  }

  @override
  RuntimeAsset? assetFor({required PlatformTarget target}) => null;

  @override
  String downloadUrlFor({required RuntimeAsset asset}) => githubReleaseAssetUrl(
    repository: "github/copilot-cli",
    tag: "v${bundledVersion.raw}",
    asset: asset,
  );
}
