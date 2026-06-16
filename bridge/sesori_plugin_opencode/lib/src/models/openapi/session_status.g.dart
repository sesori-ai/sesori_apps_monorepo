// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.17.3 (8c8011336163d7e7fb24a6a4a049cdb1f6e6ee74)

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

@immutable
abstract interface class SessionStatus {
  const SessionStatus();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `Object?` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `Object?`.
  Object? toJson();

  factory SessionStatus.fromJson(Object json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "idle":
        return SessionStatusIdle.fromJson(map);
      case "retry":
        return SessionStatusRetry.fromJson(map);
      case "busy":
        return SessionStatusBusy.fromJson(map);
      default:
        return SessionStatusUnknown(raw: map);
    }
  }
}

@immutable
class SessionStatusIdle implements SessionStatus {
  const SessionStatusIdle();

  // ignore: avoid_unused_constructor_parameters
  factory SessionStatusIdle.fromJson(Map<String, dynamic> json) {
    return const SessionStatusIdle();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "idle",
    };
  }

}


@immutable
class SessionStatusRetry implements SessionStatus {
  const SessionStatusRetry({
    required this.attempt,
    required this.message,
    required this.action,
    required this.next,
  });

  factory SessionStatusRetry.fromJson(Map<String, dynamic> json) {
    return SessionStatusRetry(
      attempt: (json["attempt"] as num).toInt(),
      message: json["message"] as String,
      action: json["action"] == null ? null : SessionStatusRetryAction.fromJson(json["action"] as Map<String, dynamic>),
      next: (json["next"] as num).toInt(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "retry",
      "attempt": attempt,
      "message": message,
      "action": ?action?.toJson(),
      "next": next,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionStatusRetry copyWith({
    int? attempt,
    String? message,
    SessionStatusRetryAction? action,
    int? next,
  }) {
    return SessionStatusRetry(
      attempt: attempt ?? this.attempt,
      message: message ?? this.message,
      action: action ?? this.action,
      next: next ?? this.next,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStatusRetry &&
          other.attempt == attempt &&
          other.message == message &&
          other.action == action &&
          other.next == next);

  @override
  int get hashCode => Object.hash(attempt, message, action, next);

  final int attempt;
  final String message;
  final SessionStatusRetryAction? action;
  final int next;
}


@immutable
class SessionStatusBusy implements SessionStatus {
  const SessionStatusBusy();

  // ignore: avoid_unused_constructor_parameters
  factory SessionStatusBusy.fromJson(Map<String, dynamic> json) {
    return const SessionStatusBusy();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "busy",
    };
  }

}


/// Fallback variant for an unrecognized [SessionStatus] payload shape.
/// Carries the raw JSON so newer OpenCode servers do not break
/// decoding; `toJson` returns the payload unchanged.
@immutable
class SessionStatusUnknown implements SessionStatus {
  const SessionStatusUnknown({required this.raw});

  final Object? raw;

  @override
  Object? toJson() => raw;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStatusUnknown &&
          const DeepCollectionEquality().equals(other.raw, raw));

  @override
  int get hashCode => const DeepCollectionEquality().hash(raw);
}

@immutable
class SessionStatusRetryAction {
  const SessionStatusRetryAction({
    required this.reason,
    required this.provider,
    required this.title,
    required this.message,
    required this.label,
    required this.link,
  });

  factory SessionStatusRetryAction.fromJson(Map<String, dynamic> json) {
    return SessionStatusRetryAction(
      reason: json["reason"] as String,
      provider: json["provider"] as String,
      title: json["title"] as String?,
      message: json["message"] as String,
      label: json["label"] as String,
      link: json["link"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "reason": reason,
      "provider": provider,
      "title": title,
      "message": message,
      "label": label,
      "link": ?link,
    };
  }

  /// Returns a copy with non-null arguments replacing existing values.
  /// Nullable fields cannot be set to null through this helper; null means keep.
  SessionStatusRetryAction copyWith({
    String? reason,
    String? provider,
    String? title,
    String? message,
    String? label,
    String? link,
  }) {
    return SessionStatusRetryAction(
      reason: reason ?? this.reason,
      provider: provider ?? this.provider,
      title: title ?? this.title,
      message: message ?? this.message,
      label: label ?? this.label,
      link: link ?? this.link,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStatusRetryAction &&
          other.reason == reason &&
          other.provider == provider &&
          other.title == title &&
          other.message == message &&
          other.label == label &&
          other.link == link);

  @override
  int get hashCode => Object.hash(reason, provider, title, message, label, link);

  final String reason;
  final String provider;
  final String? title;
  final String message;
  final String label;
  final String? link;
}
