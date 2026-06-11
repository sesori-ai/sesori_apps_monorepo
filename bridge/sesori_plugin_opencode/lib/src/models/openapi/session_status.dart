// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

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
        return SessionStatus00Inline.fromJson(map);
      case "retry":
        return SessionStatus01Inline.fromJson(map);
      case "busy":
        return SessionStatus02Inline.fromJson(map);
      default:
        return SessionStatusUnknown(raw: map);
    }
  }
}

@immutable
class SessionStatus00Inline implements SessionStatus {
  const SessionStatus00Inline();

  // ignore: avoid_unused_constructor_parameters
  factory SessionStatus00Inline.fromJson(Map<String, dynamic> json) {
    return const SessionStatus00Inline();
  }

  @override
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": "idle",
    };
  }

}


@immutable
class SessionStatus01Inline implements SessionStatus {
  const SessionStatus01Inline({
    required this.attempt,
    required this.message,
    this.action,
    required this.next,
  });

  factory SessionStatus01Inline.fromJson(Map<String, dynamic> json) {
    return SessionStatus01Inline(
      attempt: (json["attempt"] as num).toInt(),
      message: json["message"] as String,
      action: json["action"] == null ? null : SessionStatus01InlineAction.fromJson(json["action"] as Map<String, dynamic>),
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStatus01Inline &&
          other.attempt == attempt &&
          other.message == message &&
          other.action == action &&
          other.next == next);

  @override
  int get hashCode => Object.hash(attempt, message, action, next);

  final int attempt;
  final String message;
  final SessionStatus01InlineAction? action;
  final int next;
}


@immutable
class SessionStatus02Inline implements SessionStatus {
  const SessionStatus02Inline();

  // ignore: avoid_unused_constructor_parameters
  factory SessionStatus02Inline.fromJson(Map<String, dynamic> json) {
    return const SessionStatus02Inline();
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
class SessionStatus01InlineAction {
  const SessionStatus01InlineAction({
    required this.reason,
    required this.provider,
    required this.title,
    required this.message,
    required this.label,
    this.link,
  });

  factory SessionStatus01InlineAction.fromJson(Map<String, dynamic> json) {
    return SessionStatus01InlineAction(
      reason: json["reason"] as String,
      provider: json["provider"] as String,
      title: json["title"] as String,
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionStatus01InlineAction &&
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
  final String title;
  final String message;
  final String label;
  final String? link;
}
