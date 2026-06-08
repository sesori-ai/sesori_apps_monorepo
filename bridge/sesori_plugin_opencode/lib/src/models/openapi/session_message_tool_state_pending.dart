// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.963605Z

import 'package:meta/meta.dart';

@immutable
class SessionMessageToolStatePending {
  const SessionMessageToolStatePending({
    required this.status,
    required this.input,
  });

  factory SessionMessageToolStatePending.fromJson(Map<String, dynamic> json) {
    return SessionMessageToolStatePending(
      status: json["status"] as String,
      input: json["input"] as String,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "status": status,
      "input": input,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionMessageToolStatePending &&
          other.status == status &&
          other.input == input);

  @override
  int get hashCode => Object.hash(status, input);

  final String status;
  final String input;
}
