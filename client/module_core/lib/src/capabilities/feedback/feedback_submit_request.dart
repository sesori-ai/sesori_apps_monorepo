import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/feedback/feedback_issue.dart";
import "../../foundation/models/feedback/feedback_source.dart";

part "feedback_submit_request.freezed.dart";
part "feedback_submit_request.g.dart";

@Freezed(fromJson: true, toJson: true)
sealed class FeedbackSubmitRequest with _$FeedbackSubmitRequest {
  const factory({
    required List<FeedbackIssue> issues,
    // The server rejects a blank message, so a missing one must be an absent
    // key; include_if_null: false in build.yaml omits it.
    required String? message,
    required FeedbackSource source,
    required DevicePlatform platform,
    required String appVersion,
  }) = _FeedbackSubmitRequest;

  factory fromJson(Map<String, dynamic> json) => _$FeedbackSubmitRequestFromJson(json);
}
