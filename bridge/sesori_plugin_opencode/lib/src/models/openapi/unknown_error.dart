// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)
// Generated: 2026-06-08T14:11:43.976835Z

import 'package:meta/meta.dart';

@immutable
class UnknownError {
  const UnknownError({
    required this.name,
    required this.data,
  });

  factory UnknownError.fromJson(Map<String, dynamic> json) {
    return UnknownError(
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
      (other is UnknownError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final Map<String, dynamic> data;
}
