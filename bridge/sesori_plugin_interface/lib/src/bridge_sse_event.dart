import "models/plugin_message.dart";

sealed class BridgeSseEvent {
  const BridgeSseEvent();
}

class BridgeSseServerConnected extends BridgeSseEvent {
  const BridgeSseServerConnected();
}

class BridgeSseServerHeartbeat extends BridgeSseEvent {
  const BridgeSseServerHeartbeat();
}

class BridgeSseServerInstanceDisposed extends BridgeSseEvent {
  final String? directory;
  const BridgeSseServerInstanceDisposed({this.directory});
}

class BridgeSseGlobalDisposed extends BridgeSseEvent {
  const BridgeSseGlobalDisposed();
}

class BridgeSseSessionCreated extends BridgeSseEvent {
  final Map<String, dynamic> info;
  const BridgeSseSessionCreated({required this.info});
}

class BridgeSseSessionUpdated extends BridgeSseEvent {
  final Map<String, dynamic> info;
  const BridgeSseSessionUpdated({required this.info});
}

class BridgeSseSessionDeleted extends BridgeSseEvent {
  final Map<String, dynamic> info;
  const BridgeSseSessionDeleted({required this.info});
}

class BridgeSseSessionDiff extends BridgeSseEvent {
  final String sessionID;
  const BridgeSseSessionDiff({required this.sessionID});
}

class BridgeSseSessionError extends BridgeSseEvent {
  final String sessionID;
  const BridgeSseSessionError({required this.sessionID});
}

class BridgeSseSessionCompacted extends BridgeSseEvent {
  final String sessionID;
  const BridgeSseSessionCompacted({required this.sessionID});
}

class BridgeSseSessionStatus extends BridgeSseEvent {
  final String sessionID;
  final Map<String, dynamic> status;
  const BridgeSseSessionStatus({required this.sessionID, required this.status});
}

class BridgeSseSessionIdle extends BridgeSseEvent {
  final String sessionID;
  const BridgeSseSessionIdle({required this.sessionID});
}

class BridgeSseMessageUpdated extends BridgeSseEvent {
  final Map<String, dynamic> info;
  const BridgeSseMessageUpdated({required this.info});
}

class BridgeSseMessageRemoved extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
  const BridgeSseMessageRemoved({required this.sessionID, required this.messageID});
}

class BridgeSseMessagePartUpdated extends BridgeSseEvent {
  final PluginMessagePart part;
  const BridgeSseMessagePartUpdated({required this.part});
}

class BridgeSseMessagePartDelta extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
  final String partID;
  final String field;
  final String delta;
  const BridgeSseMessagePartDelta({
    required this.sessionID,
    required this.messageID,
    required this.partID,
    required this.field,
    required this.delta,
  });
}

class BridgeSseMessagePartRemoved extends BridgeSseEvent {
  final String sessionID;
  final String messageID;
  final String partID;
  const BridgeSseMessagePartRemoved({
    required this.sessionID,
    required this.messageID,
    required this.partID,
  });
}

class BridgeSsePtyCreated extends BridgeSseEvent {
  const BridgeSsePtyCreated();
}

class BridgeSsePtyUpdated extends BridgeSseEvent {
  const BridgeSsePtyUpdated();
}

class BridgeSsePtyExited extends BridgeSseEvent {
  final String? id;
  final int? exitCode;
  const BridgeSsePtyExited({this.id, this.exitCode});
}

class BridgeSsePtyDeleted extends BridgeSseEvent {
  final String? id;
  const BridgeSsePtyDeleted({this.id});
}

class BridgeSsePermissionAsked extends BridgeSseEvent {
  final String requestID;
  final String sessionID;
  final String tool;
  final String description;
  const BridgeSsePermissionAsked({
    required this.requestID,
    required this.sessionID,
    required this.tool,
    required this.description,
  });
}

class BridgeSsePermissionReplied extends BridgeSseEvent {
  final String requestID;
  final String reply;
  const BridgeSsePermissionReplied({required this.requestID, required this.reply});
}

class BridgeSsePermissionUpdated extends BridgeSseEvent {
  const BridgeSsePermissionUpdated();
}

class BridgeSseQuestionAsked extends BridgeSseEvent {
  final String id;
  final String sessionID;
  final List<Map<String, dynamic>> questions;
  const BridgeSseQuestionAsked({required this.id, required this.sessionID, required this.questions});
}

class BridgeSseQuestionReplied extends BridgeSseEvent {
  final String requestID;
  final String sessionID;
  const BridgeSseQuestionReplied({required this.requestID, required this.sessionID});
}

class BridgeSseQuestionRejected extends BridgeSseEvent {
  final String requestID;
  final String sessionID;
  const BridgeSseQuestionRejected({required this.requestID, required this.sessionID});
}

class BridgeSseTodoUpdated extends BridgeSseEvent {
  final String sessionID;
  const BridgeSseTodoUpdated({required this.sessionID});
}

class BridgeSseProjectUpdated extends BridgeSseEvent {
  const BridgeSseProjectUpdated();
}

class BridgeSseVcsBranchUpdated extends BridgeSseEvent {
  const BridgeSseVcsBranchUpdated();
}

class BridgeSseFileEdited extends BridgeSseEvent {
  final String? file;
  const BridgeSseFileEdited({this.file});
}

class BridgeSseFileWatcherUpdated extends BridgeSseEvent {
  final String? file;
  final String? event;
  const BridgeSseFileWatcherUpdated({this.file, this.event});
}

class BridgeSseLspUpdated extends BridgeSseEvent {
  const BridgeSseLspUpdated();
}

class BridgeSseLspClientDiagnostics extends BridgeSseEvent {
  final String? serverID;
  final String? path;
  const BridgeSseLspClientDiagnostics({this.serverID, this.path});
}

class BridgeSseMcpToolsChanged extends BridgeSseEvent {
  const BridgeSseMcpToolsChanged();
}

class BridgeSseMcpBrowserOpenFailed extends BridgeSseEvent {
  const BridgeSseMcpBrowserOpenFailed();
}

class BridgeSseInstallationUpdated extends BridgeSseEvent {
  final String? version;
  const BridgeSseInstallationUpdated({this.version});
}

class BridgeSseInstallationUpdateAvailable extends BridgeSseEvent {
  final String? version;
  const BridgeSseInstallationUpdateAvailable({this.version});
}

class BridgeSseWorkspaceReady extends BridgeSseEvent {
  final String? name;
  const BridgeSseWorkspaceReady({this.name});
}

class BridgeSseWorkspaceFailed extends BridgeSseEvent {
  final String? message;
  const BridgeSseWorkspaceFailed({this.message});
}

class BridgeSseTuiToastShow extends BridgeSseEvent {
  final String? title;
  final String? message;
  final String? variant;
  const BridgeSseTuiToastShow({this.title, this.message, this.variant});
}

class BridgeSseWorktreeReady extends BridgeSseEvent {
  const BridgeSseWorktreeReady();
}

class BridgeSseWorktreeFailed extends BridgeSseEvent {
  const BridgeSseWorktreeFailed();
}
