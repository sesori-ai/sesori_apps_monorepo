// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextToolProgress {
  const SyncEventSessionNextToolProgress({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextToolProgress.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolProgress(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextToolProgressSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "syncEvent": syncEvent.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolProgress &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextToolProgressSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextToolProgressSyncEvent {
  const SyncEventSessionNextToolProgressSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextToolProgressSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolProgressSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextToolProgressSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "id": id,
      "seq": seq,
      "aggregateID": aggregateID,
      "data": data.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolProgressSyncEvent &&
          other.type == type &&
          other.id == id &&
          other.seq == seq &&
          other.aggregateID == aggregateID &&
          other.data == data);

  @override
  int get hashCode => Object.hash(type, id, seq, aggregateID, data);

  final String type;
  final String id;
  final double seq;
  final String aggregateID;
  final SyncEventSessionNextToolProgressSyncEventData data;
}

@immutable
class SyncEventSessionNextToolProgressSyncEventData {
  const SyncEventSessionNextToolProgressSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.callID,
    required this.structured,
    required this.content,
  });

  factory SyncEventSessionNextToolProgressSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextToolProgressSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      callID: json["callID"] as String,
      structured: json["structured"] as Map<String, dynamic>,
      content: (json["content"] as List<dynamic>).cast<Object>(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "callID": callID,
      "structured": structured,
      "content": content,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextToolProgressSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.callID == callID &&
          const DeepCollectionEquality().equals(other.structured, structured) &&
          const DeepCollectionEquality().equals(other.content, content));

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, callID, const DeepCollectionEquality().hash(structured), const DeepCollectionEquality().hash(content));

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String callID;
  final Map<String, dynamic> structured;
  final List<Object> content;
}
