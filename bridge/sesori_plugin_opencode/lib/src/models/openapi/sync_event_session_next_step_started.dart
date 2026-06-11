// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextStepStarted {
  const SyncEventSessionNextStepStarted({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextStepStarted.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepStarted(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextStepStartedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepStarted &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextStepStartedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextStepStartedSyncEvent {
  const SyncEventSessionNextStepStartedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextStepStartedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepStartedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextStepStartedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepStartedSyncEvent &&
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
  final SyncEventSessionNextStepStartedSyncEventData data;
}

@immutable
class SyncEventSessionNextStepStartedSyncEventData {
  const SyncEventSessionNextStepStartedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.agent,
    required this.model,
    this.snapshot,
  });

  factory SyncEventSessionNextStepStartedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepStartedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      agent: json["agent"] as String,
      model: SyncEventSessionNextStepStartedSyncEventDataModel.fromJson(json["model"] as Map<String, dynamic>),
      snapshot: json["snapshot"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "agent": agent,
      "model": model.toJson(),
      "snapshot": ?snapshot,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepStartedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.agent == agent &&
          other.model == model &&
          other.snapshot == snapshot);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, agent, model, snapshot);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String agent;
  final SyncEventSessionNextStepStartedSyncEventDataModel model;
  final String? snapshot;
}

@immutable
class SyncEventSessionNextStepStartedSyncEventDataModel {
  const SyncEventSessionNextStepStartedSyncEventDataModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory SyncEventSessionNextStepStartedSyncEventDataModel.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepStartedSyncEventDataModel(
      id: json["id"] as String,
      providerID: json["providerID"] as String,
      variant: json["variant"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "providerID": providerID,
      "variant": ?variant,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepStartedSyncEventDataModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}
