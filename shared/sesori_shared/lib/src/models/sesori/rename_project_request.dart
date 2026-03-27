import "package:freezed_annotation/freezed_annotation.dart";

part "rename_project_request.freezed.dart";

part "rename_project_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class RenameProjectRequest with _$RenameProjectRequest {
  const factory RenameProjectRequest({
    required String name,
  }) = _RenameProjectRequest;

  factory RenameProjectRequest.fromJson(Map<String, dynamic> json) => _$RenameProjectRequestFromJson(json);
}
