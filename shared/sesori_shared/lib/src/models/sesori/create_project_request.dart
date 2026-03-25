import "package:freezed_annotation/freezed_annotation.dart";

part "create_project_request.freezed.dart";
part "create_project_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class CreateProjectRequest with _$CreateProjectRequest {
  const factory CreateProjectRequest({
    required String path,
  }) = _CreateProjectRequest;

  factory CreateProjectRequest.fromJson(Map<String, dynamic> json) => _$CreateProjectRequestFromJson(json);
}
