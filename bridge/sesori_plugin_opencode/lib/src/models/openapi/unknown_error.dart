// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

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
      data: UnknownErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is UnknownError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final UnknownErrorData data;
}

@immutable
class UnknownErrorData {
  const UnknownErrorData({
    required this.message,
    this.ref,
  });

  factory UnknownErrorData.fromJson(Map<String, dynamic> json) {
    return UnknownErrorData(
      message: json["message"] as String,
      ref: json["ref"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "ref": ?ref,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnknownErrorData &&
          other.message == message &&
          other.ref == ref);

  @override
  int get hashCode => Object.hash(message, ref);

  final String message;
  final String? ref;
}
