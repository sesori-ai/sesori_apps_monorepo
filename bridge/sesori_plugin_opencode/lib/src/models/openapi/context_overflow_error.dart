// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class ContextOverflowError {
  const ContextOverflowError({
    required this.name,
    required this.data,
  });

  factory ContextOverflowError.fromJson(Map<String, dynamic> json) {
    return ContextOverflowError(
      name: json["name"] as String,
      data: ContextOverflowErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is ContextOverflowError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ContextOverflowErrorData data;
}

@immutable
class ContextOverflowErrorData {
  const ContextOverflowErrorData({
    required this.message,
    this.responseBody,
  });

  factory ContextOverflowErrorData.fromJson(Map<String, dynamic> json) {
    return ContextOverflowErrorData(
      message: json["message"] as String,
      responseBody: json["responseBody"] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
      "responseBody": ?responseBody,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContextOverflowErrorData &&
          other.message == message &&
          other.responseBody == responseBody);

  @override
  int get hashCode => Object.hash(message, responseBody);

  final String message;
  final String? responseBody;
}
