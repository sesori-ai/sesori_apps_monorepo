// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class SyncEventSessionNextStepEnded {
  const SyncEventSessionNextStepEnded({
    required this.type,
    required this.id,
    required this.syncEvent,
  });

  factory SyncEventSessionNextStepEnded.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepEnded(
      type: json["type"] as String,
      id: json["id"] as String,
      syncEvent: SyncEventSessionNextStepEndedSyncEvent.fromJson(json["syncEvent"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepEnded &&
          other.type == type &&
          other.id == id &&
          other.syncEvent == syncEvent);

  @override
  int get hashCode => Object.hash(type, id, syncEvent);

  final String type;
  final String id;
  final SyncEventSessionNextStepEndedSyncEvent syncEvent;
}

@immutable
class SyncEventSessionNextStepEndedSyncEvent {
  const SyncEventSessionNextStepEndedSyncEvent({
    required this.type,
    required this.id,
    required this.seq,
    required this.aggregateID,
    required this.data,
  });

  factory SyncEventSessionNextStepEndedSyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepEndedSyncEvent(
      type: json["type"] as String,
      id: json["id"] as String,
      seq: (json["seq"] as num).toDouble(),
      aggregateID: json["aggregateID"] as String,
      data: SyncEventSessionNextStepEndedSyncEventData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is SyncEventSessionNextStepEndedSyncEvent &&
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
  final SyncEventSessionNextStepEndedSyncEventData data;
}

@immutable
class SyncEventSessionNextStepEndedSyncEventData {
  const SyncEventSessionNextStepEndedSyncEventData({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.finish,
    required this.cost,
    required this.tokens,
    this.snapshot,
  });

  factory SyncEventSessionNextStepEndedSyncEventData.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepEndedSyncEventData(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      finish: json["finish"] as String,
      cost: (json["cost"] as num).toDouble(),
      tokens: SyncEventSessionNextStepEndedSyncEventDataTokens.fromJson(json["tokens"] as Map<String, dynamic>),
      snapshot: json["snapshot"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "timestamp": timestamp,
      "sessionID": sessionID,
      "assistantMessageID": assistantMessageID,
      "finish": finish,
      "cost": cost,
      "tokens": tokens.toJson(),
      "snapshot": ?snapshot,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepEndedSyncEventData &&
          other.timestamp == timestamp &&
          other.sessionID == sessionID &&
          other.assistantMessageID == assistantMessageID &&
          other.finish == finish &&
          other.cost == cost &&
          other.tokens == tokens &&
          other.snapshot == snapshot);

  @override
  int get hashCode => Object.hash(timestamp, sessionID, assistantMessageID, finish, cost, tokens, snapshot);

  final double timestamp;
  final String sessionID;
  final String assistantMessageID;
  final String finish;
  final double cost;
  final SyncEventSessionNextStepEndedSyncEventDataTokens tokens;
  final String? snapshot;
}

@immutable
class SyncEventSessionNextStepEndedSyncEventDataTokens {
  const SyncEventSessionNextStepEndedSyncEventDataTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory SyncEventSessionNextStepEndedSyncEventDataTokens.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepEndedSyncEventDataTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: SyncEventSessionNextStepEndedSyncEventDataTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "input": input,
      "output": output,
      "reasoning": reasoning,
      "cache": cache.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepEndedSyncEventDataTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final SyncEventSessionNextStepEndedSyncEventDataTokensCache cache;
}

@immutable
class SyncEventSessionNextStepEndedSyncEventDataTokensCache {
  const SyncEventSessionNextStepEndedSyncEventDataTokensCache({
    required this.read,
    required this.write,
  });

  factory SyncEventSessionNextStepEndedSyncEventDataTokensCache.fromJson(Map<String, dynamic> json) {
    return SyncEventSessionNextStepEndedSyncEventDataTokensCache(
      read: (json["read"] as num).toDouble(),
      write: (json["write"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "read": read,
      "write": write,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncEventSessionNextStepEndedSyncEventDataTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
