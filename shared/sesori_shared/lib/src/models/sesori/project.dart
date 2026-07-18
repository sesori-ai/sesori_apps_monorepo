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
    // COMPATIBILITY 2026-07-10 (v1.5.0): Old bridges may omit path. Require path and remove the client id fallback once those bridges are unsupported.
    @Default("") String path,
    // COMPATIBILITY 2026-07-11 (v1.4.1): Old bridges may omit time. Require it and remove bridge/client fallbacks.
    required ProjectTime? time,
    // Whether this project has at least one non-archived session with unseen
    // activity. Backend-derived from its sessions. Defaults to false so older
    // payloads (and the baseline) deserialize as "seen".
    // COMPATIBILITY 2026-07-03 (v1.3.0): Old bridges omit unseen-change state. Require the field once those bridges are unsupported.
    @Default(false) bool hasUnseenChanges,
    // Whether the project's directory no longer exists on disk at its recorded
    // location (the folder was moved or deleted). The bridge stamps this from a
    // filesystem check; the client renders such projects as "folder not found"
    // instead of driving into a dead path. Defaults to false so older payloads
    // deserialize as "present".
    // COMPATIBILITY 2026-07-08 (v1.4.0): Old bridges omit directory-missing state. Require the field once those bridges are unsupported.
    @Default(false) bool directoryMissing,
    // Whether this project can create dedicated Git worktrees. This is a
    // capability rather than a raw Git-state field so clients render the
    // behavior the bridge can actually provide.
    // COMPATIBILITY 2026-07-17 (v1.5.2): Old bridges omit this capability. Default to the prior visible-toggle behavior; require the field once those bridges are unsupported.
    @Default(true) bool supportsDedicatedWorktrees,
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

@JsonEnum(fieldRename: FieldRename.snake)
enum OpenProjectGitAction {
  promptIfNeeded,
  initializeGit,
  openWithoutGit,
}

@Freezed(fromJson: true, toJson: true)
sealed class OpenProjectRequest with _$OpenProjectRequest {
  const factory OpenProjectRequest({
    required String path,
    // COMPATIBILITY 2026-07-17 (v1.5.2): Old apps send only path. Keep opening without Git until those apps are unsupported.
    @Default(OpenProjectGitAction.openWithoutGit) OpenProjectGitAction gitAction,
  }) = _OpenProjectRequest;

  factory OpenProjectRequest.fromJson(Map<String, dynamic> json) => _$OpenProjectRequestFromJson(json);
}
