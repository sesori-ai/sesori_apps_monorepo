import "package:freezed_annotation/freezed_annotation.dart";

import "message.dart";
import "message_part.dart";
import "project_activity_summary.dart";
import "question.dart";
import "session.dart";
import "session_status.dart";

part "sesori_sse_event.freezed.dart";

part "sesori_sse_event.g.dart";

/// Marker sealed type for all SSE events that are scoped to a specific session.
///
/// Any [SesoriSseEvent] variant that carries a session context implements this.
/// Use [ConnectionService.sessionEvents] to obtain a filtered stream already
/// typed as [SesoriSessionEvent], enabling exhaustive switching over only
/// the events that can ever be received for a given session.
sealed class SesoriSessionEvent {}

/// Typed representation of all known SSE event payloads.
///
/// Uses Freezed [unionKey] on the `"type"` field to auto-deserialize from JSON.
/// Unknown event types cause [fromJson] to throw — callers should catch and
/// report via [FailureReporter.recordFailure].
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SesoriSseEvent with _$SesoriSseEvent {
  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("server.connected")
  const factory SesoriSseEvent.serverConnected() = SesoriServerConnected;

  @FreezedUnionValue("server.heartbeat")
  const factory SesoriSseEvent.serverHeartbeat() = SesoriServerHeartbeat;

  @FreezedUnionValue("server.instance.disposed")
  const factory SesoriSseEvent.serverInstanceDisposed({
    String? directory,
  }) = SesoriServerInstanceDisposed;

  @FreezedUnionValue("global.disposed")
  const factory SesoriSseEvent.globalDisposed() = SesoriGlobalDisposed;

  // ---------------------------------------------------------------------------
  // Session — all implement SesoriSessionEvent
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("session.created")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionCreated({
    required Session info,
  }) = SesoriSessionCreated;

  @FreezedUnionValue("session.updated")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionUpdated({
    required Session info,
  }) = SesoriSessionUpdated;

  @FreezedUnionValue("session.deleted")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionDeleted({
    required Session info,
  }) = SesoriSessionDeleted;

  @FreezedUnionValue("session.diff")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionDiff({
    required String sessionID,
  }) = SesoriSessionDiff;

  @FreezedUnionValue("session.error")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionError({
    required String sessionID,
  }) = SesoriSessionError;

  @FreezedUnionValue("session.compacted")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionCompacted({
    required String sessionID,
  }) = SesoriSessionCompacted;

  @FreezedUnionValue("session.status")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionStatus({
    required String sessionID,
    required SessionStatus status,
  }) = SesoriSessionStatus;

  /// Deprecated — server emits this alongside [sessionStatus] when idle.
  // ignore: remove_deprecations_in_breaking_versions
  @Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
  @FreezedUnionValue("session.idle")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.sessionIdle({
    required String sessionID,
  }) = SesoriSessionIdle;

  // ---------------------------------------------------------------------------
  // Message — all implement SesoriSessionEvent
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("message.updated")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.messageUpdated({
    required Message info,
  }) = SesoriMessageUpdated;

  @FreezedUnionValue("message.removed")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.messageRemoved({
    required String sessionID,
    required String messageID,
  }) = SesoriMessageRemoved;

  @FreezedUnionValue("message.part.updated")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.messagePartUpdated({
    required MessagePart part,
  }) = SesoriMessagePartUpdated;

  @FreezedUnionValue("message.part.delta")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.messagePartDelta({
    required String sessionID,
    required String messageID,
    required String partID,
    required String field,
    required String delta,
  }) = SesoriMessagePartDelta;

  @FreezedUnionValue("message.part.removed")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.messagePartRemoved({
    required String sessionID,
    required String messageID,
    required String partID,
  }) = SesoriMessagePartRemoved;

  // ---------------------------------------------------------------------------
  // PTY
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("pty.created")
  const factory SesoriSseEvent.ptyCreated() = SesoriPtyCreated;

  @FreezedUnionValue("pty.updated")
  const factory SesoriSseEvent.ptyUpdated() = SesoriPtyUpdated;

  @FreezedUnionValue("pty.exited")
  const factory SesoriSseEvent.ptyExited({
    required String? id,
    required int? exitCode,
  }) = SesoriPtyExited;

  @FreezedUnionValue("pty.deleted")
  const factory SesoriSseEvent.ptyDeleted({
    String? id,
  }) = SesoriPtyDeleted;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("permission.asked")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.permissionAsked({
    required String requestID,
    required String sessionID,
    required String tool,
    required String description,
  }) = SesoriPermissionAsked;

  @FreezedUnionValue("permission.replied")
  const factory SesoriSseEvent.permissionReplied({
    required String requestID,
    required String reply,
  }) = SesoriPermissionReplied;

  @FreezedUnionValue("permission.updated")
  const factory SesoriSseEvent.permissionUpdated() = SesoriPermissionUpdated;

  // ---------------------------------------------------------------------------
  // Question
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("question.asked")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.questionAsked({
    required String id,
    required String sessionID,
    required List<QuestionInfo> questions,
  }) = SesoriQuestionAsked;

  @FreezedUnionValue("question.replied")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.questionReplied({
    required String requestID,
    required String sessionID,
  }) = SesoriQuestionReplied;

  @FreezedUnionValue("question.rejected")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.questionRejected({
    required String requestID,
    required String sessionID,
  }) = SesoriQuestionRejected;

  // ---------------------------------------------------------------------------
  // Todo
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("todo.updated")
  @Implements<SesoriSessionEvent>()
  const factory SesoriSseEvent.todoUpdated({
    required String sessionID,
  }) = SesoriTodoUpdated;

  // ---------------------------------------------------------------------------
  // Project & VCS
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("projects.summary")
  const factory SesoriSseEvent.projectsSummary({
    required List<ProjectActivitySummary> projects,
  }) = SesoriProjectsSummary;

  @FreezedUnionValue("project.updated")
  const factory SesoriSseEvent.projectUpdated() = SesoriProjectUpdated;

  @FreezedUnionValue("vcs.branch.updated")
  const factory SesoriSseEvent.vcsBranchUpdated() = SesoriVcsBranchUpdated;

  // ---------------------------------------------------------------------------
  // File
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("file.edited")
  const factory SesoriSseEvent.fileEdited({
    String? file,
  }) = SesoriFileEdited;

  @FreezedUnionValue("file.watcher.updated")
  const factory SesoriSseEvent.fileWatcherUpdated({
    required String? file,
    required String? event,
  }) = SesoriFileWatcherUpdated;

  // ---------------------------------------------------------------------------
  // LSP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("lsp.updated")
  const factory SesoriSseEvent.lspUpdated() = SesoriLspUpdated;

  @FreezedUnionValue("lsp.client.diagnostics")
  const factory SesoriSseEvent.lspClientDiagnostics({
    required String? serverID,
    required String? path,
  }) = SesoriLspClientDiagnostics;

  // ---------------------------------------------------------------------------
  // MCP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("mcp.tools.changed")
  const factory SesoriSseEvent.mcpToolsChanged() = SesoriMcpToolsChanged;

  @FreezedUnionValue("mcp.browser.open.failed")
  const factory SesoriSseEvent.mcpBrowserOpenFailed() = SesoriMcpBrowserOpenFailed;

  // ---------------------------------------------------------------------------
  // Installation
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("installation.updated")
  const factory SesoriSseEvent.installationUpdated({
    String? version,
  }) = SesoriInstallationUpdated;

  @FreezedUnionValue("installation.update-available")
  const factory SesoriSseEvent.installationUpdateAvailable({
    String? version,
  }) = SesoriInstallationUpdateAvailable;

  // ---------------------------------------------------------------------------
  // Workspace
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("workspace.ready")
  const factory SesoriSseEvent.workspaceReady({
    String? name,
  }) = SesoriWorkspaceReady;

  @FreezedUnionValue("workspace.failed")
  const factory SesoriSseEvent.workspaceFailed({
    String? message,
  }) = SesoriWorkspaceFailed;

  // ---------------------------------------------------------------------------
  // TUI
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("tui.toast.show")
  const factory SesoriSseEvent.tuiToastShow({
    required String? title,
    required String? message,
    required String? variant,
  }) = SesoriTuiToastShow;

  // ---------------------------------------------------------------------------
  // Worktree
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("worktree.ready")
  const factory SesoriSseEvent.worktreeReady() = SesoriWorktreeReady;

  @FreezedUnionValue("worktree.failed")
  const factory SesoriSseEvent.worktreeFailed() = SesoriWorktreeFailed;

  factory SesoriSseEvent.fromJson(Map<String, dynamic> json) => _$SesoriSseEventFromJson(json);
}
