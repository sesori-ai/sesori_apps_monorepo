import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

part "project_list_state.freezed.dart";

@Freezed()
sealed class ProjectListState with _$ProjectListState {
  const factory ProjectListState.loading() = ProjectListLoading;

  const factory ProjectListState.loaded({
    required List<Project> projects,
    required Map<String, int> activityByWorktree,
  }) = ProjectListLoaded;

  const factory ProjectListState.failed({required ApiError error}) = ProjectListFailed;
}
