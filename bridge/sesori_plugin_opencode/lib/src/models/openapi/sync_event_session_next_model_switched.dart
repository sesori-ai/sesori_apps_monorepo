// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextModelSwitched {
  const SyncEventSessionNextModelSwitched({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextModelSwitched.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextModelSwitched(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextModelSwitchedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextModelSwitched &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextModelSwitchedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextModelSwitchedSyncEvent {
  const SyncEventSessionNextModelSwitchedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextModelSwitchedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextModelSwitchedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextModelSwitchedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextModelSwitchedSyncEvent &&
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
  final SyncEventSessionNextModelSwitchedSyncEventData data;
}

@immutable
class SyncEventSessionNextModelSwitchedSyncEventData {
  const SyncEventSessionNextModelSwitchedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.messageID,
    required this.model,
  });

  factory SyncEventSessionNextModelSwitchedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextModelSwitchedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      messageID: json["messageID"] as String,
      model: SyncEventSessionNextModelSwitchedSyncEventDataModel.fromJson(json["model"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "messageID": messageID,
      "model": model.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextModelSwitchedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.messageID == messageID &&
          other.model == model);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, messageID, model);

  final double timestamp;
  final String sessionID;
  final String messageID;
  final SyncEventSessionNextModelSwitchedSyncEventDataModel model;
}

@immutable
class SyncEventSessionNextModelSwitchedSyncEventDataModel {
  const SyncEventSessionNextModelSwitchedSyncEventDataModel({
    required this.id,
    required this.providerID,
    this.variant,
  });

  factory SyncEventSessionNextModelSwitchedSyncEventDataModel.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextModelSwitchedSyncEventDataModel(
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
      (other is SyncEventSessionNextModelSwitchedSyncEventDataModel &&
          other.id == id &&
          other.providerID == providerID &&
          other.variant == variant);

  @override
  int get hashCode => Object.hash(id, providerID, variant);

  final String id;
  final String providerID;
  final String? variant;
}
