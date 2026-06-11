// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';
import 'event.dart';

@immutable
class EventSessionNextStepEnded implements Event {
  const EventSessionNextStepEnded({
    required this.id,
    required this.properties,
  });

  factory EventSessionNextStepEnded.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepEnded(
      id: json["id"] as String,
      properties: EventSessionNextStepEndedProperties.fromJson(json["properties"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "type": "session.next.step.ended",
      "properties": properties.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventSessionNextStepEnded &&
          other.id == id &&
          other.properties == properties);

  @override
  int get hashCode => Object.hash(id, properties);

  final String id;
  final EventSessionNextStepEndedProperties properties;
}

@immutable
class EventSessionNextStepEndedProperties {
  const EventSessionNextStepEndedProperties({
    required this.timestamp,
    required this.sessionID,
    required this.assistantMessageID,
    required this.finish,
    required this.cost,
    required this.tokens,
    this.snapshot,
  });

  factory EventSessionNextStepEndedProperties.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepEndedProperties(
      timestamp: (json["timestamp"] as num).toDouble(),
      sessionID: json["sessionID"] as String,
      assistantMessageID: json["assistantMessageID"] as String,
      finish: json["finish"] as String,
      cost: (json["cost"] as num).toDouble(),
      tokens: EventSessionNextStepEndedPropertiesTokens.fromJson(json["tokens"] as Map<String, dynamic>),
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
      (other is EventSessionNextStepEndedProperties &&
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
  final EventSessionNextStepEndedPropertiesTokens tokens;
  final String? snapshot;
}

@immutable
class EventSessionNextStepEndedPropertiesTokens {
  const EventSessionNextStepEndedPropertiesTokens({
    required this.input,
    required this.output,
    required this.reasoning,
    required this.cache,
  });

  factory EventSessionNextStepEndedPropertiesTokens.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepEndedPropertiesTokens(
      input: (json["input"] as num).toDouble(),
      output: (json["output"] as num).toDouble(),
      reasoning: (json["reasoning"] as num).toDouble(),
      cache: EventSessionNextStepEndedPropertiesTokensCache.fromJson(json["cache"] as Map<String, dynamic>),
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
      (other is EventSessionNextStepEndedPropertiesTokens &&
          other.input == input &&
          other.output == output &&
          other.reasoning == reasoning &&
          other.cache == cache);

  @override
  int get hashCode => Object.hash(input, output, reasoning, cache);

  final double input;
  final double output;
  final double reasoning;
  final EventSessionNextStepEndedPropertiesTokensCache cache;
}

@immutable
class EventSessionNextStepEndedPropertiesTokensCache {
  const EventSessionNextStepEndedPropertiesTokensCache({
    required this.read,
    required this.write,
  });

  factory EventSessionNextStepEndedPropertiesTokensCache.fromJson(Map<String, dynamic> json) {
    return EventSessionNextStepEndedPropertiesTokensCache(
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
      (other is EventSessionNextStepEndedPropertiesTokensCache &&
          other.read == read &&
          other.write == write);

  @override
  int get hashCode => Object.hash(read, write);

  final double read;
  final double write;
}
