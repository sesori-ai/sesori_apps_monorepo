// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v2.0.24 (e7a34f09bfd9134dfade5a8ddb843f7030bc9a69)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
sealed class IntegrationAttemptStatus {
  const IntegrationAttemptStatus();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory IntegrationAttemptStatus.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["status"];
    switch (discriminator) {
      case "pending":
        return IntegrationAttemptStatusPending.fromJson(map);
      case "complete":
        return IntegrationAttemptStatusComplete.fromJson(map);
      case "failed":
        return IntegrationAttemptStatusFailed.fromJson(map);
      case "expired":
        return IntegrationAttemptStatusExpired.fromJson(map);
      default:
        return IntegrationAttemptStatusUnknown(raw: map);
    }
  }
}

@immutable
final class IntegrationAttemptStatusPending implements IntegrationAttemptStatus {
  const IntegrationAttemptStatusPending({
    required this.time,
  });

  factory IntegrationAttemptStatusPending.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusPending(
      time: IntegrationAttemptStatusPendingTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "pending",
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptStatusPending copyWith({
    IntegrationAttemptStatusPendingTime? time,
  }) {
    return IntegrationAttemptStatusPending(
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusPending &&
          other.time == time);

  @override
  int get hashCode => time.hashCode;

  final IntegrationAttemptStatusPendingTime time;
}


@immutable
final class IntegrationAttemptStatusComplete implements IntegrationAttemptStatus {
  const IntegrationAttemptStatusComplete({
    required this.time,
  });

  factory IntegrationAttemptStatusComplete.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusComplete(
      time: IntegrationAttemptStatusCompleteTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "complete",
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptStatusComplete copyWith({
    IntegrationAttemptStatusCompleteTime? time,
  }) {
    return IntegrationAttemptStatusComplete(
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusComplete &&
          other.time == time);

  @override
  int get hashCode => time.hashCode;

  final IntegrationAttemptStatusCompleteTime time;
}


@immutable
final class IntegrationAttemptStatusFailed implements IntegrationAttemptStatus {
  const IntegrationAttemptStatusFailed({
    required this.message,
    required this.time,
  });

  factory IntegrationAttemptStatusFailed.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusFailed(
      message: json["message"] as String,
      time: IntegrationAttemptStatusFailedTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "failed",
      "message": message,
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptStatusFailed copyWith({
    String? message,
    IntegrationAttemptStatusFailedTime? time,
  }) {
    return IntegrationAttemptStatusFailed(
      message: message ?? this.message,
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusFailed &&
          other.message == message &&
          other.time == time);

  @override
  int get hashCode => Object.hash(message, time);

  final String message;
  final IntegrationAttemptStatusFailedTime time;
}


@immutable
final class IntegrationAttemptStatusExpired implements IntegrationAttemptStatus {
  const IntegrationAttemptStatusExpired({
    required this.time,
  });

  factory IntegrationAttemptStatusExpired.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusExpired(
      time: IntegrationAttemptStatusExpiredTime.fromJson(json["time"] as Map<String, dynamic>),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": "expired",
      "time": time.toJson(),
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  IntegrationAttemptStatusExpired copyWith({
    IntegrationAttemptStatusExpiredTime? time,
  }) {
    return IntegrationAttemptStatusExpired(
      time: time ?? this.time,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusExpired &&
          other.time == time);

  @override
  int get hashCode => time.hashCode;

  final IntegrationAttemptStatusExpiredTime time;
}


/// Fallback variant for an unrecognized [IntegrationAttemptStatus] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
final class IntegrationAttemptStatusUnknown implements IntegrationAttemptStatus {
  const IntegrationAttemptStatusUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

@immutable
class IntegrationAttemptStatusPendingTime {
  const IntegrationAttemptStatusPendingTime({
    required this.created,
    required this.expires,
  });

  factory IntegrationAttemptStatusPendingTime.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusPendingTime(
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
  IntegrationAttemptStatusPendingTime copyWith({
    Object? created,
    Object? expires,
  }) {
    return IntegrationAttemptStatusPendingTime(
      created: created ?? this.created,
      expires: expires ?? this.expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusPendingTime &&
          const DeepCollectionEquality().equals(other.created, created) &&
          const DeepCollectionEquality().equals(other.expires, expires));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(created), const DeepCollectionEquality().hash(expires));

  final Object created;
  final Object expires;
}

@immutable
class IntegrationAttemptStatusCompleteTime {
  const IntegrationAttemptStatusCompleteTime({
    required this.created,
    required this.expires,
  });

  factory IntegrationAttemptStatusCompleteTime.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusCompleteTime(
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
  IntegrationAttemptStatusCompleteTime copyWith({
    Object? created,
    Object? expires,
  }) {
    return IntegrationAttemptStatusCompleteTime(
      created: created ?? this.created,
      expires: expires ?? this.expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusCompleteTime &&
          const DeepCollectionEquality().equals(other.created, created) &&
          const DeepCollectionEquality().equals(other.expires, expires));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(created), const DeepCollectionEquality().hash(expires));

  final Object created;
  final Object expires;
}

@immutable
class IntegrationAttemptStatusFailedTime {
  const IntegrationAttemptStatusFailedTime({
    required this.created,
    required this.expires,
  });

  factory IntegrationAttemptStatusFailedTime.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusFailedTime(
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
  IntegrationAttemptStatusFailedTime copyWith({
    Object? created,
    Object? expires,
  }) {
    return IntegrationAttemptStatusFailedTime(
      created: created ?? this.created,
      expires: expires ?? this.expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusFailedTime &&
          const DeepCollectionEquality().equals(other.created, created) &&
          const DeepCollectionEquality().equals(other.expires, expires));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(created), const DeepCollectionEquality().hash(expires));

  final Object created;
  final Object expires;
}

@immutable
class IntegrationAttemptStatusExpiredTime {
  const IntegrationAttemptStatusExpiredTime({
    required this.created,
    required this.expires,
  });

  factory IntegrationAttemptStatusExpiredTime.fromJson(Map<String, dynamic> json) {
    return IntegrationAttemptStatusExpiredTime(
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
  IntegrationAttemptStatusExpiredTime copyWith({
    Object? created,
    Object? expires,
  }) {
    return IntegrationAttemptStatusExpiredTime(
      created: created ?? this.created,
      expires: expires ?? this.expires,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IntegrationAttemptStatusExpiredTime &&
          const DeepCollectionEquality().equals(other.created, created) &&
          const DeepCollectionEquality().equals(other.expires, expires));

  @override
  int get hashCode => Object.hash(const DeepCollectionEquality().hash(created), const DeepCollectionEquality().hash(expires));

  final Object created;
  final Object expires;
}
