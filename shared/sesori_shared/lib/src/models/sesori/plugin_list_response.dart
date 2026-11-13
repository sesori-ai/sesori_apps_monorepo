import "package:freezed_annotation/freezed_annotation.dart";

import "mcp.dart";

part "plugin_list_response.freezed.dart";
part "plugin_list_response.g.dart";

enum PluginLifecycleState() {
  unavailable,
  ready,
  degraded,
  failed,
}

/// What a harness the bridge stopped after a refused request needs before it
/// starts again. Only a fresh setup check lifts it, once the user has fixed
/// the cause.
enum PluginFailureBlock() {
  /// Its backend login stopped working.
  authenticationRequired,

  /// Something outside the backend's own login refused it, such as the
  /// gateway configured for it.
  unavailable,

  /// A reason this app does not know yet.
  unknown,
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginMetadata with _$PluginMetadata {
  const factory({
    required String id,
    required String displayName,
    required bool isDefault,
    @JsonKey(unknownEnumValue: PluginLifecycleState.unavailable) required PluginLifecycleState state,
    required String? actionHint,

    /// Set while the bridge holds this harness back after a refused request,
    /// which lists it although its [state] is unavailable, so the user can
    /// pick it, read why and check setup again; [actionHint] then says what to
    /// fix. Null for every other harness.
    // COMPATIBILITY 2026-11-09 (v1.12.0): Bridges before this field omit it and
    // leave a held-back harness out of the list, so null (not held back) needs
    // no fallback. Nothing to remove once those bridges are unsupported.
    @JsonKey(unknownEnumValue: PluginFailureBlock.unknown) required PluginFailureBlock? failureBlock,
    // COMPATIBILITY 2026-08-04 (v1.8.0): Older bridges omit this
    // per-plugin capability. Unknown plugins stay disabled; the client
    // repository narrowly restores released legacy OpenCode support from the
    // enclosing response's legacy capability signal. Remove @Default and that
    // mapping once those bridges are unsupported.
    @Default(false) bool supportsPromptAttachments,

    /// Where this harness answers MCP inventory; empty when it has no MCP
    /// support. Mirrors `PluginManagementMetadata.mcpScopes`.
    // COMPATIBILITY 2026-11-09 (v1.12.0): Older bridge payloads omit mcpScopes;
    // null means the bridge did not report them, so clients keep offering
    // session MCP as before. Make it non-nullable once the minimum supported
    // bridge sends it.
    @JsonKey(unknownEnumValue: McpScopeKind.unknown) required Set<McpScopeKind>? mcpScopes,

    /// Why a failed harness could not start, in words its plugin wrote for the
    /// user. Mirrors `PluginManagementMetadata.failureReason`: null when the
    /// harness has not failed or gave no such reason; older bridges omit it,
    /// which reads the same.
    required String? failureReason,

    /// Whether this plugin's confirmed command turns carry
    /// `MessageUser.invocation`, so a client can show a command as its card
    /// from the moment it is sent.
    // COMPATIBILITY 2026-11-12 (v1.13.0): Older bridges omit this capability because they never name invocations.
    // Remove @Default and require the field once all supported production bridges send it.
    @Default(false) bool namesCommandInvocations,
  }) = _PluginMetadata;

  factory fromJson(Map<String, dynamic> json) => _$PluginMetadataFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class PluginListResponse with _$PluginListResponse {
  const factory({
    required List<PluginMetadata> plugins,
    // COMPATIBILITY 2026-07-26 (v1.7.0): Bridges predating per-bridge harness
    // preferences omit the ID; null disables preference recall. Remove the
    // nullable path once those bridges are unsupported.
    required String? bridgeId,
    // COMPATIBILITY 2026-07-30 (v1.8.0): Old bridges omit this capability,
    // which means session options are unsupported. Remove @Default and require
    // supportsSessionOptions once those bridges are unsupported.
    @Default(false) bool supportsSessionOptions,

    /// Whether the bridge saves prompt files that it doesn't pass to the
    /// plugin inline, and gives the agent their paths (see
    /// `PromptPart.fileData`).
    // COMPATIBILITY 2026-11-08 (v1.12.0): Bridges before file uploads omit this, so
    // only images reach them and the client says so. Remove @Default and require
    // supportsFileUploads once those bridges are unsupported.
    @Default(false) bool supportsFileUploads,
  }) = _PluginListResponse;

  factory fromJson(Map<String, dynamic> json) => _$PluginListResponseFromJson(json);
}
