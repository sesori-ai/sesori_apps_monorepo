// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sse_event_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SseServerConnected _$SseServerConnectedFromJson(Map json) =>
    SseServerConnected($type: json['type'] as String?);

Map<String, dynamic> _$SseServerConnectedToJson(SseServerConnected instance) =>
    <String, dynamic>{'type': instance.$type};

SseServerHeartbeat _$SseServerHeartbeatFromJson(Map json) =>
    SseServerHeartbeat($type: json['type'] as String?);

Map<String, dynamic> _$SseServerHeartbeatToJson(SseServerHeartbeat instance) =>
    <String, dynamic>{'type': instance.$type};

SseServerInstanceDisposed _$SseServerInstanceDisposedFromJson(Map json) =>
    SseServerInstanceDisposed(
      directory: json['directory'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseServerInstanceDisposedToJson(
  SseServerInstanceDisposed instance,
) => <String, dynamic>{'directory': instance.directory, 'type': instance.$type};

SseGlobalDisposed _$SseGlobalDisposedFromJson(Map json) =>
    SseGlobalDisposed($type: json['type'] as String?);

Map<String, dynamic> _$SseGlobalDisposedToJson(SseGlobalDisposed instance) =>
    <String, dynamic>{'type': instance.$type};

SseSessionCreated _$SseSessionCreatedFromJson(Map json) => SseSessionCreated(
  info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionCreatedToJson(SseSessionCreated instance) =>
    <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SseSessionUpdated _$SseSessionUpdatedFromJson(Map json) => SseSessionUpdated(
  info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionUpdatedToJson(SseSessionUpdated instance) =>
    <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SseSessionDeleted _$SseSessionDeletedFromJson(Map json) => SseSessionDeleted(
  info: Session.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionDeletedToJson(SseSessionDeleted instance) =>
    <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SseSessionDiff _$SseSessionDiffFromJson(Map json) => SseSessionDiff(
  sessionID: json['sessionID'] as String,
  diff: (json['diff'] as List<dynamic>)
      .map((e) => FileDiff.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionDiffToJson(SseSessionDiff instance) =>
    <String, dynamic>{
      'sessionID': instance.sessionID,
      'diff': instance.diff.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

SseSessionError _$SseSessionErrorFromJson(Map json) => SseSessionError(
  sessionID: json['sessionID'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionErrorToJson(SseSessionError instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SseSessionCompacted _$SseSessionCompactedFromJson(Map json) =>
    SseSessionCompacted(
      sessionID: json['sessionID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseSessionCompactedToJson(
  SseSessionCompacted instance,
) => <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SseSessionStatus _$SseSessionStatusFromJson(Map json) => SseSessionStatus(
  sessionID: json['sessionID'] as String,
  status: SessionStatus.fromJson(
    Map<String, dynamic>.from(json['status'] as Map),
  ),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionStatusToJson(SseSessionStatus instance) =>
    <String, dynamic>{
      'sessionID': instance.sessionID,
      'status': instance.status.toJson(),
      'type': instance.$type,
    };

SseSessionIdle _$SseSessionIdleFromJson(Map json) => SseSessionIdle(
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseSessionIdleToJson(SseSessionIdle instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SseMessageUpdated _$SseMessageUpdatedFromJson(Map json) => SseMessageUpdated(
  info: Message.fromJson(Map<String, dynamic>.from(json['info'] as Map)),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseMessageUpdatedToJson(SseMessageUpdated instance) =>
    <String, dynamic>{'info': instance.info.toJson(), 'type': instance.$type};

SseMessageRemoved _$SseMessageRemovedFromJson(Map json) => SseMessageRemoved(
  sessionID: json['sessionID'] as String,
  messageID: json['messageID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseMessageRemovedToJson(SseMessageRemoved instance) =>
    <String, dynamic>{
      'sessionID': instance.sessionID,
      'messageID': instance.messageID,
      'type': instance.$type,
    };

SseMessagePartUpdated _$SseMessagePartUpdatedFromJson(Map json) =>
    SseMessagePartUpdated(
      part: MessagePart.fromJson(
        Map<String, dynamic>.from(json['part'] as Map),
      ),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseMessagePartUpdatedToJson(
  SseMessagePartUpdated instance,
) => <String, dynamic>{'part': instance.part.toJson(), 'type': instance.$type};

SseMessagePartDelta _$SseMessagePartDeltaFromJson(Map json) =>
    SseMessagePartDelta(
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      partID: json['partID'] as String,
      field: json['field'] as String,
      delta: json['delta'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseMessagePartDeltaToJson(
  SseMessagePartDelta instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'partID': instance.partID,
  'field': instance.field,
  'delta': instance.delta,
  'type': instance.$type,
};

SseMessagePartRemoved _$SseMessagePartRemovedFromJson(Map json) =>
    SseMessagePartRemoved(
      sessionID: json['sessionID'] as String,
      messageID: json['messageID'] as String,
      partID: json['partID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseMessagePartRemovedToJson(
  SseMessagePartRemoved instance,
) => <String, dynamic>{
  'sessionID': instance.sessionID,
  'messageID': instance.messageID,
  'partID': instance.partID,
  'type': instance.$type,
};

SsePtyCreated _$SsePtyCreatedFromJson(Map json) =>
    SsePtyCreated($type: json['type'] as String?);

Map<String, dynamic> _$SsePtyCreatedToJson(SsePtyCreated instance) =>
    <String, dynamic>{'type': instance.$type};

SsePtyUpdated _$SsePtyUpdatedFromJson(Map json) =>
    SsePtyUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SsePtyUpdatedToJson(SsePtyUpdated instance) =>
    <String, dynamic>{'type': instance.$type};

SsePtyExited _$SsePtyExitedFromJson(Map json) => SsePtyExited(
  id: json['id'] as String?,
  exitCode: (json['exitCode'] as num?)?.toInt(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SsePtyExitedToJson(SsePtyExited instance) =>
    <String, dynamic>{
      'id': instance.id,
      'exitCode': instance.exitCode,
      'type': instance.$type,
    };

SsePtyDeleted _$SsePtyDeletedFromJson(Map json) =>
    SsePtyDeleted(id: json['id'] as String?, $type: json['type'] as String?);

Map<String, dynamic> _$SsePtyDeletedToJson(SsePtyDeleted instance) =>
    <String, dynamic>{'id': instance.id, 'type': instance.$type};

SsePermissionAsked _$SsePermissionAskedFromJson(Map json) => SsePermissionAsked(
  requestID: json['requestID'] as String,
  sessionID: json['sessionID'] as String,
  tool: json['tool'] as String,
  description: json['description'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SsePermissionAskedToJson(SsePermissionAsked instance) =>
    <String, dynamic>{
      'requestID': instance.requestID,
      'sessionID': instance.sessionID,
      'tool': instance.tool,
      'description': instance.description,
      'type': instance.$type,
    };

SsePermissionReplied _$SsePermissionRepliedFromJson(Map json) =>
    SsePermissionReplied(
      requestID: json['requestID'] as String,
      reply: json['reply'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SsePermissionRepliedToJson(
  SsePermissionReplied instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'reply': instance.reply,
  'type': instance.$type,
};

SsePermissionUpdated _$SsePermissionUpdatedFromJson(Map json) =>
    SsePermissionUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SsePermissionUpdatedToJson(
  SsePermissionUpdated instance,
) => <String, dynamic>{'type': instance.$type};

SseQuestionAsked _$SseQuestionAskedFromJson(Map json) => SseQuestionAsked(
  id: json['id'] as String,
  sessionID: json['sessionID'] as String,
  questions: (json['questions'] as List<dynamic>)
      .map((e) => QuestionInfo.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList(),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseQuestionAskedToJson(SseQuestionAsked instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionID': instance.sessionID,
      'questions': instance.questions.map((e) => e.toJson()).toList(),
      'type': instance.$type,
    };

SseQuestionReplied _$SseQuestionRepliedFromJson(Map json) => SseQuestionReplied(
  requestID: json['requestID'] as String,
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseQuestionRepliedToJson(SseQuestionReplied instance) =>
    <String, dynamic>{
      'requestID': instance.requestID,
      'sessionID': instance.sessionID,
      'type': instance.$type,
    };

SseQuestionRejected _$SseQuestionRejectedFromJson(Map json) =>
    SseQuestionRejected(
      requestID: json['requestID'] as String,
      sessionID: json['sessionID'] as String,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseQuestionRejectedToJson(
  SseQuestionRejected instance,
) => <String, dynamic>{
  'requestID': instance.requestID,
  'sessionID': instance.sessionID,
  'type': instance.$type,
};

SseTodoUpdated _$SseTodoUpdatedFromJson(Map json) => SseTodoUpdated(
  sessionID: json['sessionID'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseTodoUpdatedToJson(SseTodoUpdated instance) =>
    <String, dynamic>{'sessionID': instance.sessionID, 'type': instance.$type};

SseProjectUpdated _$SseProjectUpdatedFromJson(Map json) =>
    SseProjectUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SseProjectUpdatedToJson(SseProjectUpdated instance) =>
    <String, dynamic>{'type': instance.$type};

SseVcsBranchUpdated _$SseVcsBranchUpdatedFromJson(Map json) =>
    SseVcsBranchUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SseVcsBranchUpdatedToJson(
  SseVcsBranchUpdated instance,
) => <String, dynamic>{'type': instance.$type};

SseFileEdited _$SseFileEditedFromJson(Map json) => SseFileEdited(
  file: json['file'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseFileEditedToJson(SseFileEdited instance) =>
    <String, dynamic>{'file': instance.file, 'type': instance.$type};

SseFileWatcherUpdated _$SseFileWatcherUpdatedFromJson(Map json) =>
    SseFileWatcherUpdated(
      file: json['file'] as String?,
      event: json['event'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseFileWatcherUpdatedToJson(
  SseFileWatcherUpdated instance,
) => <String, dynamic>{
  'file': instance.file,
  'event': instance.event,
  'type': instance.$type,
};

SseLspUpdated _$SseLspUpdatedFromJson(Map json) =>
    SseLspUpdated($type: json['type'] as String?);

Map<String, dynamic> _$SseLspUpdatedToJson(SseLspUpdated instance) =>
    <String, dynamic>{'type': instance.$type};

SseLspClientDiagnostics _$SseLspClientDiagnosticsFromJson(Map json) =>
    SseLspClientDiagnostics(
      serverID: json['serverID'] as String?,
      path: json['path'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseLspClientDiagnosticsToJson(
  SseLspClientDiagnostics instance,
) => <String, dynamic>{
  'serverID': instance.serverID,
  'path': instance.path,
  'type': instance.$type,
};

SseMcpToolsChanged _$SseMcpToolsChangedFromJson(Map json) =>
    SseMcpToolsChanged($type: json['type'] as String?);

Map<String, dynamic> _$SseMcpToolsChangedToJson(SseMcpToolsChanged instance) =>
    <String, dynamic>{'type': instance.$type};

SseMcpBrowserOpenFailed _$SseMcpBrowserOpenFailedFromJson(Map json) =>
    SseMcpBrowserOpenFailed($type: json['type'] as String?);

Map<String, dynamic> _$SseMcpBrowserOpenFailedToJson(
  SseMcpBrowserOpenFailed instance,
) => <String, dynamic>{'type': instance.$type};

SseInstallationUpdated _$SseInstallationUpdatedFromJson(Map json) =>
    SseInstallationUpdated(
      version: json['version'] as String?,
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$SseInstallationUpdatedToJson(
  SseInstallationUpdated instance,
) => <String, dynamic>{'version': instance.version, 'type': instance.$type};

SseInstallationUpdateAvailable _$SseInstallationUpdateAvailableFromJson(
  Map json,
) => SseInstallationUpdateAvailable(
  version: json['version'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseInstallationUpdateAvailableToJson(
  SseInstallationUpdateAvailable instance,
) => <String, dynamic>{'version': instance.version, 'type': instance.$type};

SseWorkspaceReady _$SseWorkspaceReadyFromJson(Map json) => SseWorkspaceReady(
  name: json['name'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseWorkspaceReadyToJson(SseWorkspaceReady instance) =>
    <String, dynamic>{'name': instance.name, 'type': instance.$type};

SseWorkspaceFailed _$SseWorkspaceFailedFromJson(Map json) => SseWorkspaceFailed(
  message: json['message'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseWorkspaceFailedToJson(SseWorkspaceFailed instance) =>
    <String, dynamic>{'message': instance.message, 'type': instance.$type};

SseTuiToastShow _$SseTuiToastShowFromJson(Map json) => SseTuiToastShow(
  title: json['title'] as String?,
  message: json['message'] as String?,
  variant: json['variant'] as String?,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$SseTuiToastShowToJson(SseTuiToastShow instance) =>
    <String, dynamic>{
      'title': instance.title,
      'message': instance.message,
      'variant': instance.variant,
      'type': instance.$type,
    };

SseWorktreeReady _$SseWorktreeReadyFromJson(Map json) =>
    SseWorktreeReady($type: json['type'] as String?);

Map<String, dynamic> _$SseWorktreeReadyToJson(SseWorktreeReady instance) =>
    <String, dynamic>{'type': instance.$type};

SseWorktreeFailed _$SseWorktreeFailedFromJson(Map json) =>
    SseWorktreeFailed($type: json['type'] as String?);

Map<String, dynamic> _$SseWorktreeFailedToJson(SseWorktreeFailed instance) =>
    <String, dynamic>{'type': instance.$type};
