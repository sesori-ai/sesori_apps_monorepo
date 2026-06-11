// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class BadRequestError {
  const BadRequestError({
    required this.name,
    required this.data,
  });

  factory BadRequestError.fromJson(Map<String, dynamic> json) {
    return BadRequestError(
      name: json["name"] as String,
      data: BadRequestErrorData.fromJson(json["data"] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "name": name,
      "data": data.toJson(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BadRequestError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final BadRequestErrorData data;
}

@immutable
class BadRequestErrorData {
  const BadRequestErrorData({
    required this.message,
    this.kind,
  });

  factory BadRequestErrorData.fromJson(Map<String, dynamic> json) {
    return BadRequestErrorData(
      message: json["message"] as String,
      kind: json["kind"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "kind": ?kind,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BadRequestErrorData &&
          other.message == message &&
          other.kind == kind);

  @override
  int get hashCode => Object.hash(message, kind);

  final String message;
  final String? kind;
}
