import "package:freezed_annotation/freezed_annotation.dart";

import "catalog_import_progress.dart";
import "message.dart";
import "message_part.dart";
import "plugin_management.dart";
import "project_activity_summary.dart";
import "question.dart";
import "queued_prompt.dart";
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
sealed class SesoriSessionEvent();

/// Typed representation of all known SSE event payloads.
///
/// Uses Freezed [unionKey] on the `"type"` field to auto-deserialize from JSON.
/// Unknown event types cause [fromJson] to throw so transport callers can skip
/// events introduced by newer peers without hiding malformed known payloads.
@Freezed(unionKey: "type", fromJson: true, toJson: true)
sealed class SesoriSseEvent with _$SesoriSseEvent {
  // ---------------------------------------------------------------------------
  // System
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("server.connected")
  const factory serverConnected() = SesoriServerConnected;

  @FreezedUnionValue("server.heartbeat")
  const factory serverHeartbeat() = SesoriServerHeartbeat;

  @FreezedUnionValue("server.instance.disposed")
  const factory serverInstanceDisposed({
    String? directory,
  }) = SesoriServerInstanceDisposed;

  @FreezedUnionValue("global.disposed")
  const factory globalDisposed() = SesoriGlobalDisposed;

  @FreezedUnionValue("catalog.import.progress")
  const factory catalogImportProgress({
    required CatalogImportProgress progress,
  }) = SesoriCatalogImportProgress;

  @FreezedUnionValue("plugin.management.changed")
  const factory pluginManagementChanged({
    required String snapshotToken,
  }) = SesoriPluginManagementChanged;

  /// Progress of a phone-triggered managed runtime install for one plugin.
  /// [percent] is only meaningful while [PluginInstallPhase.downloading] with a
  /// known total; [message] carries a sanitized failure description only on
  /// [PluginInstallPhase.failed].
  @FreezedUnionValue("plugin.install.progress")
  const factory pluginInstallProgress({
    required String pluginId,
    @JsonKey(unknownEnumValue: PluginInstallPhase.unknown) required PluginInstallPhase phase,
    required int? percent,
    required String? message,
  }) = SesoriPluginInstallProgress;

  /// Terminal progress for one plugin authentication operation. Challenges are
  /// request-scoped and never enter SSE replay or persistence.
  @FreezedUnionValue("plugin.authentication.progress")
  const factory pluginAuthenticationProgress({
    required String pluginId,
    required PluginAuthenticationProgress progress,
  }) = SesoriPluginAuthenticationProgress;

  /// Invalidates the process-wide slash-command catalog for one plugin.
  @FreezedUnionValue("command.catalog.updated")
  const factory commandCatalogUpdated({
    required String pluginId,
  }) = SesoriCommandCatalogUpdated;

  // ---------------------------------------------------------------------------
  // Session — all implement SesoriSessionEvent
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("session.created")
  @Implements<SesoriSessionEvent>()
  const factory sessionCreated({
    required Session info,
  }) = SesoriSessionCreated;

  @FreezedUnionValue("session.updated")
  @Implements<SesoriSessionEvent>()
  const factory sessionUpdated({
    required Session info,
  }) = SesoriSessionUpdated;

  @FreezedUnionValue("session.deleted")
  @Implements<SesoriSessionEvent>()
  const factory sessionDeleted({
    required Session info,
  }) = SesoriSessionDeleted;

  @FreezedUnionValue("session.diff")
  @Implements<SesoriSessionEvent>()
  const factory sessionDiff({
    required String sessionID,
  }) = SesoriSessionDiff;

  @FreezedUnionValue("session.error")
  @Implements<SesoriSessionEvent>()
  const factory sessionError({
    required String? sessionID,
  }) = SesoriSessionError;

  @FreezedUnionValue("session.compacted")
  @Implements<SesoriSessionEvent>()
  const factory sessionCompacted({
    required String sessionID,
  }) = SesoriSessionCompacted;

  @FreezedUnionValue("session.prompt_defaults_changed")
  @Implements<SesoriSessionEvent>()
  const factory sessionPromptDefaultsChanged({
    required String sessionID,
    required SessionPromptDefaults promptDefaults,
  }) = SesoriSessionPromptDefaultsChanged;

  @FreezedUnionValue("session.status")
  @Implements<SesoriSessionEvent>()
  const factory sessionStatus({
    required String sessionID,
    required SessionStatus status,
  }) = SesoriSessionStatus;

  @FreezedUnionValue("command.executed")
  @Implements<SesoriSessionEvent>()
  const factory commandExecuted({
    required String name,
    required String sessionID,
    required String arguments,
    required String messageID,
  }) = SesoriCommandExecuted;

  /// Full replacement of the session's bridge-owned queued-prompt list.
  ///
  /// Emitted whenever the queue changes (accept, cancel, dispatch, abort,
  /// failure). Carries the complete current list rather than a delta so a
  /// missed event self-heals on the next one.
  @FreezedUnionValue("session.queued-prompts")
  @Implements<SesoriSessionEvent>()
  const factory sessionQueuedPrompts({
    required String sessionID,
    required List<QueuedSessionPrompt> prompts,
  }) = SesoriSessionQueuedPrompts;

  // ---------------------------------------------------------------------------
  // Message — all implement SesoriSessionEvent
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("message.updated")
  @Implements<SesoriSessionEvent>()
  const factory messageUpdated({
    required Message info,
  }) = SesoriMessageUpdated;

  @FreezedUnionValue("message.removed")
  @Implements<SesoriSessionEvent>()
  const factory messageRemoved({
    required String sessionID,
    required String messageID,
  }) = SesoriMessageRemoved;

  @FreezedUnionValue("message.part.updated")
  @Implements<SesoriSessionEvent>()
  const factory messagePartUpdated({
    required MessagePart part,
  }) = SesoriMessagePartUpdated;

  @FreezedUnionValue("message.part.delta")
  @Implements<SesoriSessionEvent>()
  const factory messagePartDelta({
    required String sessionID,
    required String messageID,
    required String partID,
    required String field,
    required String delta,
  }) = SesoriMessagePartDelta;

  @FreezedUnionValue("message.part.removed")
  @Implements<SesoriSessionEvent>()
  const factory messagePartRemoved({
    required String sessionID,
    required String messageID,
    required String partID,
  }) = SesoriMessagePartRemoved;

  // ---------------------------------------------------------------------------
  // PTY
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("pty.created")
  const factory ptyCreated() = SesoriPtyCreated;

  @FreezedUnionValue("pty.updated")
  const factory ptyUpdated() = SesoriPtyUpdated;

  @FreezedUnionValue("pty.exited")
  const factory ptyExited({
    required String? id,
    required int? exitCode,
  }) = SesoriPtyExited;

  @FreezedUnionValue("pty.deleted")
  const factory ptyDeleted({
    String? id,
  }) = SesoriPtyDeleted;

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("permission.asked")
  @Implements<SesoriSessionEvent>()
  const factory permissionAsked({
    required String requestID,
    required String sessionID,

    /// Top-most root session this request should be surfaced under (for a
    /// child/sub-agent session's request). Null when unknown; consumers fall
    /// back to [sessionID].
    required String? displaySessionId,
    required String tool,
    required String description,
    // COMPATIBILITY 2026-08-10 (v1.8.0): Older bridges omit this capability;
    // remove the default after the minimum supported bridge sends it.
    @Default(true) bool allowAlways,
  }) = SesoriPermissionAsked;

  @FreezedUnionValue("permission.replied")
  @Implements<SesoriSessionEvent>()
  const factory permissionReplied({
    required String requestID,
    required String sessionID,

    /// Root session this request is surfaced under; null ⇒ fall back to
    /// [sessionID].
    required String? displaySessionId,
    required String reply,
  }) = SesoriPermissionReplied;

  @FreezedUnionValue("permission.updated")
  const factory permissionUpdated() = SesoriPermissionUpdated;

  // ---------------------------------------------------------------------------
  // Question
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("question.asked")
  @Implements<SesoriSessionEvent>()
  const factory questionAsked({
    required String id,
    required String sessionID,

    /// Top-most root session this request should be surfaced under (for a
    /// child/sub-agent session's request). Null when unknown; consumers fall
    /// back to [sessionID].
    required String? displaySessionId,
    required List<QuestionInfo> questions,
  }) = SesoriQuestionAsked;

  @FreezedUnionValue("question.replied")
  @Implements<SesoriSessionEvent>()
  const factory questionReplied({
    required String requestID,
    required String sessionID,

    /// Root session this request is surfaced under; null ⇒ fall back to
    /// [sessionID].
    required String? displaySessionId,
  }) = SesoriQuestionReplied;

  @FreezedUnionValue("question.rejected")
  @Implements<SesoriSessionEvent>()
  const factory questionRejected({
    required String requestID,
    required String sessionID,

    /// Root session this request is surfaced under; null ⇒ fall back to
    /// [sessionID].
    required String? displaySessionId,
  }) = SesoriQuestionRejected;

  // ---------------------------------------------------------------------------
  // Todo
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("todo.updated")
  @Implements<SesoriSessionEvent>()
  const factory todoUpdated({
    required String sessionID,
  }) = SesoriTodoUpdated;

  // ---------------------------------------------------------------------------
  // Project & VCS
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("projects.summary")
  const factory projectsSummary({
    required List<ProjectActivitySummary> projects,
  }) = SesoriProjectsSummary;

  @FreezedUnionValue("project.updated")
  const factory projectUpdated({
    // COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges emit no payload. Require both fields and remove fallbacks.
    required String? projectID,
    required int? updatedAt,
  }) = SesoriProjectUpdated;

  @FreezedUnionValue("vcs.branch.updated")
  const factory vcsBranchUpdated() = SesoriVcsBranchUpdated;

  /// Notifies phones that PR data changed for sessions in this project.
  /// Unlike [sessionUpdated] (single session content change), this triggers
  /// a full session list re-fetch to pick up updated PR metadata.
  @FreezedUnionValue("sessions.updated")
  const factory sessionsUpdated({
    required String projectID,
  }) = SesoriSessionsUpdated;

  /// Real-time change to a session's list state. Carries the per-session
  /// [unseen] flag and [lastUserActivityAt] marker plus the recomputed
  /// project-level [projectHasUnseenChanges] aggregate so session and project
  /// lists can both update without a re-fetch. Cross-cutting list event (NOT a
  /// [SesoriSessionEvent]).
  @FreezedUnionValue("session.unseen_changed")
  const factory sessionUnseenChanged({
    required String projectID,
    required String sessionId,
    required bool unseen,
    required bool projectHasUnseenChanges,
    // COMPATIBILITY 2026-08-13 (v1.8.0): Older bridges omit lastUserActivityAt, which means no durable marker is known. Remove this comment after the minimum supported bridge always sends this field.
    required int? lastUserActivityAt,
  }) = SesoriSessionUnseenChanged;

  // ---------------------------------------------------------------------------
  // File
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("file.edited")
  const factory fileEdited({
    String? file,
  }) = SesoriFileEdited;

  @FreezedUnionValue("file.watcher.updated")
  const factory fileWatcherUpdated({
    required String? file,
    required String? event,
  }) = SesoriFileWatcherUpdated;

  // ---------------------------------------------------------------------------
  // LSP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("lsp.updated")
  const factory lspUpdated() = SesoriLspUpdated;

  @FreezedUnionValue("lsp.client.diagnostics")
  const factory lspClientDiagnostics({
    required String? serverID,
    required String? path,
  }) = SesoriLspClientDiagnostics;

  // ---------------------------------------------------------------------------
  // MCP
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("mcp.tools.changed")
  const factory mcpToolsChanged() = SesoriMcpToolsChanged;

  @FreezedUnionValue("mcp.browser.open.failed")
  const factory mcpBrowserOpenFailed() = SesoriMcpBrowserOpenFailed;

  // ---------------------------------------------------------------------------
  // Installation
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("installation.updated")
  const factory installationUpdated({
    String? version,
  }) = SesoriInstallationUpdated;

  @FreezedUnionValue("installation.update-available")
  const factory installationUpdateAvailable({
    String? version,
  }) = SesoriInstallationUpdateAvailable;

  // ---------------------------------------------------------------------------
  // Workspace
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("workspace.ready")
  const factory workspaceReady({
    String? name,
  }) = SesoriWorkspaceReady;

  @FreezedUnionValue("workspace.failed")
  const factory workspaceFailed({
    String? message,
  }) = SesoriWorkspaceFailed;

  // ---------------------------------------------------------------------------
  // TUI
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("tui.toast.show")
  const factory tuiToastShow({
    required String? title,
    required String? message,
    required String? variant,
  }) = SesoriTuiToastShow;

  // ---------------------------------------------------------------------------
  // Worktree
  // ---------------------------------------------------------------------------

  @FreezedUnionValue("worktree.ready")
  const factory worktreeReady() = SesoriWorktreeReady;

  @FreezedUnionValue("worktree.failed")
  const factory worktreeFailed() = SesoriWorktreeFailed;

  factory fromJson(Map<String, dynamic> json) => _$SesoriSseEventFromJson(json);
}
