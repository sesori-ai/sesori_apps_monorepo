// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesori_sse_event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SesoriServerConnected _$SesoriServerConnectedFromJson(Map json) =>
    SesoriServerConnected($type: json['type'] as String?);

Map<String, dynamic> _$SesoriServerConnectedToJson(
  SesoriServerConnected instance,
) => <String, dynamic>{'type': instance.$type};

SesoriServerHeartbeat _$SesoriServerHeartbeatFromJson(Map json) =>
    SesoriServerHeartbeat($type: json['type'] as String?);

Map<String, dynamic> _$SesoriServerHeartbeatToJson(
  SesoriServerHeartbeat instance,
) => <String, dynamic>{'type': instance.$type};

SesoriServerInstanceDisposed _$SesoriServerInstanceDisposedFromJson(Map json) =>
    SesoriServerInstanceDisposed(
      directory: json['directory'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriServerInstanceDisposedToJson(
  SesoriServerInstanceDisposed instance,
) => <String, dynamic>{'directory': instance.directory, 'type': instance.$type};

SesoriGlobalDisposed _$SesoriGlobalDisposedFromJson(Map json) =>
    SesoriGlobalDisposed($type: json['type'] as String?);

Map<String, dynamic> _$SesoriGlobalDisposedToJson(
  SesoriGlobalDisposed instance,
) => <String, dynamic>{'type': instance.$type};

SesoriSessionCreated _$SesoriSessionCreatedFromJson(Map json) =>
    SesoriSessionCreated(
      info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionCreatedToJson(
  SesoriSessionCreated instance,
) => <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SesoriSessionUpdated _$SesoriSessionUpdatedFromJson(Map json) =>
    SesoriSessionUpdated(
      info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionUpdatedToJson(
  SesoriSessionUpdated instance,
) => <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SesoriSessionDeleted _$SesoriSessionDeletedFromJson(Map json) =>
    SesoriSessionDeleted(
      info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionDeletedToJson(
  SesoriSessionDeleted instance,
) => <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SesoriSessionDiff _$SesoriSessionDiffFromJson(Map json) => SesoriSessionDiff(
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriSessionDiffToJson(SesoriSessionDiff instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SesoriSessionError _$SesoriSessionErrorFromJson(Map json) => SesoriSessionError(
  sessionID: json['sessionID'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriSessionErrorToJson(SesoriSessionError instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SesoriSessionCompacted _$SesoriSessionCompactedFromJson(Map json) =>
    SesoriSessionCompacted(
      sessionID: json['sessionID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionCompactedToJson(
  SesoriSessionCompacted instance,
) => <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SesoriSessionStatus _$SesoriSessionStatusFromJson(Map json) =>
    SesoriSessionStatus(
      sessionID: json['sessionID'] as String,
      status: SessionStatus.fromJson(
        Map<String, dynamic>.from(json['status'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionStatusToJson(
  SesoriSessionStatus instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'status': instance.status.toJson(),
  'type': instance.$type,
};

SesoriSessionIdle _$SesoriSessionIdleFromJson(Map json) => SesoriSessionIdle(
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriSessionIdleToJson(SesoriSessionIdle instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SesoriCommandExecuted _$SesoriCommandExecutedFromJson(Map json) =>
    SesoriCommandExecuted(
      name: json['name'] as String,
      sessionID: json['sessionID'] as String,
      arguments: json['arguments'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriCommandExecutedToJson(
  SesoriCommandExecuted instance,
) => <String, dynamic>{
  'name': instance.name,
  'sessionID': instance.sessionID,
  'arguments': instance.arguments,
  'messageID': instance.messageID,
  'type': instance.$type,
};

SesoriMessageUpdated _$SesoriMessageUpdatedFromJson(Map json) =>
    SesoriMessageUpdated(
      info: Message.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriMessageUpdatedToJson(
  SesoriMessageUpdated instance,
) => <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SesoriMessageRemoved _$SesoriMessageRemovedFromJson(Map json) =>
    SesoriMessageRemoved(
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriMessageRemovedToJson(
  SesoriMessageRemoved instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'type': instance.$type,
};

SesoriMessagePartUpdated _$SesoriMessagePartUpdatedFromJson(Map json) =>
    SesoriMessagePartUpdated(
      part: MessagePart.fromJson(
        Map<String, dynamic>.from(json['part'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriMessagePartUpdatedToJson(
  SesoriMessagePartUpdated instance,
) => <String, dynamic>{'part': instance.part.toJson(), 'type': instance.$type};

SesoriMessagePartDelta _$SesoriMessagePartDeltaFromJson(Map json) =>
    SesoriMessagePartDelta(
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      partID: json['partID'] as String,
      field: json['field'] as String,
      delta: json['delta'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriMessagePartDeltaToJson(
  SesoriMessagePartDelta instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'partID': instance.partID,
  'field': instance.field,
  'delta': instance.delta,
  'type': instance.$type,
};

SesoriMessagePartRemoved _$SesoriMessagePartRemovedFromJson(Map json) =>
    SesoriMessagePartRemoved(
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      partID: json['partID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriMessagePartRemovedToJson(
  SesoriMessagePartRemoved instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'partID': instance.partID,
  'type': instance.$type,
};

SesoriPtyCreated _$SesoriPtyCreatedFromJson(Map json) =>
    SesoriPtyCreated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriPtyCreatedToJson(SesoriPtyCreated instance) =>
    <String, dynamic>{'type': instance.$type};

SesoriPtyUpdated _$SesoriPtyUpdatedFromJson(Map json) =>
    SesoriPtyUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriPtyUpdatedToJson(SesoriPtyUpdated instance) =>
    <String, dynamic>{'type': instance.$type};

SesoriPtyExited _$SesoriPtyExitedFromJson(Map json) => SesoriPtyExited(
  id: json['id'] as String?,
  exitCode: (json['exitCode'] as num?)?.toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriPtyExitedToJson(SesoriPtyExited instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exitCode': instance.exitCode,
      'type': instance.$type,
    };

SesoriPtyDeleted _$SesoriPtyDeletedFromJson(Map json) =>
    SesoriPtyDeleted(id: json['id'] as String?, $type: json['type'] as String?);

Map<String, dynamic> _$SesoriPtyDeletedToJson(SesoriPtyDeleted instance) =>
    <String, dynamic>{'id': instance.id, 'type': instance.$type};

SesoriPermissionAsked _$SesoriPermissionAskedFromJson(Map json) =>
    SesoriPermissionAsked(
      requestID: json['requestID'] as String,
      sessionID: json['sessionID'] as String,
      tool: json['tool'] as String,
      description: json['description'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriPermissionAskedToJson(
  SesoriPermissionAsked instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'sessionID': instance.sessionID,
  'tool': instance.tool,
  'description': instance.description,
  'type': instance.$type,
};

SesoriPermissionReplied _$SesoriPermissionRepliedFromJson(Map json) =>
    SesoriPermissionReplied(
      requestID: json['requestID'] as String,
      sessionID: json['sessionID'] as String,
      reply: json['reply'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriPermissionRepliedToJson(
  SesoriPermissionReplied instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'sessionID': instance.sessionID,
  'reply': instance.reply,
  'type': instance.$type,
};

SesoriPermissionUpdated _$SesoriPermissionUpdatedFromJson(Map json) =>
    SesoriPermissionUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriPermissionUpdatedToJson(
  SesoriPermissionUpdated instance,
) => <String, dynamic>{'type': instance.$type};

SesoriQuestionAsked _$SesoriQuestionAskedFromJson(Map json) =>
    SesoriQuestionAsked(
      id: json['id'] as String,
      sessionID: json['sessionID'] as String,
      questions: (json['questions'] as List<dynamic>)
          .map(
            (e) => QuestionInfo.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriQuestionAskedToJson(
  SesoriQuestionAsked instance,
) => <String, dynamic>{
  'id': instance.id,
  'sessionID': instance.sessionID,
  'questions': instance.questions.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

SesoriQuestionReplied _$SesoriQuestionRepliedFromJson(Map json) =>
    SesoriQuestionReplied(
      requestID: json['requestID'] as String,
      sessionID: json['sessionID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriQuestionRepliedToJson(
  SesoriQuestionReplied instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'sessionID': instance.sessionID,
  'type': instance.$type,
};

SesoriQuestionRejected _$SesoriQuestionRejectedFromJson(Map json) =>
    SesoriQuestionRejected(
      requestID: json['requestID'] as String,
      sessionID: json['sessionID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriQuestionRejectedToJson(
  SesoriQuestionRejected instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'sessionID': instance.sessionID,
  'type': instance.$type,
};

SesoriTodoUpdated _$SesoriTodoUpdatedFromJson(Map json) => SesoriTodoUpdated(
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriTodoUpdatedToJson(SesoriTodoUpdated instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SesoriProjectsSummary _$SesoriProjectsSummaryFromJson(Map json) =>
    SesoriProjectsSummary(
      projects: (json['projects'] as List<dynamic>)
          .map(
            (e) => ProjectActivitySummary.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriProjectsSummaryToJson(
  SesoriProjectsSummary instance,
) => <String, dynamic>{
  'projects': instance.projects.map((e) => e.toJson()).toList(),
  'type': instance.$type,
};

SesoriProjectUpdated _$SesoriProjectUpdatedFromJson(Map json) =>
    SesoriProjectUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriProjectUpdatedToJson(
  SesoriProjectUpdated instance,
) => <String, dynamic>{'type': instance.$type};

SesoriVcsBranchUpdated _$SesoriVcsBranchUpdatedFromJson(Map json) =>
    SesoriVcsBranchUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriVcsBranchUpdatedToJson(
  SesoriVcsBranchUpdated instance,
) => <String, dynamic>{'type': instance.$type};

SesoriSessionsUpdated _$SesoriSessionsUpdatedFromJson(Map json) =>
    SesoriSessionsUpdated(
      projectID: json['projectID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriSessionsUpdatedToJson(
  SesoriSessionsUpdated instance,
) => <String, dynamic>{'projectID': instance.projectID, 'type': instance.$type};

SesoriFileEdited _$SesoriFileEditedFromJson(Map json) => SesoriFileEdited(
  file: json['file'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriFileEditedToJson(SesoriFileEdited instance) =>
    <String, dynamic>{'file': instance.file, 'type': instance.$type};

SesoriFileWatcherUpdated _$SesoriFileWatcherUpdatedFromJson(Map json) =>
    SesoriFileWatcherUpdated(
      file: json['file'] as String?,
      event: json['event'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriFileWatcherUpdatedToJson(
  SesoriFileWatcherUpdated instance,
) => <String, dynamic>{
  'file': instance.file,
  'event': instance.event,
  'type': instance.$type,
};

SesoriLspUpdated _$SesoriLspUpdatedFromJson(Map json) =>
    SesoriLspUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SesoriLspUpdatedToJson(SesoriLspUpdated instance) =>
    <String, dynamic>{'type': instance.$type};

SesoriLspClientDiagnostics _$SesoriLspClientDiagnosticsFromJson(Map json) =>
    SesoriLspClientDiagnostics(
      serverID: json['serverID'] as String?,
      path: json['path'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriLspClientDiagnosticsToJson(
  SesoriLspClientDiagnostics instance,
) => <String, dynamic>{
  'serverID': instance.serverID,
  'path': instance.path,
  'type': instance.$type,
};

SesoriMcpToolsChanged _$SesoriMcpToolsChangedFromJson(Map json) =>
    SesoriMcpToolsChanged($type: json['type'] as String?);

Map<String, dynamic> _$SesoriMcpToolsChangedToJson(
  SesoriMcpToolsChanged instance,
) => <String, dynamic>{'type': instance.$type};

SesoriMcpBrowserOpenFailed _$SesoriMcpBrowserOpenFailedFromJson(Map json) =>
    SesoriMcpBrowserOpenFailed($type: json['type'] as String?);

Map<String, dynamic> _$SesoriMcpBrowserOpenFailedToJson(
  SesoriMcpBrowserOpenFailed instance,
) => <String, dynamic>{'type': instance.$type};

SesoriInstallationUpdated _$SesoriInstallationUpdatedFromJson(Map json) =>
    SesoriInstallationUpdated(
      version: json['version'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriInstallationUpdatedToJson(
  SesoriInstallationUpdated instance,
) => <String, dynamic>{'version': instance.version, 'type': instance.$type};

SesoriInstallationUpdateAvailable _$SesoriInstallationUpdateAvailableFromJson(
  Map json,
) => SesoriInstallationUpdateAvailable(
  version: json['version'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriInstallationUpdateAvailableToJson(
  SesoriInstallationUpdateAvailable instance,
) => <String, dynamic>{'version': instance.version, 'type': instance.$type};

SesoriWorkspaceReady _$SesoriWorkspaceReadyFromJson(Map json) =>
    SesoriWorkspaceReady(
      name: json['name'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriWorkspaceReadyToJson(
  SesoriWorkspaceReady instance,
) => <String, dynamic>{'name': instance.name, 'type': instance.$type};

SesoriWorkspaceFailed _$SesoriWorkspaceFailedFromJson(Map json) =>
    SesoriWorkspaceFailed(
      message: json['message'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SesoriWorkspaceFailedToJson(
  SesoriWorkspaceFailed instance,
) => <String, dynamic>{'message': instance.message, 'type': instance.$type};

SesoriTuiToastShow _$SesoriTuiToastShowFromJson(Map json) => SesoriTuiToastShow(
  title: json['title'] as String?,
  message: json['message'] as String?,
  variant: json['variant'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriTuiToastShowToJson(SesoriTuiToastShow instance) =>
    <String, dynamic>{
      'title': instance.title,
      'message': instance.message,
      'variant': instance.variant,
      'type': instance.$type,
    };

SesoriWorktreeReady _$SesoriWorktreeReadyFromJson(Map json) =>
    SesoriWorktreeReady($type: json['type'] as String?);

Map<String, dynamic> _$SesoriWorktreeReadyToJson(
  SesoriWorktreeReady instance,
) => <String, dynamic>{'type': instance.$type};

SesoriWorktreeFailed _$SesoriWorktreeFailedFromJson(Map json) =>
    SesoriWorktreeFailed($type: json['type'] as String?);

Map<String, dynamic> _$SesoriWorktreeFailedToJson(
  SesoriWorktreeFailed instance,
) => <String, dynamic>{'type': instance.$type};

SesoriServerStatus _$SesoriServerStatusFromJson(Map json) => SesoriServerStatus(
  status: $enumDecode(_$ServerStatusKindEnumMap, json['status']),
  message: json['message'] as String?,
  reason: json['reason'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SesoriServerStatusToJson(SesoriServerStatus instance) =>
    <String, dynamic>{
      'status': _$ServerStatusKindEnumMap[instance.status]!,
      'message': instance.message,
      'reason': instance.reason,
      'type': instance.$type,
    };

const _$ServerStatusKindEnumMap = {
  ServerStatusKind.unavailable: 'unavailable',
  ServerStatusKind.restored: 'restored',
  ServerStatusKind.fatal: 'fatal',
};
