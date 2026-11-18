import "package:freezed_annotation/freezed_annotation.dart";

part "sesori_mcp_tool_arguments.freezed.dart";
part "sesori_mcp_tool_arguments.g.dart";

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class ListTasksArguments with _$ListTasksArguments {
  const factory({@JsonKey(name: "project_id") required String? projectId}) = _ListTasksArguments;

  factory fromJson(Map<String, dynamic> json) => _$ListTasksArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskArguments with _$GetTaskArguments {
  const factory({@JsonKey(name: "task_id") required String? taskId}) = _GetTaskArguments;

  factory fromJson(Map<String, dynamic> json) => _$GetTaskArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class ListTaskRunsArguments with _$ListTaskRunsArguments {
  const factory({@JsonKey(name: "task_id") required String taskId}) = _ListTaskRunsArguments;

  factory fromJson(Map<String, dynamic> json) => _$ListTaskRunsArgumentsFromJson(json);
}

@Freezed(fromJson: true, toJson: false, copyWith: false, equal: false)
sealed class GetTaskRunTranscriptArguments with _$GetTaskRunTranscriptArguments {
  const factory({
    @JsonKey(name: "task_id") required String taskId,
    @JsonKey(name: "run_id") required String runId,

    /// The previous page's `next_page`; null for the newest page.
    required int? page,
  }) = _GetTaskRunTranscriptArguments;

  factory fromJson(Map<String, dynamic> json) => _$GetTaskRunTranscriptArgumentsFromJson(json);
}
