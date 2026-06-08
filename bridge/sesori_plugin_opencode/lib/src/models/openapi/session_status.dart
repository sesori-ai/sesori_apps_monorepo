// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T09:42:34.355557Z


abstract interface class SessionStatus {
  const SessionStatus();

  /// Serialize the underlying variant. Variants must override this.
  ///
  /// The return type is `dynamic` (not `Map<String, dynamic>`)
  /// because some unions are string-or-object and the string
  /// variant encodes as the scalar itself, not a wrapped map.
  /// Callers pass the result straight to `jsonEncode` or
  /// another `toJson()`, both of which accept `dynamic`.
  dynamic toJson();

  factory SessionStatus.fromJson(dynamic json) {
    final map = json as Map<String, dynamic>;
    final discriminator = map["type"];
    switch (discriminator) {
      case "idle":
        return sessionStatus00Inline.fromJson(map);
      case "retry":
        return sessionStatus01Inline.fromJson(map);
      case "busy":
        return sessionStatus02Inline.fromJson(map);
      default:
        throw FormatException('Unknown SessionStatus value: $discriminator');
    }
  }
}

class sessionStatus00Inline implements SessionStatus {
  const sessionStatus00Inline();

  // ignore: avoid_unused_constructor_parameters
  factory sessionStatus00Inline.fromJson(Map<String, dynamic> json) {
    return const sessionStatus00Inline();
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{};
  }

}


class sessionStatus01Inline implements SessionStatus {
  const sessionStatus01Inline({
    required this.attempt,
    required this.message,
    this.action,
    required this.next,
  });

  factory sessionStatus01Inline.fromJson(Map<String, dynamic> json) {
    return sessionStatus01Inline(
      attempt: json["attempt"] as int,
      message: json["message"] as String,
      action: json["action"] as Map<String, dynamic>?,
      next: json["next"] as int,
    );
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{
      "type": "retry",
      "attempt": attempt,
      "message": message,
      "action": ?action,
      "next": next,
    };
  }

  final int attempt;
  final String message;
  final Map<String, dynamic>? action;
  final int next;
}


class sessionStatus02Inline implements SessionStatus {
  const sessionStatus02Inline();

  // ignore: avoid_unused_constructor_parameters
  factory sessionStatus02Inline.fromJson(Map<String, dynamic> json) {
    return const sessionStatus02Inline();
  }

  @override
  dynamic toJson() {
    return <String, dynamic>{};
  }

}
