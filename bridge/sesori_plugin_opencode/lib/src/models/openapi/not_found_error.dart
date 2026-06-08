// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:04:07.976588Z

import 'package:meta/meta.dart';

@immutable
class NotFoundError {
  const NotFoundError({
    required this.name,
    required this.data,
  });

  factory NotFoundError.fromJson(Map<String, dynamic> json) {
    return NotFoundError(
      name: json["name"] as String,
      data: json["data"] as Map<String, dynamic>,
    );
  }


  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotFoundError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final Map<String, dynamic> data;
}
