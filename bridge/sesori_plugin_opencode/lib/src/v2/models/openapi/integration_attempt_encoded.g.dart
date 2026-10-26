// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.1.4 (68bc26b7da1990ce10ffecfbc1e09eb13aa5d824)

import 'package:collection/collection.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

@immutable
class IntegrationAttemptEncoded {
  const IntegrationAttemptEncoded({
    required this.attemptID,
    required this.url,
    required this.instructions,
    required this.mode,
    required this.time,
  });

  factory IntegrationAttemptEncoded.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptEncoded(
      attemptID: json["attemptID"] as String,
      url: json["url"] as String,
      instructions: json["instructions"] as String,
      mode: IntegrationAttemptEncodedMode.fromJson(json["mode"] as String),
      time: IntegrationAttemptEncodedTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "attemptID": attemptID,
      "url": url,
      "instructions": instructions,
      "mode": mode.toJson(),
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptEncoded copyWith({
    String? attemptID,
    String? url,
    String? instructions,
    IntegrationAttemptEncodedMode? mode,
    IntegrationAttemptEncodedTime? time,
  }) {
    return IntegrationAttemptEncoded(
      attemptID: attemptID ?? this.attemptID,
      url: url ?? this.url,
      instructions: instructions ?? this.instructions,
      mode: mode ?? this.mode,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptEncoded &&
          other.attemptID == attemptID &&
          other.url == url &&
          other.instructions == instructions &&
          other.mode == mode &&
          other.time == time);

  @override
  int get hashCode => Object.hash(attemptID, url, instructions, mode, time);

  final String attemptID;
  final String url;
  final String instructions;
  final IntegrationAttemptEncodedMode mode;
  final IntegrationAttemptEncodedTime time;
}

@immutable
class IntegrationAttemptEncodedTime {
  const IntegrationAttemptEncodedTime({
    required this.created,
    required this.expires,
  });

  factory IntegrationAttemptEncodedTime.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptEncodedTime(
      created: json["created"] as Object,
      expires: json["expires"] as Object,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "created": created,
      "expires": expires,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptEncodedTime copyWith({
    Object? created,
    Object? expires,
  }) {
    return IntegrationAttemptEncodedTime(
      created: created ?? this.created,
      expires: expires ?? this.expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptEncodedTime &&
          const DeepCollectionEquality().equals(other.created, created) &&
          const DeepCollectionEquality().equals(other.expires, expires));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(created), const DeepCollectionEquality().hash(expires));

  final Object created;
  final Object expires;
}

enum IntegrationAttemptEncodedMode {
  @JsonValue("auto")
  auto,
  @JsonValue("code")
  code,

  /// Fallback for values introduced by newer OpenCode servers.
  /// Encodes back to the literal string `unknown`.
  unknown,
  ;

  static IntegrationAttemptEncodedMode fromJson(String value) {
    switch (value) {
      case "auto":
        return IntegrationAttemptEncodedMode.auto;
      case "code":
        return IntegrationAttemptEncodedMode.code;
      default:
        return IntegrationAttemptEncodedMode.unknown;
    }
  }

  String toJson() {
    switch (this) {
      case IntegrationAttemptEncodedMode.auto:
        return "auto";
      case IntegrationAttemptEncodedMode.code:
        return "code";
      case IntegrationAttemptEncodedMode.unknown:
        return 'unknown';
    }
  }
}
