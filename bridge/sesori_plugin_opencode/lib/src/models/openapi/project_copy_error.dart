// GENERATED FILE - DO NOT EDIT BY HAND
// Source: anomalyco/opencode@v1.16.2 (76c631d198f9ff620e15468e45f3457d50481b57)

import 'package:meta/meta.dart';

@immutable
class ProjectCopyError {
  const ProjectCopyError({
    required this.name,
    required this.data,
  });

  factory ProjectCopyError.fromJson(Map<String, dynamic> json) {
    return ProjectCopyError(
      name: json["name"] as String,
      data: ProjectCopyErrorData.fromJson(json["data"] as Map<String, dynamic>),
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
      (other is ProjectCopyError &&
          other.name == name &&
          other.data == data);

  @override
  int get hashCode => Object.hash(name, data);

  final String name;
  final ProjectCopyErrorData data;
}

@immutable
class ProjectCopyErrorData {
  const ProjectCopyErrorData({
    required this.message,
  });

  factory ProjectCopyErrorData.fromJson(Map<String, dynamic> json) {
    return ProjectCopyErrorData(
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
      (other is ProjectCopyErrorData &&
          other.message == message);

  @override
  int get hashCode => message.hashCode;

  final String message;
}
