// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.958483Z

import 'package:meta/meta.dart';

@immutable
class SessionErrorUnknown {
  const SessionErrorUnknown({
    required this.type,
    required this.message,
  });

  factory SessionErrorUnknown.fromJson(Map<String, dynamic> json) {
    return SessionErrorUnknown(
      type: json["type"] as String,
      message: json["message"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "type": type,
      "message": message,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionErrorUnknown &&
          other.type == type &&
          other.message == message);

  @override
  int get hashCode => Object.hash(type, message);

  final String type;
  final String message;
}
