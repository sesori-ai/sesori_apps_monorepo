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
    // Live directory of the project on disk — the directory backend operations
    // run in. Distinct from [id]: the id is a stable identifier that survives
    // folder moves (for git-backed backends it is the original worktree path,
    // pinned at first open). Defaults to "" so payloads from older bridges
    // (which don't send a path) still decode; clients fall back to [id] when
    // empty.
    @Default("") String path,
    required ProjectTime? time,
    // Whether this project has at least one non-archived session with unseen
    // activity. Backend-derived from its sessions. Defaults to false so older
    // payloads (and the baseline) deserialize as "seen".
    @Default(false) bool hasUnseenChanges,
    // Whether the project's directory no longer exists on disk at its recorded
    // location (the folder was moved or deleted). The bridge stamps this from a
    // filesystem check; the client renders such projects as "folder not found"
    // instead of driving into a dead path. Defaults to false so older payloads
    // deserialize as "present".
    @Default(false) bool directoryMissing,
  }) = _Project;

  factory Project.fromJson(Map<String, dynamic> json) => _$ProjectFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectTime with _$ProjectTime {
  const factory ProjectTime({
    required int created,
    required int updated,
  }) = _ProjectTime;

  factory ProjectTime.fromJson(Map<String, dynamic> json) => _$ProjectTimeFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class ProjectIdRequest with _$ProjectIdRequest {
  const factory ProjectIdRequest({
    required String projectId,
    // Nullable so requests remain compatible with older peers that do not identify plugins.
    required String? pluginId,
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
