import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

part "session.freezed.dart";

part "session.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class Session with _$Session {
  const factory Session({
    required String id,
    required String projectID,
    required String directory,
    String? parentID,
    String? title,
    SessionTime? time,
    SessionSummary? summary,
  }) = _Session;

  factory Session.fromJson(Map<String, dynamic> json) => _$SessionFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionTime with _$SessionTime {
  const factory SessionTime({
    required int created,
    required int updated,
    int? archived,
  }) = _SessionTime;

  factory SessionTime.fromJson(Map<String, dynamic> json) => _$SessionTimeFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class SessionSummary with _$SessionSummary {
  const factory SessionSummary({
    @Default(0) int additions,
    @Default(0) int deletions,
    @Default(0) int files,
  }) = _SessionSummary;

  factory SessionSummary.fromJson(Map<String, dynamic> json) => _$SessionSummaryFromJson(json);
}

/// Session with embedded project info, returned by `/experimental/session`.
///
/// This is the `GlobalInfo` type from the OpenCode server — a [Session] extended
/// with a nullable [SessionProject] that identifies which project the session
/// belongs to.
@Freezed(fromJson: true, toJson: true)
sealed class GlobalSession with _$GlobalSession {
  const factory GlobalSession({
    required String id,
    required String projectID,
    required String directory,
    String? parentID,
    String? title,
    SessionTime? time,
    SessionSummary? summary,
    SessionProject? project,
  }) = _GlobalSession;

  factory GlobalSession.fromJson(Map<String, dynamic> json) => _$GlobalSessionFromJson(json);
}

/// Lightweight project reference embedded in [GlobalSession].
///
/// This is the `ProjectInfo` / `ProjectSummary` type from the OpenCode server —
/// a subset of [Project] with only `id`, `name`, and `worktree`.
@Freezed(fromJson: true, toJson: true)
sealed class SessionProject with _$SessionProject {
  const factory SessionProject({
    required String id,
    String? name,
    required String worktree,
  }) = _SessionProject;

  factory SessionProject.fromJson(Map<String, dynamic> json) => _$SessionProjectFromJson(json);
}

extension SessionToPluginExtension on Session {
  PluginSession toPlugin() => PluginSession(
    id: id,
    projectID: directory,
    directory: directory,
    parentID: parentID,
    title: title,
    summary: switch (summary) {
      SessionSummary(:final additions, :final deletions, :final files) => PluginSessionSummary(
        additions: additions,
        deletions: deletions,
        files: files,
      ),
      null => null,
    },
    time: switch (time) {
      SessionTime(:final created, :final updated, :final archived) => PluginSessionTime(
        created: created,
        updated: updated,
        archived: archived,
      ),
      null => null,
    },
  );
}
