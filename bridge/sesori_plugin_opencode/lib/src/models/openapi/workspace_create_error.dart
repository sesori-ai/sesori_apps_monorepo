// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class WorkspaceCreateError {
  const WorkspaceCreateError({
    required this.name,
    required this.data,
  });

  factory WorkspaceCreateError.fromJson(Map<String, dynamic> json) {
    return WorkspaceCreateError(
      name: json["name"] as String,
      data: WorkspaceCreateErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is WorkspaceCreateError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final WorkspaceCreateErrorData data;
}

@immutable
class WorkspaceCreateErrorData {
  const WorkspaceCreateErrorData({
    required this.message,
  });

  factory WorkspaceCreateErrorData.fromJson(Map<String, dynamic> json) {
    return WorkspaceCreateErrorData(
      message: json["message"] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "message": message,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkspaceCreateErrorData &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
