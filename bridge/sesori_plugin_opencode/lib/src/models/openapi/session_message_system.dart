// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'session_message.dart';

@immutable
class SessionMessageSystem implements SessionMessage {
  const SessionMessageSystem({
    required this.id,
    this.metadata,
    required this.time,
    required this.text,
  });

  factory SessionMessageSystem.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystem(
      id: json["id"] as String,
      metadata: json["metadata"] as Map<String, dynamic>?,
      time: SessionMessageSystemTime.fromJson(json["time"] as Map<String, dynamic>),
      text: json["text"] as String,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "id": id,
      "metadata": ?metadata,
      "time": time.toJson(),
      "type": "system",
      "text": text,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSystem &&
          other.id == id &&
          const DeepCollectionEquality().equals(other.metadata, metadata) &&
          other.time == time &&
          other.text == text);

  @override
  int get hashCode => Object.hash(id, const DeepCollectionEquality().hash(metadata), time, text);

  final String id;
  final Map<String, dynamic>? metadata;
  final SessionMessageSystemTime time;
  final String text;
}

@immutable
class SessionMessageSystemTime {
  const SessionMessageSystemTime({
    required this.created,
  });

  factory SessionMessageSystemTime.fromJson(Map<String, dynamic> json) {
    return SessionMessageSystemTime(
      created: (json["created"] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageSystemTime &&
          other.created == created);

  @override
  int get hashCode => created.hashCode;

  final double created;
}
