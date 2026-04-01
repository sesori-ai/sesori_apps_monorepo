import "package:freezed_annotation/freezed_annotation.dart";

part "project.freezed.dart";

part "project.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Projects with _$Projects {
  const factory Projects({
    required List<Project> data,
  }) = _Projects;

  factory Projects.fromJson(Map<String, dynamic> json) => _$ProjectsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class Project with _$Project {
  const factory Project({
    required String id,
    required String? name,
    required ProjectTime? time,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectTime with _$ProjectTime {
  const factory ProjectTime({
    required int created,
    required int updated,
    required int? initialized,
  }) = _ProjectTime;

  factory ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectIdRequest with _$ProjectIdRequest {
  const factory ProjectIdRequest({
    required String projectId,
  }) = _ProjectIdRequest;

  factory ProjectIdRequest.fromJson(Map<String, dynamic> json) => _$ProjectIdRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectPathRequest with _$ProjectPathRequest {
  const factory ProjectPathRequest({
    required String path,
  }) = _ProjectPathRequest;

  factory ProjectPathRequest.fromJson(Map<String, dynamic> json) => _$ProjectPathRequestFromJson(json);
}
