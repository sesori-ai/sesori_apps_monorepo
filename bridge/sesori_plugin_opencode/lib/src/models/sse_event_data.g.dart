// GENERATED FILE - DO NOT EDIT BY HAND
//
// Source manifest: tool/opencode_events_v1.json
// To regenerate: dart run tool/generate_sse_events.dart

// `FormatException` lives in `dart:core`; no extra import needed.
import "openapi/message.g.dart";
import "openapi/part.g.dart";
import "openapi/question_info.g.dart";
import "openapi/session.g.dart";
import "openapi/session_status.g.dart";
import "openapi/snapshot_file_diff.g.dart";

/// Marker sealed type for all SSE events that are scoped to a specific
/// session. Any [SseEventData] variant that carries a session context
/// implements this. Use this to obtain a typed stream of only the events
/// that can ever be received for a given session, enabling exhaustive
/// switching over only session-scoped variants.
sealed class SseSessionEventData {}

/// Typed representation of all known SSE event payloads. Each variant
/// carries a [type] matching the wire-format string and a payload
/// corresponding to the field set declared in the event manifest.
///
/// Deserialization dispatches on the JSON `type` field. Unknown event
/// types cause [fromJson] to throw — callers should catch and report.
sealed class SseEventData {
  const SseEventData();

  // -------------------------------------------------------------------
  // Redirecting factories
  //
  // Each variant gets a `SseEventData.<eventCamelName>(...)`
  // redirecting factory so callers that pre-date the typed variant
  // classes can still construct events through the base class.
  // -------------------------------------------------------------------
  const factory SseEventData.serverConnected() = SseServerConnected;
  const factory SseEventData.serverHeartbeat() = SseServerHeartbeat;
  const factory SseEventData.serverInstanceDisposed({
    String? directory,
  }) = SseServerInstanceDisposed;
  const factory SseEventData.globalDisposed() = SseGlobalDisposed;
  const factory SseEventData.sessionCreated({
    required Session info,
  }) = SseSessionCreated;
  const factory SseEventData.sessionUpdated({
    required Session info,
  }) = SseSessionUpdated;
  const factory SseEventData.sessionDeleted({
    required Session info,
  }) = SseSessionDeleted;
  const factory SseEventData.sessionDiff({
    required String sessionID,
    required List<SnapshotFileDiff> diff,
  }) = SseSessionDiff;
  const factory SseEventData.sessionError({
    String? sessionID,
  }) = SseSessionError;
  const factory SseEventData.sessionCompacted({
    required String sessionID,
  }) = SseSessionCompacted;
  const factory SseEventData.sessionStatus({
    required String sessionID,
    required SessionStatus status,
  }) = SseSessionStatus;
  const factory SseEventData.sessionIdle({
    required String sessionID,
  }) = SseSessionIdle;
  const factory SseEventData.commandExecuted({
    required String name,
    required String sessionID,
    required String arguments,
    required String messageID,
  }) = SseCommandExecuted;
  const factory SseEventData.messageUpdated({
    required Message info,
  }) = SseMessageUpdated;
  const factory SseEventData.messageRemoved({
    required String sessionID,
    required String messageID,
  }) = SseMessageRemoved;
  const factory SseEventData.messagePartUpdated({
    required Part part,
  }) = SseMessagePartUpdated;
  const factory SseEventData.messagePartDelta({
    required String sessionID,
    required String messageID,
    required String partID,
    required String field,
    required String delta,
  }) = SseMessagePartDelta;
  const factory SseEventData.messagePartRemoved({
    required String sessionID,
    required String messageID,
    required String partID,
  }) = SseMessagePartRemoved;
  const factory SseEventData.ptyCreated() = SsePtyCreated;
  const factory SseEventData.ptyUpdated() = SsePtyUpdated;
  const factory SseEventData.ptyExited({
    String? id,
    int? exitCode,
  }) = SsePtyExited;
  const factory SseEventData.ptyDeleted({
    String? id,
  }) = SsePtyDeleted;
  const factory SseEventData.permissionAsked({
    required String id,
    required String sessionID,
    required String permission,
    required List<String> patterns,
  }) = SsePermissionAsked;
  const factory SseEventData.permissionReplied({
    required String requestID,
    required String sessionID,
    required String reply,
  }) = SsePermissionReplied;
  const factory SseEventData.permissionUpdated() = SsePermissionUpdated;
  const factory SseEventData.questionAsked({
    required String id,
    required String sessionID,
    required List<QuestionInfo> questions,
  }) = SseQuestionAsked;
  const factory SseEventData.questionReplied({
    required String requestID,
    required String sessionID,
  }) = SseQuestionReplied;
  const factory SseEventData.questionRejected({
    required String requestID,
    required String sessionID,
  }) = SseQuestionRejected;
  const factory SseEventData.todoUpdated({
    required String sessionID,
  }) = SseTodoUpdated;
  const factory SseEventData.projectUpdated() = SseProjectUpdated;
  const factory SseEventData.vcsBranchUpdated() = SseVcsBranchUpdated;
  const factory SseEventData.fileEdited({
    String? file,
  }) = SseFileEdited;
  const factory SseEventData.fileWatcherUpdated({
    String? file,
    String? event,
  }) = SseFileWatcherUpdated;
  const factory SseEventData.lspUpdated() = SseLspUpdated;
  const factory SseEventData.lspClientDiagnostics({
    String? serverID,
    String? path,
  }) = SseLspClientDiagnostics;
  const factory SseEventData.mcpToolsChanged() = SseMcpToolsChanged;
  const factory SseEventData.mcpBrowserOpenFailed() = SseMcpBrowserOpenFailed;
  const factory SseEventData.installationUpdated({
    String? version,
  }) = SseInstallationUpdated;
  const factory SseEventData.installationUpdateAvailable({
    String? version,
  }) = SseInstallationUpdateAvailable;
  const factory SseEventData.workspaceReady({
    String? name,
  }) = SseWorkspaceReady;
  const factory SseEventData.workspaceFailed({
    String? message,
  }) = SseWorkspaceFailed;
  const factory SseEventData.tuiToastShow({
    String? title,
    String? message,
    String? variant,
  }) = SseTuiToastShow;
  const factory SseEventData.worktreeReady() = SseWorktreeReady;
  const factory SseEventData.worktreeFailed() = SseWorktreeFailed;

  /// Wire-format type discriminator for this event.
  String get type;

  /// Encodes this event back to its JSON wire form, including the
  /// `type` discriminator.
  Map<String, dynamic> toJson();

  /// Decodes a JSON envelope into the corresponding [SseEventData]
  /// variant by dispatching on the `type` field.
  factory SseEventData.fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String?;
    if (type == null) {
      throw const FormatException("SSE event missing 'type' field");
    }
    return switch (type) {
      "server.connected" => SseServerConnected.fromJson(json),
      "server.heartbeat" => SseServerHeartbeat.fromJson(json),
      "server.instance.disposed" => SseServerInstanceDisposed.fromJson(json),
      "global.disposed" => SseGlobalDisposed.fromJson(json),
      "session.created" => SseSessionCreated.fromJson(json),
      "session.updated" => SseSessionUpdated.fromJson(json),
      "session.deleted" => SseSessionDeleted.fromJson(json),
      "session.diff" => SseSessionDiff.fromJson(json),
      "session.error" => SseSessionError.fromJson(json),
      "session.compacted" => SseSessionCompacted.fromJson(json),
      "session.status" => SseSessionStatus.fromJson(json),
      "session.idle" => SseSessionIdle.fromJson(json),
      "command.executed" => SseCommandExecuted.fromJson(json),
      "message.updated" => SseMessageUpdated.fromJson(json),
      "message.removed" => SseMessageRemoved.fromJson(json),
      "message.part.updated" => SseMessagePartUpdated.fromJson(json),
      "message.part.delta" => SseMessagePartDelta.fromJson(json),
      "message.part.removed" => SseMessagePartRemoved.fromJson(json),
      "pty.created" => SsePtyCreated.fromJson(json),
      "pty.updated" => SsePtyUpdated.fromJson(json),
      "pty.exited" => SsePtyExited.fromJson(json),
      "pty.deleted" => SsePtyDeleted.fromJson(json),
      "permission.asked" => SsePermissionAsked.fromJson(json),
      "permission.replied" => SsePermissionReplied.fromJson(json),
      "permission.updated" => SsePermissionUpdated.fromJson(json),
      "question.asked" => SseQuestionAsked.fromJson(json),
      "question.replied" => SseQuestionReplied.fromJson(json),
      "question.rejected" => SseQuestionRejected.fromJson(json),
      "todo.updated" => SseTodoUpdated.fromJson(json),
      "project.updated" => SseProjectUpdated.fromJson(json),
      "vcs.branch.updated" => SseVcsBranchUpdated.fromJson(json),
      "file.edited" => SseFileEdited.fromJson(json),
      "file.watcher.updated" => SseFileWatcherUpdated.fromJson(json),
      "lsp.updated" => SseLspUpdated.fromJson(json),
      "lsp.client.diagnostics" => SseLspClientDiagnostics.fromJson(json),
      "mcp.tools.changed" => SseMcpToolsChanged.fromJson(json),
      "mcp.browser.open.failed" => SseMcpBrowserOpenFailed.fromJson(json),
      "installation.updated" => SseInstallationUpdated.fromJson(json),
      "installation.update-available" => SseInstallationUpdateAvailable.fromJson(json),
      "workspace.ready" => SseWorkspaceReady.fromJson(json),
      "workspace.failed" => SseWorkspaceFailed.fromJson(json),
      "tui.toast.show" => SseTuiToastShow.fromJson(json),
      "worktree.ready" => SseWorktreeReady.fromJson(json),
      "worktree.failed" => SseWorktreeFailed.fromJson(json),
      final String unknown =>
        throw FormatException("Unknown SSE event type: $unknown"),
    };
  }
}

class SseServerConnected extends SseEventData {
  const SseServerConnected();

  @override
  String get type => "server.connected";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseServerConnected.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "server.connected");
    return const SseServerConnected();
  }
}
class SseServerHeartbeat extends SseEventData {
  const SseServerHeartbeat();

  @override
  String get type => "server.heartbeat";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseServerHeartbeat.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "server.heartbeat");
    return const SseServerHeartbeat();
  }
}
class SseServerInstanceDisposed extends SseEventData {
  const SseServerInstanceDisposed({
    this.directory,
  });

  final String? directory;

  @override
  String get type => "server.instance.disposed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "directory": directory,
  };

  factory SseServerInstanceDisposed.fromJson(Map<String, dynamic> json) {
    return SseServerInstanceDisposed(
      directory: json["directory"] == null ? null : json["directory"] as String,
    );
  }
}
class SseGlobalDisposed extends SseEventData {
  const SseGlobalDisposed();

  @override
  String get type => "global.disposed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseGlobalDisposed.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "global.disposed");
    return const SseGlobalDisposed();
  }
}
class SseSessionCreated extends SseEventData implements SseSessionEventData {
  const SseSessionCreated({
    required this.info,
  });

  final Session info;

  @override
  String get type => "session.created";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "info": info.toJson(),
  };

  factory SseSessionCreated.fromJson(Map<String, dynamic> json) {
    return SseSessionCreated(
      info: Session.fromJson(json["info"] as Map<String, dynamic>),
    );
  }
}
class SseSessionUpdated extends SseEventData implements SseSessionEventData {
  const SseSessionUpdated({
    required this.info,
  });

  final Session info;

  @override
  String get type => "session.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "info": info.toJson(),
  };

  factory SseSessionUpdated.fromJson(Map<String, dynamic> json) {
    return SseSessionUpdated(
      info: Session.fromJson(json["info"] as Map<String, dynamic>),
    );
  }
}
class SseSessionDeleted extends SseEventData implements SseSessionEventData {
  const SseSessionDeleted({
    required this.info,
  });

  final Session info;

  @override
  String get type => "session.deleted";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "info": info.toJson(),
  };

  factory SseSessionDeleted.fromJson(Map<String, dynamic> json) {
    return SseSessionDeleted(
      info: Session.fromJson(json["info"] as Map<String, dynamic>),
    );
  }
}
class SseSessionDiff extends SseEventData implements SseSessionEventData {
  const SseSessionDiff({
    required this.sessionID,
    required this.diff,
  });

  final String sessionID;
  final List<SnapshotFileDiff> diff;

  @override
  String get type => "session.diff";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "diff": diff.map((e) => e.toJson()).toList(),
  };

  factory SseSessionDiff.fromJson(Map<String, dynamic> json) {
    return SseSessionDiff(
      sessionID: json["sessionID"] as String,
      diff: (json["diff"] as List<dynamic>).map((e) => SnapshotFileDiff.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
class SseSessionError extends SseEventData implements SseSessionEventData {
  const SseSessionError({
    this.sessionID,
  });

  final String? sessionID;

  @override
  String get type => "session.error";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory SseSessionError.fromJson(Map<String, dynamic> json) {
    return SseSessionError(
      sessionID: json["sessionID"] == null ? null : json["sessionID"] as String,
    );
  }
}
class SseSessionCompacted extends SseEventData implements SseSessionEventData {
  const SseSessionCompacted({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "session.compacted";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory SseSessionCompacted.fromJson(Map<String, dynamic> json) {
    return SseSessionCompacted(
      sessionID: json["sessionID"] as String,
    );
  }
}
class SseSessionStatus extends SseEventData implements SseSessionEventData {
  const SseSessionStatus({
    required this.sessionID,
    required this.status,
  });

  final String sessionID;
  final SessionStatus status;

  @override
  String get type => "session.status";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "status": status.toJson(),
  };

  factory SseSessionStatus.fromJson(Map<String, dynamic> json) {
    return SseSessionStatus(
      sessionID: json["sessionID"] as String,
      status: SessionStatus.fromJson(json["status"] as Map<String, dynamic>),
    );
  }
}
/// Deprecated event. Use sessionStatus instead. Emitted for backward compatibility.
// ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility
@Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
class SseSessionIdle extends SseEventData implements SseSessionEventData {
  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility
  @Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
  const SseSessionIdle({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "session.idle";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility
  @Deprecated("Use sessionStatus instead. Emitted for backward compatibility.")
  factory SseSessionIdle.fromJson(Map<String, dynamic> json) {
    return SseSessionIdle(
      sessionID: json["sessionID"] as String,
    );
  }
}
class SseCommandExecuted extends SseEventData implements SseSessionEventData {
  const SseCommandExecuted({
    required this.name,
    required this.sessionID,
    required this.arguments,
    required this.messageID,
  });

  final String name;
  final String sessionID;
  final String arguments;
  final String messageID;

  @override
  String get type => "command.executed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "name": name,
    "sessionID": sessionID,
    "arguments": arguments,
    "messageID": messageID,
  };

  factory SseCommandExecuted.fromJson(Map<String, dynamic> json) {
    return SseCommandExecuted(
      name: json["name"] as String,
      sessionID: json["sessionID"] as String,
      arguments: json["arguments"] as String,
      messageID: json["messageID"] as String,
    );
  }
}
class SseMessageUpdated extends SseEventData implements SseSessionEventData {
  const SseMessageUpdated({
    required this.info,
  });

  final Message info;

  @override
  String get type => "message.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "info": info.toJson(),
  };

  factory SseMessageUpdated.fromJson(Map<String, dynamic> json) {
    return SseMessageUpdated(
      info: Message.fromJson(json["info"] as Map<String, dynamic>),
    );
  }
}
class SseMessageRemoved extends SseEventData implements SseSessionEventData {
  const SseMessageRemoved({
    required this.sessionID,
    required this.messageID,
  });

  final String sessionID;
  final String messageID;

  @override
  String get type => "message.removed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "messageID": messageID,
  };

  factory SseMessageRemoved.fromJson(Map<String, dynamic> json) {
    return SseMessageRemoved(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
    );
  }
}
class SseMessagePartUpdated extends SseEventData implements SseSessionEventData {
  const SseMessagePartUpdated({
    required this.part,
  });

  final Part part;

  @override
  String get type => "message.part.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "part": part.toJson(),
  };

  factory SseMessagePartUpdated.fromJson(Map<String, dynamic> json) {
    return SseMessagePartUpdated(
      part: Part.fromJson(json["part"] as Map<String, dynamic>),
    );
  }
}
class SseMessagePartDelta extends SseEventData implements SseSessionEventData {
  const SseMessagePartDelta({
    required this.sessionID,
    required this.messageID,
    required this.partID,
    required this.field,
    required this.delta,
  });

  final String sessionID;
  final String messageID;
  final String partID;
  final String field;
  final String delta;

  @override
  String get type => "message.part.delta";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "messageID": messageID,
    "partID": partID,
    "field": field,
    "delta": delta,
  };

  factory SseMessagePartDelta.fromJson(Map<String, dynamic> json) {
    return SseMessagePartDelta(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
      field: json["field"] as String,
      delta: json["delta"] as String,
    );
  }
}
class SseMessagePartRemoved extends SseEventData implements SseSessionEventData {
  const SseMessagePartRemoved({
    required this.sessionID,
    required this.messageID,
    required this.partID,
  });

  final String sessionID;
  final String messageID;
  final String partID;

  @override
  String get type => "message.part.removed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "messageID": messageID,
    "partID": partID,
  };

  factory SseMessagePartRemoved.fromJson(Map<String, dynamic> json) {
    return SseMessagePartRemoved(
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      partID: json["partID"] as String,
    );
  }
}
class SsePtyCreated extends SseEventData {
  const SsePtyCreated();

  @override
  String get type => "pty.created";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SsePtyCreated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "pty.created");
    return const SsePtyCreated();
  }
}
class SsePtyUpdated extends SseEventData {
  const SsePtyUpdated();

  @override
  String get type => "pty.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SsePtyUpdated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "pty.updated");
    return const SsePtyUpdated();
  }
}
class SsePtyExited extends SseEventData {
  const SsePtyExited({
    this.id,
    this.exitCode,
  });

  final String? id;
  final int? exitCode;

  @override
  String get type => "pty.exited";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "exitCode": exitCode,
  };

  factory SsePtyExited.fromJson(Map<String, dynamic> json) {
    return SsePtyExited(
      id: json["id"] == null ? null : json["id"] as String,
      exitCode: json["exitCode"] == null ? null : (json["exitCode"] as num).toInt(),
    );
  }
}
class SsePtyDeleted extends SseEventData {
  const SsePtyDeleted({
    this.id,
  });

  final String? id;

  @override
  String get type => "pty.deleted";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
  };

  factory SsePtyDeleted.fromJson(Map<String, dynamic> json) {
    return SsePtyDeleted(
      id: json["id"] == null ? null : json["id"] as String,
    );
  }
}
class SsePermissionAsked extends SseEventData implements SseSessionEventData {
  const SsePermissionAsked({
    required this.id,
    required this.sessionID,
    required this.permission,
    required this.patterns,
  });

  final String id;
  final String sessionID;
  final String permission;
  final List<String> patterns;

  @override
  String get type => "permission.asked";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "sessionID": sessionID,
    "permission": permission,
    "patterns": patterns,
  };

  factory SsePermissionAsked.fromJson(Map<String, dynamic> json) {
    return SsePermissionAsked(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      permission: json["permission"] as String,
      patterns: (json["patterns"] as List<dynamic>).cast<String>(),
    );
  }
}
class SsePermissionReplied extends SseEventData implements SseSessionEventData {
  const SsePermissionReplied({
    required this.requestID,
    required this.sessionID,
    required this.reply,
  });

  final String requestID;
  final String sessionID;
  final String reply;

  @override
  String get type => "permission.replied";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "requestID": requestID,
    "sessionID": sessionID,
    "reply": reply,
  };

  factory SsePermissionReplied.fromJson(Map<String, dynamic> json) {
    return SsePermissionReplied(
      requestID: json["requestID"] as String,
      sessionID: json["sessionID"] as String,
      reply: json["reply"] as String,
    );
  }
}
class SsePermissionUpdated extends SseEventData {
  const SsePermissionUpdated();

  @override
  String get type => "permission.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SsePermissionUpdated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "permission.updated");
    return const SsePermissionUpdated();
  }
}
class SseQuestionAsked extends SseEventData implements SseSessionEventData {
  const SseQuestionAsked({
    required this.id,
    required this.sessionID,
    required this.questions,
  });

  final String id;
  final String sessionID;
  final List<QuestionInfo> questions;

  @override
  String get type => "question.asked";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "sessionID": sessionID,
    "questions": questions.map((e) => e.toJson()).toList(),
  };

  factory SseQuestionAsked.fromJson(Map<String, dynamic> json) {
    return SseQuestionAsked(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      questions: (json["questions"] as List<dynamic>).map((e) => QuestionInfo.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
class SseQuestionReplied extends SseEventData implements SseSessionEventData {
  const SseQuestionReplied({
    required this.requestID,
    required this.sessionID,
  });

  final String requestID;
  final String sessionID;

  @override
  String get type => "question.replied";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "requestID": requestID,
    "sessionID": sessionID,
  };

  factory SseQuestionReplied.fromJson(Map<String, dynamic> json) {
    return SseQuestionReplied(
      requestID: json["requestID"] as String,
      sessionID: json["sessionID"] as String,
    );
  }
}
class SseQuestionRejected extends SseEventData implements SseSessionEventData {
  const SseQuestionRejected({
    required this.requestID,
    required this.sessionID,
  });

  final String requestID;
  final String sessionID;

  @override
  String get type => "question.rejected";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "requestID": requestID,
    "sessionID": sessionID,
  };

  factory SseQuestionRejected.fromJson(Map<String, dynamic> json) {
    return SseQuestionRejected(
      requestID: json["requestID"] as String,
      sessionID: json["sessionID"] as String,
    );
  }
}
class SseTodoUpdated extends SseEventData implements SseSessionEventData {
  const SseTodoUpdated({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "todo.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory SseTodoUpdated.fromJson(Map<String, dynamic> json) {
    return SseTodoUpdated(
      sessionID: json["sessionID"] as String,
    );
  }
}
class SseProjectUpdated extends SseEventData {
  const SseProjectUpdated();

  @override
  String get type => "project.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseProjectUpdated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "project.updated");
    return const SseProjectUpdated();
  }
}
class SseVcsBranchUpdated extends SseEventData {
  const SseVcsBranchUpdated();

  @override
  String get type => "vcs.branch.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseVcsBranchUpdated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "vcs.branch.updated");
    return const SseVcsBranchUpdated();
  }
}
class SseFileEdited extends SseEventData {
  const SseFileEdited({
    this.file,
  });

  final String? file;

  @override
  String get type => "file.edited";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "file": file,
  };

  factory SseFileEdited.fromJson(Map<String, dynamic> json) {
    return SseFileEdited(
      file: json["file"] == null ? null : json["file"] as String,
    );
  }
}
class SseFileWatcherUpdated extends SseEventData {
  const SseFileWatcherUpdated({
    this.file,
    this.event,
  });

  final String? file;
  final String? event;

  @override
  String get type => "file.watcher.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "file": file,
    "event": event,
  };

  factory SseFileWatcherUpdated.fromJson(Map<String, dynamic> json) {
    return SseFileWatcherUpdated(
      file: json["file"] == null ? null : json["file"] as String,
      event: json["event"] == null ? null : json["event"] as String,
    );
  }
}
class SseLspUpdated extends SseEventData {
  const SseLspUpdated();

  @override
  String get type => "lsp.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseLspUpdated.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "lsp.updated");
    return const SseLspUpdated();
  }
}
class SseLspClientDiagnostics extends SseEventData {
  const SseLspClientDiagnostics({
    this.serverID,
    this.path,
  });

  final String? serverID;
  final String? path;

  @override
  String get type => "lsp.client.diagnostics";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "serverID": serverID,
    "path": path,
  };

  factory SseLspClientDiagnostics.fromJson(Map<String, dynamic> json) {
    return SseLspClientDiagnostics(
      serverID: json["serverID"] == null ? null : json["serverID"] as String,
      path: json["path"] == null ? null : json["path"] as String,
    );
  }
}
class SseMcpToolsChanged extends SseEventData {
  const SseMcpToolsChanged();

  @override
  String get type => "mcp.tools.changed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseMcpToolsChanged.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "mcp.tools.changed");
    return const SseMcpToolsChanged();
  }
}
class SseMcpBrowserOpenFailed extends SseEventData {
  const SseMcpBrowserOpenFailed();

  @override
  String get type => "mcp.browser.open.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseMcpBrowserOpenFailed.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "mcp.browser.open.failed");
    return const SseMcpBrowserOpenFailed();
  }
}
class SseInstallationUpdated extends SseEventData {
  const SseInstallationUpdated({
    this.version,
  });

  final String? version;

  @override
  String get type => "installation.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "version": version,
  };

  factory SseInstallationUpdated.fromJson(Map<String, dynamic> json) {
    return SseInstallationUpdated(
      version: json["version"] == null ? null : json["version"] as String,
    );
  }
}
class SseInstallationUpdateAvailable extends SseEventData {
  const SseInstallationUpdateAvailable({
    this.version,
  });

  final String? version;

  @override
  String get type => "installation.update-available";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "version": version,
  };

  factory SseInstallationUpdateAvailable.fromJson(Map<String, dynamic> json) {
    return SseInstallationUpdateAvailable(
      version: json["version"] == null ? null : json["version"] as String,
    );
  }
}
class SseWorkspaceReady extends SseEventData {
  const SseWorkspaceReady({
    this.name,
  });

  final String? name;

  @override
  String get type => "workspace.ready";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "name": name,
  };

  factory SseWorkspaceReady.fromJson(Map<String, dynamic> json) {
    return SseWorkspaceReady(
      name: json["name"] == null ? null : json["name"] as String,
    );
  }
}
class SseWorkspaceFailed extends SseEventData {
  const SseWorkspaceFailed({
    this.message,
  });

  final String? message;

  @override
  String get type => "workspace.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "message": message,
  };

  factory SseWorkspaceFailed.fromJson(Map<String, dynamic> json) {
    return SseWorkspaceFailed(
      message: json["message"] == null ? null : json["message"] as String,
    );
  }
}
class SseTuiToastShow extends SseEventData {
  const SseTuiToastShow({
    this.title,
    this.message,
    this.variant,
  });

  final String? title;
  final String? message;
  final String? variant;

  @override
  String get type => "tui.toast.show";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "title": title,
    "message": message,
    "variant": variant,
  };

  factory SseTuiToastShow.fromJson(Map<String, dynamic> json) {
    return SseTuiToastShow(
      title: json["title"] == null ? null : json["title"] as String,
      message: json["message"] == null ? null : json["message"] as String,
      variant: json["variant"] == null ? null : json["variant"] as String,
    );
  }
}
class SseWorktreeReady extends SseEventData {
  const SseWorktreeReady();

  @override
  String get type => "worktree.ready";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseWorktreeReady.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "worktree.ready");
    return const SseWorktreeReady();
  }
}
class SseWorktreeFailed extends SseEventData {
  const SseWorktreeFailed();

  @override
  String get type => "worktree.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory SseWorktreeFailed.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "worktree.failed");
    return const SseWorktreeFailed();
  }
}
