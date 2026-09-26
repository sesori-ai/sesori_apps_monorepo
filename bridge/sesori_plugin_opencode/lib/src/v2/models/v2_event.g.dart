// GENERATED FILE - DO NOT EDIT BY HAND
//
// Source manifest: tool/opencode_events_v2.json
// To regenerate: dart run tool/generate_sse_events.dart --manifest tool/opencode_events_v2.json --out lib/src/v2/models/v2_event.g.dart

// `FormatException` lives in `dart:core`; no extra import needed.
import "openapi/form_answer.g.dart";
import "openapi/form_info.g.dart";
import "openapi/location_public_ref.g.dart";
import "openapi/model_ref.g.dart";
import "openapi/permission_reply.g.dart";
import "openapi/permission_source.g.dart";
import "openapi/project_icon.g.dart";
import "openapi/project_time.g.dart";
import "openapi/session_structured_error.g.dart";
import "openapi/token_usage_info.g.dart";
import "openapi/tool_content.g.dart";
import "v2_execution_interrupt_reason.dart";

/// Marker sealed type for all SSE events that are scoped to a specific
/// session. Any [V2EventData] variant that carries a session context
/// implements this. Use this to obtain a typed stream of only the events
/// that can ever be received for a given session, enabling exhaustive
/// switching over only session-scoped variants.
sealed class V2SessionEventData {}

/// Typed representation of all known SSE event payloads. Each variant
/// carries a [type] matching the wire-format string and a payload
/// corresponding to the field set declared in the event manifest.
///
/// Deserialization dispatches on the JSON `type` field. Unknown event
/// types cause [fromJson] to throw — callers should catch and report.
sealed class V2EventData {
  const V2EventData();

  // -------------------------------------------------------------------
  // Redirecting factories
  //
  // Each variant gets a `V2EventData.<eventCamelName>(...)`
  // redirecting factory so callers that pre-date the typed variant
  // classes can still construct events through the base class.
  // -------------------------------------------------------------------
  const factory V2EventData.serverConnected() = V2ServerConnected;
  const factory V2EventData.sessionCreated({
    required String sessionID,
    required String projectID,
    required LocationPublicRef location,
    String? subpath,
    String? parentID,
    required String slug,
    String? title,
    String? agent,
    ModelRef? model,
    required String version,
  }) = V2SessionCreated;
  const factory V2EventData.sessionRenamed({
    required String sessionID,
    required String title,
  }) = V2SessionRenamed;
  const factory V2EventData.sessionDeleted({
    required String sessionID,
  }) = V2SessionDeleted;
  const factory V2EventData.sessionExecutionStarted({
    required String sessionID,
  }) = V2SessionExecutionStarted;
  const factory V2EventData.sessionExecutionSucceeded({
    required String sessionID,
  }) = V2SessionExecutionSucceeded;
  const factory V2EventData.sessionExecutionFailed({
    required String sessionID,
    required SessionStructuredError error,
  }) = V2SessionExecutionFailed;
  const factory V2EventData.sessionExecutionInterrupted({
    required String sessionID,
    required V2ExecutionInterruptReason reason,
  }) = V2SessionExecutionInterrupted;
  const factory V2EventData.sessionInboxEnqueued({
    required String sessionID,
    required String inboxID,
  }) = V2SessionInboxEnqueued;
  const factory V2EventData.sessionInboxDelivered({
    required String sessionID,
    required String inboxID,
  }) = V2SessionInboxDelivered;
  const factory V2EventData.sessionInboxCancelled({
    required String sessionID,
    required String inboxID,
  }) = V2SessionInboxCancelled;
  const factory V2EventData.sessionInboxDeliveryChanged({
    required String sessionID,
    required String inboxID,
  }) = V2SessionInboxDeliveryChanged;
  const factory V2EventData.sessionAgentSelected({
    required String sessionID,
    required String agent,
    String? previous,
  }) = V2SessionAgentSelected;
  const factory V2EventData.sessionSynthetic({
    required String sessionID,
    required String text,
    String? description,
  }) = V2SessionSynthetic;
  const factory V2EventData.sessionStepStarted({
    required String sessionID,
    required String assistantMessageID,
    required String agent,
    required ModelRef model,
    required int started,
  }) = V2SessionStepStarted;
  const factory V2EventData.sessionStepEnded({
    required String sessionID,
    required String assistantMessageID,
    required double cost,
    required TokenUsageInfo tokens,
  }) = V2SessionStepEnded;
  const factory V2EventData.sessionStepFailed({
    required String sessionID,
    required String assistantMessageID,
    required SessionStructuredError error,
    double? cost,
    TokenUsageInfo? tokens,
  }) = V2SessionStepFailed;
  const factory V2EventData.sessionTextStarted({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
  }) = V2SessionTextStarted;
  const factory V2EventData.sessionTextDelta({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
    required String delta,
  }) = V2SessionTextDelta;
  const factory V2EventData.sessionTextEnded({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
    required String text,
  }) = V2SessionTextEnded;
  const factory V2EventData.sessionReasoningStarted({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
  }) = V2SessionReasoningStarted;
  const factory V2EventData.sessionReasoningDelta({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
    required String delta,
  }) = V2SessionReasoningDelta;
  const factory V2EventData.sessionReasoningEnded({
    required String sessionID,
    required String assistantMessageID,
    required int ordinal,
    required String text,
  }) = V2SessionReasoningEnded;
  const factory V2EventData.sessionToolInputStarted({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required String name,
  }) = V2SessionToolInputStarted;
  const factory V2EventData.sessionToolInputDelta({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required String delta,
  }) = V2SessionToolInputDelta;
  const factory V2EventData.sessionToolInputEnded({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required String text,
  }) = V2SessionToolInputEnded;
  const factory V2EventData.sessionToolCalled({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required Map<String, dynamic> input,
    required bool executed,
  }) = V2SessionToolCalled;
  const factory V2EventData.sessionToolProgress({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required Map<String, dynamic> metadata,
  }) = V2SessionToolProgress;
  const factory V2EventData.sessionToolSuccess({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required List<ToolContent> content,
    Map<String, dynamic>? metadata,
    required bool executed,
  }) = V2SessionToolSuccess;
  const factory V2EventData.sessionToolFailed({
    required String sessionID,
    required String assistantMessageID,
    required String id,
    required SessionStructuredError error,
    List<ToolContent>? content,
    Map<String, dynamic>? metadata,
    required bool executed,
  }) = V2SessionToolFailed;
  const factory V2EventData.sessionRetryScheduled({
    required String sessionID,
    required String assistantMessageID,
    required int attempt,
    required int at,
    required SessionStructuredError error,
  }) = V2SessionRetryScheduled;
  const factory V2EventData.sessionCompactionStarted({
    required String sessionID,
    String? inputID,
  }) = V2SessionCompactionStarted;
  const factory V2EventData.sessionCompactionDelta({
    required String sessionID,
    required String text,
  }) = V2SessionCompactionDelta;
  const factory V2EventData.sessionCompactionEnded({
    required String sessionID,
    required String text,
    required String recent,
  }) = V2SessionCompactionEnded;
  const factory V2EventData.sessionCompactionFailed({
    required String sessionID,
    required SessionStructuredError error,
    String? inputID,
  }) = V2SessionCompactionFailed;
  const factory V2EventData.permissionAsked({
    required String id,
    required String sessionID,
    required String action,
    required List<String> resources,
    List<String>? save,
    Map<String, dynamic>? metadata,
    PermissionSource? source,
    String? message,
  }) = V2PermissionAsked;
  const factory V2EventData.permissionReplied({
    required String sessionID,
    required String requestID,
    required PermissionReply reply,
  }) = V2PermissionReplied;
  const factory V2EventData.formCreated({
    required FormInfo form,
  }) = V2FormCreated;
  const factory V2EventData.formReplied({
    required String id,
    required String sessionID,
    required FormAnswer answer,
  }) = V2FormReplied;
  const factory V2EventData.formCancelled({
    required String id,
    required String sessionID,
  }) = V2FormCancelled;
  const factory V2EventData.projectUpdated({
    required String id,
    required String canonical,
    String? vcs,
    String? name,
    ProjectIcon? icon,
    required ProjectTime time,
    required List<String> sandboxes,
  }) = V2ProjectUpdated;

  /// Wire-format type discriminator for this event.
  String get type;

  /// Encodes this event back to its JSON wire form, including the
  /// `type` discriminator.
  Map<String, dynamic> toJson();

  /// Decodes a JSON envelope into the corresponding [V2EventData]
  /// variant by dispatching on the `type` field.
  factory V2EventData.fromJson(Map<String, dynamic> json) {
    final type = json["type"] as String?;
    if (type == null) {
      throw const FormatException("SSE event missing 'type' field");
    }
    return switch (type) {
      "server.connected" => V2ServerConnected.fromJson(json),
      "session.created" => V2SessionCreated.fromJson(json),
      "session.renamed" => V2SessionRenamed.fromJson(json),
      "session.deleted" => V2SessionDeleted.fromJson(json),
      "session.execution.started" => V2SessionExecutionStarted.fromJson(json),
      "session.execution.succeeded" => V2SessionExecutionSucceeded.fromJson(json),
      "session.execution.failed" => V2SessionExecutionFailed.fromJson(json),
      "session.execution.interrupted" => V2SessionExecutionInterrupted.fromJson(json),
      "session.inbox.enqueued" => V2SessionInboxEnqueued.fromJson(json),
      "session.inbox.delivered" => V2SessionInboxDelivered.fromJson(json),
      "session.inbox.cancelled" => V2SessionInboxCancelled.fromJson(json),
      "session.inbox.delivery.changed" => V2SessionInboxDeliveryChanged.fromJson(json),
      "session.agent.selected" => V2SessionAgentSelected.fromJson(json),
      "session.synthetic" => V2SessionSynthetic.fromJson(json),
      "session.step.started" => V2SessionStepStarted.fromJson(json),
      "session.step.ended" => V2SessionStepEnded.fromJson(json),
      "session.step.failed" => V2SessionStepFailed.fromJson(json),
      "session.text.started" => V2SessionTextStarted.fromJson(json),
      "session.text.delta" => V2SessionTextDelta.fromJson(json),
      "session.text.ended" => V2SessionTextEnded.fromJson(json),
      "session.reasoning.started" => V2SessionReasoningStarted.fromJson(json),
      "session.reasoning.delta" => V2SessionReasoningDelta.fromJson(json),
      "session.reasoning.ended" => V2SessionReasoningEnded.fromJson(json),
      "session.tool.input.started" => V2SessionToolInputStarted.fromJson(json),
      "session.tool.input.delta" => V2SessionToolInputDelta.fromJson(json),
      "session.tool.input.ended" => V2SessionToolInputEnded.fromJson(json),
      "session.tool.called" => V2SessionToolCalled.fromJson(json),
      "session.tool.progress" => V2SessionToolProgress.fromJson(json),
      "session.tool.success" => V2SessionToolSuccess.fromJson(json),
      "session.tool.failed" => V2SessionToolFailed.fromJson(json),
      "session.retry.scheduled" => V2SessionRetryScheduled.fromJson(json),
      "session.compaction.started" => V2SessionCompactionStarted.fromJson(json),
      "session.compaction.delta" => V2SessionCompactionDelta.fromJson(json),
      "session.compaction.ended" => V2SessionCompactionEnded.fromJson(json),
      "session.compaction.failed" => V2SessionCompactionFailed.fromJson(json),
      "permission.asked" => V2PermissionAsked.fromJson(json),
      "permission.replied" => V2PermissionReplied.fromJson(json),
      "form.created" => V2FormCreated.fromJson(json),
      "form.replied" => V2FormReplied.fromJson(json),
      "form.cancelled" => V2FormCancelled.fromJson(json),
      "project.updated" => V2ProjectUpdated.fromJson(json),
      final String unknown =>
        throw FormatException("Unknown SSE event type: $unknown"),
    };
  }
}

class V2ServerConnected extends V2EventData {
  const V2ServerConnected();

  @override
  String get type => "server.connected";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};

  factory V2ServerConnected.fromJson(Map<String, dynamic> json) {
    assert(json["type"] == "server.connected");
    return const V2ServerConnected();
  }
}
class V2SessionCreated extends V2EventData implements V2SessionEventData {
  const V2SessionCreated({
    required this.sessionID,
    required this.projectID,
    required this.location,
    this.subpath,
    this.parentID,
    required this.slug,
    this.title,
    this.agent,
    this.model,
    required this.version,
  });

  final String sessionID;
  final String projectID;
  final LocationPublicRef location;
  final String? subpath;
  final String? parentID;
  final String slug;
  final String? title;
  final String? agent;
  final ModelRef? model;
  final String version;

  @override
  String get type => "session.created";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "projectID": projectID,
    "location": location.toJson(),
    "subpath": subpath,
    "parentID": parentID,
    "slug": slug,
    "title": title,
    "agent": agent,
    "model": model?.toJson(),
    "version": version,
  };

  factory V2SessionCreated.fromJson(Map<String, dynamic> json) {
    return V2SessionCreated(
      sessionID: json["sessionID"] as String,
      projectID: json["projectID"] as String,
      location: LocationPublicRef.fromJson(json["location"] as Map<String, dynamic>),
      subpath: json["subpath"] == null ? null : json["subpath"] as String,
      parentID: json["parentID"] == null ? null : json["parentID"] as String,
      slug: json["slug"] as String,
      title: json["title"] == null ? null : json["title"] as String,
      agent: json["agent"] == null ? null : json["agent"] as String,
      model: json["model"] == null ? null : ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      version: json["version"] as String,
    );
  }
}
class V2SessionRenamed extends V2EventData implements V2SessionEventData {
  const V2SessionRenamed({
    required this.sessionID,
    required this.title,
  });

  final String sessionID;
  final String title;

  @override
  String get type => "session.renamed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "title": title,
  };

  factory V2SessionRenamed.fromJson(Map<String, dynamic> json) {
    return V2SessionRenamed(
      sessionID: json["sessionID"] as String,
      title: json["title"] as String,
    );
  }
}
class V2SessionDeleted extends V2EventData implements V2SessionEventData {
  const V2SessionDeleted({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "session.deleted";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory V2SessionDeleted.fromJson(Map<String, dynamic> json) {
    return V2SessionDeleted(
      sessionID: json["sessionID"] as String,
    );
  }
}
class V2SessionExecutionStarted extends V2EventData implements V2SessionEventData {
  const V2SessionExecutionStarted({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "session.execution.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory V2SessionExecutionStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionExecutionStarted(
      sessionID: json["sessionID"] as String,
    );
  }
}
class V2SessionExecutionSucceeded extends V2EventData implements V2SessionEventData {
  const V2SessionExecutionSucceeded({
    required this.sessionID,
  });

  final String sessionID;

  @override
  String get type => "session.execution.succeeded";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
  };

  factory V2SessionExecutionSucceeded.fromJson(Map<String, dynamic> json) {
    return V2SessionExecutionSucceeded(
      sessionID: json["sessionID"] as String,
    );
  }
}
class V2SessionExecutionFailed extends V2EventData implements V2SessionEventData {
  const V2SessionExecutionFailed({
    required this.sessionID,
    required this.error,
  });

  final String sessionID;
  final SessionStructuredError error;

  @override
  String get type => "session.execution.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "error": error.toJson(),
  };

  factory V2SessionExecutionFailed.fromJson(Map<String, dynamic> json) {
    return V2SessionExecutionFailed(
      sessionID: json["sessionID"] as String,
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
    );
  }
}
class V2SessionExecutionInterrupted extends V2EventData implements V2SessionEventData {
  const V2SessionExecutionInterrupted({
    required this.sessionID,
    required this.reason,
  });

  final String sessionID;
  final V2ExecutionInterruptReason reason;

  @override
  String get type => "session.execution.interrupted";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "reason": reason.toJson(),
  };

  factory V2SessionExecutionInterrupted.fromJson(Map<String, dynamic> json) {
    return V2SessionExecutionInterrupted(
      sessionID: json["sessionID"] as String,
      reason: V2ExecutionInterruptReason.fromJson(json["reason"] as String),
    );
  }
}
class V2SessionInboxEnqueued extends V2EventData implements V2SessionEventData {
  const V2SessionInboxEnqueued({
    required this.sessionID,
    required this.inboxID,
  });

  final String sessionID;
  final String inboxID;

  @override
  String get type => "session.inbox.enqueued";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "inboxID": inboxID,
  };

  factory V2SessionInboxEnqueued.fromJson(Map<String, dynamic> json) {
    return V2SessionInboxEnqueued(
      sessionID: json["sessionID"] as String,
      inboxID: json["inboxID"] as String,
    );
  }
}
class V2SessionInboxDelivered extends V2EventData implements V2SessionEventData {
  const V2SessionInboxDelivered({
    required this.sessionID,
    required this.inboxID,
  });

  final String sessionID;
  final String inboxID;

  @override
  String get type => "session.inbox.delivered";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "inboxID": inboxID,
  };

  factory V2SessionInboxDelivered.fromJson(Map<String, dynamic> json) {
    return V2SessionInboxDelivered(
      sessionID: json["sessionID"] as String,
      inboxID: json["inboxID"] as String,
    );
  }
}
class V2SessionInboxCancelled extends V2EventData implements V2SessionEventData {
  const V2SessionInboxCancelled({
    required this.sessionID,
    required this.inboxID,
  });

  final String sessionID;
  final String inboxID;

  @override
  String get type => "session.inbox.cancelled";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "inboxID": inboxID,
  };

  factory V2SessionInboxCancelled.fromJson(Map<String, dynamic> json) {
    return V2SessionInboxCancelled(
      sessionID: json["sessionID"] as String,
      inboxID: json["inboxID"] as String,
    );
  }
}
class V2SessionInboxDeliveryChanged extends V2EventData implements V2SessionEventData {
  const V2SessionInboxDeliveryChanged({
    required this.sessionID,
    required this.inboxID,
  });

  final String sessionID;
  final String inboxID;

  @override
  String get type => "session.inbox.delivery.changed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "inboxID": inboxID,
  };

  factory V2SessionInboxDeliveryChanged.fromJson(Map<String, dynamic> json) {
    return V2SessionInboxDeliveryChanged(
      sessionID: json["sessionID"] as String,
      inboxID: json["inboxID"] as String,
    );
  }
}
class V2SessionAgentSelected extends V2EventData implements V2SessionEventData {
  const V2SessionAgentSelected({
    required this.sessionID,
    required this.agent,
    this.previous,
  });

  final String sessionID;
  final String agent;
  final String? previous;

  @override
  String get type => "session.agent.selected";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "agent": agent,
    "previous": previous,
  };

  factory V2SessionAgentSelected.fromJson(Map<String, dynamic> json) {
    return V2SessionAgentSelected(
      sessionID: json["sessionID"] as String,
      agent: json["agent"] as String,
      previous: json["previous"] == null ? null : json["previous"] as String,
    );
  }
}
class V2SessionSynthetic extends V2EventData implements V2SessionEventData {
  const V2SessionSynthetic({
    required this.sessionID,
    required this.text,
    this.description,
  });

  final String sessionID;
  final String text;
  final String? description;

  @override
  String get type => "session.synthetic";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "text": text,
    "description": description,
  };

  factory V2SessionSynthetic.fromJson(Map<String, dynamic> json) {
    return V2SessionSynthetic(
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
      description: json["description"] == null ? null : json["description"] as String,
    );
  }
}
class V2SessionStepStarted extends V2EventData implements V2SessionEventData {
  const V2SessionStepStarted({
    required this.sessionID,
    required this.assistantMessageID,
    required this.agent,
    required this.model,
    required this.started,
  });

  final String sessionID;
  final String assistantMessageID;
  final String agent;
  final ModelRef model;
  final int started;

  @override
  String get type => "session.step.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "agent": agent,
    "model": model.toJson(),
    "started": started,
  };

  factory V2SessionStepStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionStepStarted(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      agent: json["agent"] as String,
      model: ModelRef.fromJson(json["model"] as Map<String, dynamic>),
      started: (json["started"] as num).toInt(),
    );
  }
}
class V2SessionStepEnded extends V2EventData implements V2SessionEventData {
  const V2SessionStepEnded({
    required this.sessionID,
    required this.assistantMessageID,
    required this.cost,
    required this.tokens,
  });

  final String sessionID;
  final String assistantMessageID;
  final double cost;
  final TokenUsageInfo tokens;

  @override
  String get type => "session.step.ended";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "cost": cost,
    "tokens": tokens.toJson(),
  };

  factory V2SessionStepEnded.fromJson(Map<String, dynamic> json) {
    return V2SessionStepEnded(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      cost: (json["cost"] as num).toDouble(),
      tokens: TokenUsageInfo.fromJson(json["tokens"] as Map<String, dynamic>),
    );
  }
}
class V2SessionStepFailed extends V2EventData implements V2SessionEventData {
  const V2SessionStepFailed({
    required this.sessionID,
    required this.assistantMessageID,
    required this.error,
    this.cost,
    this.tokens,
  });

  final String sessionID;
  final String assistantMessageID;
  final SessionStructuredError error;
  final double? cost;
  final TokenUsageInfo? tokens;

  @override
  String get type => "session.step.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "error": error.toJson(),
    "cost": cost,
    "tokens": tokens?.toJson(),
  };

  factory V2SessionStepFailed.fromJson(Map<String, dynamic> json) {
    return V2SessionStepFailed(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      cost: json["cost"] == null ? null : (json["cost"] as num).toDouble(),
      tokens: json["tokens"] == null ? null : TokenUsageInfo.fromJson(json["tokens"] as Map<String, dynamic>),
    );
  }
}
class V2SessionTextStarted extends V2EventData implements V2SessionEventData {
  const V2SessionTextStarted({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;

  @override
  String get type => "session.text.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
  };

  factory V2SessionTextStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionTextStarted(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
    );
  }
}
class V2SessionTextDelta extends V2EventData implements V2SessionEventData {
  const V2SessionTextDelta({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
    required this.delta,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;
  final String delta;

  @override
  String get type => "session.text.delta";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
    "delta": delta,
  };

  factory V2SessionTextDelta.fromJson(Map<String, dynamic> json) {
    return V2SessionTextDelta(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
      delta: json["delta"] as String,
    );
  }
}
class V2SessionTextEnded extends V2EventData implements V2SessionEventData {
  const V2SessionTextEnded({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
    required this.text,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;
  final String text;

  @override
  String get type => "session.text.ended";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
    "text": text,
  };

  factory V2SessionTextEnded.fromJson(Map<String, dynamic> json) {
    return V2SessionTextEnded(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
      text: json["text"] as String,
    );
  }
}
class V2SessionReasoningStarted extends V2EventData implements V2SessionEventData {
  const V2SessionReasoningStarted({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;

  @override
  String get type => "session.reasoning.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
  };

  factory V2SessionReasoningStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionReasoningStarted(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
    );
  }
}
class V2SessionReasoningDelta extends V2EventData implements V2SessionEventData {
  const V2SessionReasoningDelta({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
    required this.delta,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;
  final String delta;

  @override
  String get type => "session.reasoning.delta";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
    "delta": delta,
  };

  factory V2SessionReasoningDelta.fromJson(Map<String, dynamic> json) {
    return V2SessionReasoningDelta(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
      delta: json["delta"] as String,
    );
  }
}
class V2SessionReasoningEnded extends V2EventData implements V2SessionEventData {
  const V2SessionReasoningEnded({
    required this.sessionID,
    required this.assistantMessageID,
    required this.ordinal,
    required this.text,
  });

  final String sessionID;
  final String assistantMessageID;
  final int ordinal;
  final String text;

  @override
  String get type => "session.reasoning.ended";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "ordinal": ordinal,
    "text": text,
  };

  factory V2SessionReasoningEnded.fromJson(Map<String, dynamic> json) {
    return V2SessionReasoningEnded(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      ordinal: (json["ordinal"] as num).toInt(),
      text: json["text"] as String,
    );
  }
}
class V2SessionToolInputStarted extends V2EventData implements V2SessionEventData {
  const V2SessionToolInputStarted({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.name,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final String name;

  @override
  String get type => "session.tool.input.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "name": name,
  };

  factory V2SessionToolInputStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionToolInputStarted(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      name: json["name"] as String,
    );
  }
}
class V2SessionToolInputDelta extends V2EventData implements V2SessionEventData {
  const V2SessionToolInputDelta({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.delta,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final String delta;

  @override
  String get type => "session.tool.input.delta";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "delta": delta,
  };

  factory V2SessionToolInputDelta.fromJson(Map<String, dynamic> json) {
    return V2SessionToolInputDelta(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      delta: json["delta"] as String,
    );
  }
}
class V2SessionToolInputEnded extends V2EventData implements V2SessionEventData {
  const V2SessionToolInputEnded({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.text,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final String text;

  @override
  String get type => "session.tool.input.ended";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "text": text,
  };

  factory V2SessionToolInputEnded.fromJson(Map<String, dynamic> json) {
    return V2SessionToolInputEnded(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      text: json["text"] as String,
    );
  }
}
class V2SessionToolCalled extends V2EventData implements V2SessionEventData {
  const V2SessionToolCalled({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.input,
    required this.executed,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final Map<String, dynamic> input;
  final bool executed;

  @override
  String get type => "session.tool.called";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "input": input,
    "executed": executed,
  };

  factory V2SessionToolCalled.fromJson(Map<String, dynamic> json) {
    return V2SessionToolCalled(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      input: json["input"] as Map<String, dynamic>,
      executed: json["executed"] as bool,
    );
  }
}
class V2SessionToolProgress extends V2EventData implements V2SessionEventData {
  const V2SessionToolProgress({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.metadata,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final Map<String, dynamic> metadata;

  @override
  String get type => "session.tool.progress";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "metadata": metadata,
  };

  factory V2SessionToolProgress.fromJson(Map<String, dynamic> json) {
    return V2SessionToolProgress(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>,
    );
  }
}
class V2SessionToolSuccess extends V2EventData implements V2SessionEventData {
  const V2SessionToolSuccess({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.content,
    this.metadata,
    required this.executed,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final List<ToolContent> content;
  final Map<String, dynamic>? metadata;
  final bool executed;

  @override
  String get type => "session.tool.success";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "content": content.map((e) => e.toJson()).toList(),
    "metadata": metadata,
    "executed": executed,
  };

  factory V2SessionToolSuccess.fromJson(Map<String, dynamic> json) {
    return V2SessionToolSuccess(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      content: (json["content"] as List<dynamic>).map((e) => ToolContent.fromJson(e as Map<String, dynamic>)).toList(),
      metadata: json["metadata"] == null ? null : json["metadata"] as Map<String, dynamic>,
      executed: json["executed"] as bool,
    );
  }
}
class V2SessionToolFailed extends V2EventData implements V2SessionEventData {
  const V2SessionToolFailed({
    required this.sessionID,
    required this.assistantMessageID,
    required this.id,
    required this.error,
    this.content,
    this.metadata,
    required this.executed,
  });

  final String sessionID;
  final String assistantMessageID;
  final String id;
  final SessionStructuredError error;
  final List<ToolContent>? content;
  final Map<String, dynamic>? metadata;
  final bool executed;

  @override
  String get type => "session.tool.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "id": id,
    "error": error.toJson(),
    "content": content?.map((e) => e.toJson()).toList(),
    "metadata": metadata,
    "executed": executed,
  };

  factory V2SessionToolFailed.fromJson(Map<String, dynamic> json) {
    return V2SessionToolFailed(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      id: json["id"] as String,
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      content: json["content"] == null ? null : (json["content"] as List<dynamic>).map((e) => ToolContent.fromJson(e as Map<String, dynamic>)).toList(),
      metadata: json["metadata"] == null ? null : json["metadata"] as Map<String, dynamic>,
      executed: json["executed"] as bool,
    );
  }
}
class V2SessionRetryScheduled extends V2EventData implements V2SessionEventData {
  const V2SessionRetryScheduled({
    required this.sessionID,
    required this.assistantMessageID,
    required this.attempt,
    required this.at,
    required this.error,
  });

  final String sessionID;
  final String assistantMessageID;
  final int attempt;
  final int at;
  final SessionStructuredError error;

  @override
  String get type => "session.retry.scheduled";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "assistantMessageID": assistantMessageID,
    "attempt": attempt,
    "at": at,
    "error": error.toJson(),
  };

  factory V2SessionRetryScheduled.fromJson(Map<String, dynamic> json) {
    return V2SessionRetryScheduled(
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      attempt: (json["attempt"] as num).toInt(),
      at: (json["at"] as num).toInt(),
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
    );
  }
}
class V2SessionCompactionStarted extends V2EventData implements V2SessionEventData {
  const V2SessionCompactionStarted({
    required this.sessionID,
    this.inputID,
  });

  final String sessionID;
  final String? inputID;

  @override
  String get type => "session.compaction.started";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "inputID": inputID,
  };

  factory V2SessionCompactionStarted.fromJson(Map<String, dynamic> json) {
    return V2SessionCompactionStarted(
      sessionID: json["sessionID"] as String,
      inputID: json["inputID"] == null ? null : json["inputID"] as String,
    );
  }
}
class V2SessionCompactionDelta extends V2EventData implements V2SessionEventData {
  const V2SessionCompactionDelta({
    required this.sessionID,
    required this.text,
  });

  final String sessionID;
  final String text;

  @override
  String get type => "session.compaction.delta";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "text": text,
  };

  factory V2SessionCompactionDelta.fromJson(Map<String, dynamic> json) {
    return V2SessionCompactionDelta(
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
    );
  }
}
class V2SessionCompactionEnded extends V2EventData implements V2SessionEventData {
  const V2SessionCompactionEnded({
    required this.sessionID,
    required this.text,
    required this.recent,
  });

  final String sessionID;
  final String text;
  final String recent;

  @override
  String get type => "session.compaction.ended";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "text": text,
    "recent": recent,
  };

  factory V2SessionCompactionEnded.fromJson(Map<String, dynamic> json) {
    return V2SessionCompactionEnded(
      sessionID: json["sessionID"] as String,
      text: json["text"] as String,
      recent: json["recent"] as String,
    );
  }
}
class V2SessionCompactionFailed extends V2EventData implements V2SessionEventData {
  const V2SessionCompactionFailed({
    required this.sessionID,
    required this.error,
    this.inputID,
  });

  final String sessionID;
  final SessionStructuredError error;
  final String? inputID;

  @override
  String get type => "session.compaction.failed";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "error": error.toJson(),
    "inputID": inputID,
  };

  factory V2SessionCompactionFailed.fromJson(Map<String, dynamic> json) {
    return V2SessionCompactionFailed(
      sessionID: json["sessionID"] as String,
      error: SessionStructuredError.fromJson(json["error"] as Map<String, dynamic>),
      inputID: json["inputID"] == null ? null : json["inputID"] as String,
    );
  }
}
class V2PermissionAsked extends V2EventData implements V2SessionEventData {
  const V2PermissionAsked({
    required this.id,
    required this.sessionID,
    required this.action,
    required this.resources,
    this.save,
    this.metadata,
    this.source,
    this.message,
  });

  final String id;
  final String sessionID;
  final String action;
  final List<String> resources;
  final List<String>? save;
  final Map<String, dynamic>? metadata;
  final PermissionSource? source;
  final String? message;

  @override
  String get type => "permission.asked";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "sessionID": sessionID,
    "action": action,
    "resources": resources,
    "save": save,
    "metadata": metadata,
    "source": source?.toJson(),
    "message": message,
  };

  factory V2PermissionAsked.fromJson(Map<String, dynamic> json) {
    return V2PermissionAsked(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      action: json["action"] as String,
      resources: (json["resources"] as List<dynamic>).cast<String>(),
      save: json["save"] == null ? null : ((json["save"] as List<dynamic>).cast<String>()),
      metadata: json["metadata"] == null ? null : json["metadata"] as Map<String, dynamic>,
      source: json["source"] == null ? null : PermissionSource.fromJson(json["source"] as Map<String, dynamic>),
      message: json["message"] == null ? null : json["message"] as String,
    );
  }
}
class V2PermissionReplied extends V2EventData implements V2SessionEventData {
  const V2PermissionReplied({
    required this.sessionID,
    required this.requestID,
    required this.reply,
  });

  final String sessionID;
  final String requestID;
  final PermissionReply reply;

  @override
  String get type => "permission.replied";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "sessionID": sessionID,
    "requestID": requestID,
    "reply": reply.toJson(),
  };

  factory V2PermissionReplied.fromJson(Map<String, dynamic> json) {
    return V2PermissionReplied(
      sessionID: json["sessionID"] as String,
      requestID: json["requestID"] as String,
      reply: PermissionReply.fromJson(json["reply"] as String),
    );
  }
}
class V2FormCreated extends V2EventData implements V2SessionEventData {
  const V2FormCreated({
    required this.form,
  });

  final FormInfo form;

  @override
  String get type => "form.created";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "form": form.toJson(),
  };

  factory V2FormCreated.fromJson(Map<String, dynamic> json) {
    return V2FormCreated(
      form: FormInfo.fromJson(json["form"] as Map<String, dynamic>),
    );
  }
}
class V2FormReplied extends V2EventData implements V2SessionEventData {
  const V2FormReplied({
    required this.id,
    required this.sessionID,
    required this.answer,
  });

  final String id;
  final String sessionID;
  final FormAnswer answer;

  @override
  String get type => "form.replied";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "sessionID": sessionID,
    "answer": answer.toJson(),
  };

  factory V2FormReplied.fromJson(Map<String, dynamic> json) {
    return V2FormReplied(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
      answer: FormAnswer.fromJson(json["answer"] as Map<String, dynamic>),
    );
  }
}
class V2FormCancelled extends V2EventData implements V2SessionEventData {
  const V2FormCancelled({
    required this.id,
    required this.sessionID,
  });

  final String id;
  final String sessionID;

  @override
  String get type => "form.cancelled";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "sessionID": sessionID,
  };

  factory V2FormCancelled.fromJson(Map<String, dynamic> json) {
    return V2FormCancelled(
      id: json["id"] as String,
      sessionID: json["sessionID"] as String,
    );
  }
}
class V2ProjectUpdated extends V2EventData {
  const V2ProjectUpdated({
    required this.id,
    required this.canonical,
    this.vcs,
    this.name,
    this.icon,
    required this.time,
    required this.sandboxes,
  });

  final String id;
  final String canonical;
  final String? vcs;
  final String? name;
  final ProjectIcon? icon;
  final ProjectTime time;
  final List<String> sandboxes;

  @override
  String get type => "project.updated";

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    "type": type,
    "id": id,
    "canonical": canonical,
    "vcs": vcs,
    "name": name,
    "icon": icon?.toJson(),
    "time": time.toJson(),
    "sandboxes": sandboxes,
  };

  factory V2ProjectUpdated.fromJson(Map<String, dynamic> json) {
    return V2ProjectUpdated(
      id: json["id"] as String,
      canonical: json["canonical"] as String,
      vcs: json["vcs"] == null ? null : json["vcs"] as String,
      name: json["name"] == null ? null : json["name"] as String,
      icon: json["icon"] == null ? null : ProjectIcon.fromJson(json["icon"] as Map<String, dynamic>),
      time: ProjectTime.fromJson(json["time"] as Map<String, dynamic>),
      sandboxes: (json["sandboxes"] as List<dynamic>).cast<String>(),
    );
  }
}
class V2EventEnvelope {
  const V2EventEnvelope({
    required this.id,
    required this.created,
    required this.location,
    required this.data,
  });
  final String id;
  final double created;
  final LocationPublicRef? location;
  final V2EventData data;
  factory V2EventEnvelope.fromJson(Map<String, dynamic> json) {
    return V2EventEnvelope(
      id: json["id"] as String,
      created: (json["created"] as num).toDouble(),
      location: json["location"] == null ? null : LocationPublicRef.fromJson(json["location"] as Map<String, dynamic>),
      data: V2EventData.fromJson({...json["data"] as Map<String, dynamic>, "type": json["type"]}),
    );
  }
}
