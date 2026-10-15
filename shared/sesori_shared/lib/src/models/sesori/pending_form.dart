import "package:freezed_annotation/freezed_annotation.dart";

import "form_field.dart";
import "form_value.dart";

part "pending_form.freezed.dart";
part "pending_form.g.dart";

enum FormDismissalChoice() {
  unknown,
  decline,
  cancel,
}

enum FormValidationIssue() {
  unknown,
  required,
  invalidType,
  invalidChoice,
  outOfRange,
  invalidLength,
  invalidFormat,
}

// ignore: no_slop_linter/prefer_specific_type, decoded JSON map boundary
Map<String, FormValidationIssue> _decodeFieldErrors(Map<String, dynamic> json) => json.cast<String, String>().map(
  (fieldId, value) => MapEntry(
    fieldId,
    FormValidationIssue.values.firstWhere((issue) => issue.name == value, orElse: () => FormValidationIssue.unknown),
  ),
);

/// Request-scoped form data. Defaults and answers never belong in broadcasts.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingForm with _$PendingForm {
  const factory({
    required String id,
    required String sessionID,
    required String? displaySessionId,
    required String title,
    required String message,
    required List<PendingFormField> fields,
  }) = _PendingForm;

  factory fromJson(Map<String, dynamic> json) => _$PendingFormFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingFormsResponse with _$PendingFormsResponse {
  const factory({required List<PendingForm> data}) = _PendingFormsResponse;

  factory fromJson(Map<String, dynamic> json) => _$PendingFormsResponseFromJson(json);
}

/// Omit an unanswered optional field; false, zero and empty text are answers.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class ReplyToFormRequest with _$ReplyToFormRequest {
  const factory({
    required String requestId,
    required String sessionId,
    required Map<String, FormValue> values,
  }) = _ReplyToFormRequest;

  factory fromJson(Map<String, dynamic> json) => _$ReplyToFormRequestFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class DeclineFormRequest with _$DeclineFormRequest {
  const factory({
    required String requestId,
    required String sessionId,
    @JsonKey(unknownEnumValue: FormDismissalChoice.unknown) required FormDismissalChoice choice,
  }) = _DeclineFormRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeclineFormRequestFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class FormReplyResult with _$FormReplyResult {
  const factory unknown() = FormReplyUnknown;
  const factory accepted() = FormReplyAccepted;
  const factory alreadySettled() = FormAlreadySettled;
  const factory validationFailed({
    @JsonKey(fromJson: _decodeFieldErrors) required Map<String, FormValidationIssue> fieldErrors,
  }) = FormValidationFailed;
  const factory unsupportedChoice() = FormUnsupportedChoice;

  factory fromJson(Map<String, dynamic> json) => _$FormReplyResultFromJson(json);
}
