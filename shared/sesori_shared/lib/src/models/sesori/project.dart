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
  // ignore: no_slop_linter/prefer_required_named_parameters -- Freezed null default preserves older wire payloads.
  const factory Project({
    required String id,
    required String? name,
    // Live directory of the project on disk — the directory backend operations
    // run in. Distinct from [id]: the id is a stable identifier that survives
    // folder moves (for git-backed backends it is the original worktree path,
    // pinned at first open). Defaults to "" so payloads from older bridges
    // (which don't send a path) still decode; clients fall back to [id] when
    // empty.
    // COMPATIBILITY 2026-07-10 (v1.5.0): Old bridges may omit path. Require path and remove the client id fallback once those bridges are unsupported.
    @Default("") String path,
    // COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges may omit time. Require it and remove bridge/client fallbacks.
    required ProjectTime? time,
    // Whether this project has at least one non-archived session with unseen
    // activity. Backend-derived from its sessions. Defaults to false so older
    // payloads (and the baseline) deserialize as "seen".
    // COMPATIBILITY 2026-07-03 (v1.3.0): Old bridges omit unseen-change state. Require the field once those bridges are unsupported.
    @Default(false) bool hasUnseenChanges,
    // COMPATIBILITY 2026-07-16 (v1.5.0): Older bridges omit lastUserInteractionAt, which means no persisted interaction is available. Remove the default and require the field once those bridges are unsupported.
    @Default(null) int? lastUserInteractionAt,
    // Whether the project's directory no longer exists on disk at its recorded
    // location (the folder was moved or deleted). The bridge stamps this from a
    // filesystem check; the client renders such projects as "folder not found"
    // instead of driving into a dead path. Defaults to false so older payloads
    // deserialize as "present".
    // COMPATIBILITY 2026-07-08 (v1.4.0): Old bridges omit directory-missing state. Require the field once those bridges are unsupported.
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
