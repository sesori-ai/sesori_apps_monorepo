import "package:freezed_annotation/freezed_annotation.dart";

import "file_diff.dart";
import "message.dart";
import "message_part.dart";
import "question.dart";
import "session.dart";
import "session_status.dart";

part "sse_event_data.freezed.dart";

part "sse_event_data.g.dart";

/// Marker sealed type for all SSE events that are scoped to a specific session.
///
/// Any [SseEventData] variant that carries a session context implements this.
/// Use [ConnectionService.sessionEvents] to obtain a filtered stream already
/// typed as [SseSessionEventData], enabling exhaustive switching over only
/// the events that can ever be received for a given session.
sealed class SseSessionEventData {}

/// Typed representation of all known SSE event payloads.
///
/// Uses Freezed [unionKey] on the `"type"` field to auto-deserialize from JSON.
/// Unknown event types cause [fromJson] to throw — callers should catch and
/// report via [FailureReporter.recordFailure].
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SseEventData with _$SseEventData {
  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("server.connected")
  const factory SseEventData.serverConnected() = SseServerConnected;

  @FreezedUnionValue("server.heartbeat")
  const factory SseEventData.serverHeartbeat() = SseServerHeartbeat;

  @FreezedUnionValue("server.instance.disposed")
  const factory SseEventData.serverInstanceDisposed({
    String? directory,
  }) = SseServerInstanceDisposed;

  @FreezedUnionValue("global.disposed")
  const factory SseEventData.globalDisposed() = SseGlobalDisposed;

  // ---------------------------------------------------------------------------
  // Session — all implement SseSessionEventData
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("session.created")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionCreated({
    required Session info,
  }) = SseSessionCreated;

  @FreezedUnionValue("session.updated")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionUpdated({
    required Session info,
  }) = SseSessionUpdated;

  @FreezedUnionValue("session.deleted")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionDeleted({
    required Session info,
  }) = SseSessionDeleted;

  @FreezedUnionValue("session.diff")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionDiff({
    required String sessionID,
    required List<FileDiff> diff,
  }) = SseSessionDiff;

  @FreezedUnionValue("session.error")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionError({
    required String? sessionID,
  }) = SseSessionError;

  @FreezedUnionValue("session.compacted")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionCompacted({
    required String sessionID,
  }) = SseSessionCompacted;

  @FreezedUnionValue("session.status")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionStatus({
    required String sessionID,
    required SessionStatus status,
  }) = SseSessionStatus;

  /// Deprecated — server emits this alongside [sessionStatus] when idle.
  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility
  @Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
  @FreezedUnionValue("session.idle")
  @Implements<SseSessionEventData>()
  const factory SseEventData.sessionIdle({
    required String sessionID,
  }) = SseSessionIdle;

  // ---------------------------------------------------------------------------
  // Message — all implement SseSessionEventData
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("message.updated")
  @Implements<SseSessionEventData>()
  const factory SseEventData.messageUpdated({
    required Message info,
  }) = SseMessageUpdated;

  @FreezedUnionValue("message.removed")
  @Implements<SseSessionEventData>()
  const factory SseEventData.messageRemoved({
    required String sessionID,
    required String messageID,
  }) = SseMessageRemoved;

  @FreezedUnionValue("message.part.updated")
  @Implements<SseSessionEventData>()
  const factory SseEventData.messagePartUpdated({
    required MessagePart part,
  }) = SseMessagePartUpdated;

  @FreezedUnionValue("message.part.delta")
  @Implements<SseSessionEventData>()
  const factory SseEventData.messagePartDelta({
    required String sessionID,
    required String messageID,
    required String partID,
    required String field,
    required String delta,
  }) = SseMessagePartDelta;

  @FreezedUnionValue("message.part.removed")
  @Implements<SseSessionEventData>()
  const factory SseEventData.messagePartRemoved({
    required String sessionID,
    required String messageID,
    required String partID,
  }) = SseMessagePartRemoved;

  // ---------------------------------------------------------------------------
  // PTY
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("pty.created")
  const factory SseEventData.ptyCreated() = SsePtyCreated;

  @FreezedUnionValue("pty.updated")
  const factory SseEventData.ptyUpdated() = SsePtyUpdated;

  @FreezedUnionValue("pty.exited")
  const factory SseEventData.ptyExited({
    String? id,
    int? exitCode,
  }) = SsePtyExited;

  @FreezedUnionValue("pty.deleted")
  const factory SseEventData.ptyDeleted({
    String? id,
  }) = SsePtyDeleted;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("permission.asked")
  @Implements<SseSessionEventData>()
  const factory SseEventData.permissionAsked({
    required String requestID,
    required String sessionID,
    required String tool,
    required String description,
  }) = SsePermissionAsked;

  @FreezedUnionValue("permission.replied")
  @Implements<SseSessionEventData>()
  const factory SseEventData.permissionReplied({
    required String requestID,
    required String sessionID,
    required String reply,
  }) = SsePermissionReplied;

  @FreezedUnionValue("permission.updated")
  const factory SseEventData.permissionUpdated() = SsePermissionUpdated;

  // ---------------------------------------------------------------------------
  // Question
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("question.asked")
  @Implements<SseSessionEventData>()
  const factory SseEventData.questionAsked({
    required String id,
    required String sessionID,
    required List<QuestionInfo> questions,
  }) = SseQuestionAsked;

  @FreezedUnionValue("question.replied")
  @Implements<SseSessionEventData>()
  const factory SseEventData.questionReplied({
    required String requestID,
    required String sessionID,
  }) = SseQuestionReplied;

  @FreezedUnionValue("question.rejected")
  @Implements<SseSessionEventData>()
  const factory SseEventData.questionRejected({
    required String requestID,
    required String sessionID,
  }) = SseQuestionRejected;

  // ---------------------------------------------------------------------------
  // Todo
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("todo.updated")
  @Implements<SseSessionEventData>()
  const factory SseEventData.todoUpdated({
    required String sessionID,
  }) = SseTodoUpdated;

  // ---------------------------------------------------------------------------
  // Project & VCS
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("project.updated")
  const factory SseEventData.projectUpdated() = SseProjectUpdated;

  @FreezedUnionValue("vcs.branch.updated")
  const factory SseEventData.vcsBranchUpdated() = SseVcsBranchUpdated;

  // ---------------------------------------------------------------------------
  // File
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("file.edited")
  const factory SseEventData.fileEdited({
    String? file,
  }) = SseFileEdited;

  @FreezedUnionValue("file.watcher.updated")
  const factory SseEventData.fileWatcherUpdated({
    String? file,
    String? event,
  }) = SseFileWatcherUpdated;

  // ---------------------------------------------------------------------------
  // LSP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("lsp.updated")
  const factory SseEventData.lspUpdated() = SseLspUpdated;

  @FreezedUnionValue("lsp.client.diagnostics")
  const factory SseEventData.lspClientDiagnostics({
    String? serverID,
    String? path,
  }) = SseLspClientDiagnostics;

  // ---------------------------------------------------------------------------
  // MCP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("mcp.tools.changed")
  const factory SseEventData.mcpToolsChanged() = SseMcpToolsChanged;

  @FreezedUnionValue("mcp.browser.open.failed")
  const factory SseEventData.mcpBrowserOpenFailed() = SseMcpBrowserOpenFailed;

  // ---------------------------------------------------------------------------
  // Installation
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("installation.updated")
  const factory SseEventData.installationUpdated({
    String? version,
  }) = SseInstallationUpdated;

  @FreezedUnionValue("installation.update-available")
  const factory SseEventData.installationUpdateAvailable({
    String? version,
  }) = SseInstallationUpdateAvailable;

  // ---------------------------------------------------------------------------
  // Workspace
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("workspace.ready")
  const factory SseEventData.workspaceReady({
    String? name,
  }) = SseWorkspaceReady;

  @FreezedUnionValue("workspace.failed")
  const factory SseEventData.workspaceFailed({
    String? message,
  }) = SseWorkspaceFailed;

  // ---------------------------------------------------------------------------
  // TUI
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("tui.toast.show")
  const factory SseEventData.tuiToastShow({
    String? title,
    String? message,
    String? variant,
  }) = SseTuiToastShow;

  // ---------------------------------------------------------------------------
  // Worktree
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("worktree.ready")
  const factory SseEventData.worktreeReady() = SseWorktreeReady;

  @FreezedUnionValue("worktree.failed")
  const factory SseEventData.worktreeFailed() = SseWorktreeFailed;

  factory SseEventData.fromJson(Map<String, dynamic> json) => _$SseEventDataFromJson(json);
}
