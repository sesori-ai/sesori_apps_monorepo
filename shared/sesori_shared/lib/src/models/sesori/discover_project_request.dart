import "package:freezed_annotation/freezed_annotation.dart";

part "discover_project_request.freezed.dart";
part "discover_project_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class DiscoverProjectRequest with _$DiscoverProjectRequest {
  const factory DiscoverProjectRequest({
    required String path,
  }) = _DiscoverProjectRequest;

  factory DiscoverProjectRequest.fromJson(Map<String, dynamic> json) => _$DiscoverProjectRequestFromJson(json);
}
