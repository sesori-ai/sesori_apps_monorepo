import "models/plugin_agent.dart";
import "models/plugin_message.dart";
import "models/plugin_pending_question.dart";

sealed class const BridgeSseEvent();

/// Mapping provenance for reconciliation synthesized during a forced stop.
///
/// This wrapper carries no stop-fence authority. The generation runtime owns
/// that authorization separately, so a plugin-emitted wrapper remains an
/// ordinary fenced event.
class const BridgeSseTerminalHandoff({required this.event}) extends BridgeSseEvent {
  final BridgeSseEvent event;
}

class const BridgeSseServerConnected() extends BridgeSseEvent;

class const BridgeSseServerHeartbeat() extends BridgeSseEvent;

class const BridgeSseServerInstanceDisposed({this.directory}) extends BridgeSseEvent {
  final String? directory;
}

class const BridgeSseGlobalDisposed() extends BridgeSseEvent;

/// Signals that the emitting plugin's process-wide command catalog changed.
class const BridgeSseCommandCatalogUpdated() extends BridgeSseEvent;

class const BridgeSseSessionCreated({required this.info}) extends BridgeSseEvent {
  final Map<String, dynamic> info;
}

class const BridgeSseSessionUpdated({required this.info, required this.titleChanged}) extends BridgeSseEvent {
  final Map<String, dynamic> info;
  final bool titleChanged;
}

/// Signals that every session under [projectID] should be re-fetched.
class const BridgeSseSessionsUpdated({
    required this.sessionID,
    required this.projectID,
  }) extends BridgeSseEvent {
  final String sessionID;
  final String projectID;
}

/// Signals that session-creation options changed for a backend session.
///
/// This is an internal plugin event. [sessionID] is the backend's session
/// identity so bridge core can resolve its stable persisted binding.
class const BridgeSseSessionOptionsChanged({required this.sessionID}) extends BridgeSseEvent {
  final String sessionID;
}

/// Signals that a backend changed the effective defaults for future turns.
class const BridgeSseSessionPromptDefaultsChanged({
    required this.sessionID,
    required this.agent,
    required this.model,
  }) extends BridgeSseEvent {
  final String sessionID;
  final String? agent;
  final PluginAgentModel? model;
}

class const BridgeSseSessionDeleted({required this.info}) extends BridgeSseEvent {
  final Map<String, dynamic> info;
}

class const BridgeSseSessionDiff({required this.sessionID}) extends BridgeSseEvent {
  final String sessionID;
}

class const BridgeSseSessionError({required this.sessionID}) extends BridgeSseEvent {
  final String? sessionID;
}

class const BridgeSseSessionCompacted({required this.sessionID}) extends BridgeSseEvent {
  final String sessionID;
}

class const BridgeSseSessionStatus({required this.sessionID, required this.status}) extends BridgeSseEvent {
  final String sessionID;
  final Map<String, dynamic> status;
}

class const BridgeSseSessionIdle({required this.sessionID}) extends BridgeSseEvent {
  final String sessionID;
}

class const BridgeSseCommandExecuted({
    required this.name,
    required this.sessionID,
    required this.arguments,
    required this.messageID,
  }) extends BridgeSseEvent {
  final String name;
  final String sessionID;
  final String arguments;
  final String messageID;
}

class const BridgeSseMessageUpdated({required this.info}) extends BridgeSseEvent {
  final Map<String, dynamic> info;
}

class const BridgeSseMessageRemoved({required this.sessionID, required this.messageID}) extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
}

class const BridgeSseMessagePartUpdated({required this.part}) extends BridgeSseEvent {
  final PluginMessagePart part;
}

class const BridgeSseMessagePartDelta({
    required this.sessionID,
    required this.messageID,
    required this.partID,
    required this.field,
    required this.delta,
  }) extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
  final String partID;
  final String field;
  final String delta;
}

class const BridgeSseMessagePartRemoved({
    required this.sessionID,
    required this.messageID,
    required this.partID,
  }) extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
  final String partID;
}

class const BridgeSsePtyCreated() extends BridgeSseEvent;

class const BridgeSsePtyUpdated() extends BridgeSseEvent;

class const BridgeSsePtyExited({this.id, this.exitCode}) extends BridgeSseEvent {
  final String? id;
  final int? exitCode;
}

class const BridgeSsePtyDeleted({this.id}) extends BridgeSseEvent {
  final String? id;
}

class const BridgeSsePermissionAsked({
    required this.requestID,
    required this.sessionID,
    required this.displaySessionId,
    required this.tool,
    required this.description,
    required this.allowAlways,
  }) extends BridgeSseEvent {
  final String requestID;
  final String sessionID;

  /// Top-most root session this request should be surfaced under (for a
  /// child/sub-agent session's request). Null when unknown.
  final String? displaySessionId;
  final String tool;
  final String description;
  final bool allowAlways;
}

class const BridgeSsePermissionReplied({
    required this.requestID,
    required this.sessionID,
    required this.displaySessionId,
    required this.reply,
  }) extends BridgeSseEvent {
  final String requestID;
  final String sessionID;

  /// Root session this request is surfaced under. Null when unknown.
  final String? displaySessionId;
  final String reply;
}

class const BridgeSsePermissionUpdated() extends BridgeSseEvent;

class const BridgeSseQuestionAsked({
    required this.id,
    required this.sessionID,
    required this.displaySessionId,
    required this.questions,
  }) extends BridgeSseEvent {
  final String id;
  final String sessionID;

  /// Top-most root session this request should be surfaced under (for a
  /// child/sub-agent session's request). Null when unknown.
  final String? displaySessionId;
  final List<PluginQuestionInfo> questions;
}

class const BridgeSseQuestionReplied({
    required this.requestID,
    required this.sessionID,
    required this.displaySessionId,
  }) extends BridgeSseEvent {
  final String requestID;
  final String sessionID;

  /// Root session this request is surfaced under. Null when unknown.
  final String? displaySessionId;
}

class const BridgeSseQuestionRejected({
    required this.requestID,
    required this.sessionID,
    required this.displaySessionId,
  }) extends BridgeSseEvent {
  final String requestID;
  final String sessionID;

  /// Root session this request is surfaced under. Null when unknown.
  final String? displaySessionId;
}

class const BridgeSseTodoUpdated({required this.sessionID}) extends BridgeSseEvent {
  final String sessionID;
}

class const BridgeSseProjectUpdated() extends BridgeSseEvent;

class const BridgeSseVcsBranchUpdated() extends BridgeSseEvent;

class const BridgeSseFileEdited({this.file}) extends BridgeSseEvent {
  final String? file;
}

class const BridgeSseFileWatcherUpdated({this.file, this.event}) extends BridgeSseEvent {
  final String? file;
  final String? event;
}

class const BridgeSseLspUpdated() extends BridgeSseEvent;

class const BridgeSseLspClientDiagnostics({this.serverID, this.path}) extends BridgeSseEvent {
  final String? serverID;
  final String? path;
}

class const BridgeSseMcpToolsChanged() extends BridgeSseEvent;

class const BridgeSseMcpBrowserOpenFailed() extends BridgeSseEvent;

class const BridgeSseInstallationUpdated({this.version}) extends BridgeSseEvent {
  final String? version;
}

class const BridgeSseInstallationUpdateAvailable({this.version}) extends BridgeSseEvent {
  final String? version;
}

class const BridgeSseWorkspaceReady({this.name}) extends BridgeSseEvent {
  final String? name;
}

class const BridgeSseWorkspaceFailed({this.message}) extends BridgeSseEvent {
  final String? message;
}

class const BridgeSseTuiToastShow({this.title, this.message, this.variant}) extends BridgeSseEvent {
  final String? title;
  final String? message;
  final String? variant;
}

class const BridgeSseWorktreeReady() extends BridgeSseEvent;

class const BridgeSseWorktreeFailed() extends BridgeSseEvent;
