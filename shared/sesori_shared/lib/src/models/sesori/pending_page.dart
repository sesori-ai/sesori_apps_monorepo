import "package:freezed_annotation/freezed_annotation.dart";

part "pending_page.freezed.dart";
part "pending_page.g.dart";

enum PageQuestionKind() {
  unknown,
  single,
  multiple,
  text,
}

/// An image the bridge copied when the page was sent. [path] points at that
/// copy, which the client reads through the file preview route.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageImage with _$PageImage {
  const factory({
    required String path,
    required int width,
    required int height,
    required String? caption,
  }) = _PageImage;

  factory fromJson(Map<String, dynamic> json) => _$PageImageFromJson(json);
}

/// [recommended] shows a label; it never preselects the option.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageOption with _$PageOption {
  const factory({
    required String id,
    required String label,
    required String? description,
    required PageImage? image,
    required bool recommended,
  }) = _PageOption;

  factory fromJson(Map<String, dynamic> json) => _$PageOptionFromJson(json);
}

/// Text questions carry no options.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageQuestion with _$PageQuestion {
  const factory({
    required String id,
    required String title,
    required String? body,
    required List<PageImage> images,
    @JsonKey(unknownEnumValue: PageQuestionKind.unknown) required PageQuestionKind kind,
    required List<PageOption> options,
    required bool isRequired,
  }) = _PageQuestion;

  factory fromJson(Map<String, dynamic> json) => _$PageQuestionFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageSection with _$PageSection {
  const factory({
    required String? heading,
    required String? body,
    required List<PageImage> images,
    required List<PageQuestion> questions,
  }) = _PageSection;

  factory fromJson(Map<String, dynamic> json) => _$PageSectionFromJson(json);
}

/// Request-scoped page content. Answers never belong in broadcasts; the
/// pending-question pipeline only carries a marker for the page.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PendingPage with _$PendingPage {
  const factory({
    required String id,
    required String sessionId,
    required String? displaySessionId,
    required String title,
    required String? intro,
    required List<PageSection> sections,
  }) = _PendingPage;

  factory fromJson(Map<String, dynamic> json) => _$PendingPageFromJson(json);
}

/// Omit an unanswered question. A text answer carries [text] and no option ids.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageAnswer with _$PageAnswer {
  const factory({
    required String questionId,
    required List<String> optionIds,
    required String? text,
    required String? note,
  }) = _PageAnswer;

  factory fromJson(Map<String, dynamic> json) => _$PageAnswerFromJson(json);
}

@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class SubmitPageRequest with _$SubmitPageRequest {
  const factory({
    required String requestId,
    required String sessionId,
    required List<PageAnswer> answers,
    required String? note,
  }) = _SubmitPageRequest;

  factory fromJson(Map<String, dynamic> json) => _$SubmitPageRequestFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class PageSubmitResult with _$PageSubmitResult {
  const factory unknown() = PageSubmitUnknown;
  const factory accepted() = PageSubmitAccepted;
  const factory alreadySettled() = PageSubmitAlreadySettled;
  const factory invalid({required List<String> questionIds}) = PageSubmitInvalid;

  factory fromJson(Map<String, dynamic> json) => _$PageSubmitResultFromJson(json);
}

/// [sessionId] may be the page's own session or its root (display) session,
/// where the answer notice sits.
@Freezed(copyWith: false, fromJson: true, toJson: true, toStringOverride: false)
sealed class PageLookupRequest with _$PageLookupRequest {
  const factory({
    required String sessionId,
    required String requestId,
  }) = _PageLookupRequest;

  factory fromJson(Map<String, dynamic> json) => _$PageLookupRequestFromJson(json);
}

@Freezed(
  unionKey: "type",
  fallbackUnion: "unknown",
  copyWith: false,
  fromJson: true,
  toJson: true,
  toStringOverride: false,
)
sealed class PageLookupResponse with _$PageLookupResponse {
  const factory unknown() = PageLookupUnknown;
  const factory pending({required PendingPage page}) = PageLookupPending;
  const factory answered({
    required PendingPage page,
    required List<PageAnswer> answers,
    required String? note,
  }) = PageLookupAnswered;
  const factory dismissed({required PendingPage page}) = PageLookupDismissed;
  const factory missing() = PageLookupMissing;

  factory fromJson(Map<String, dynamic> json) => _$PageLookupResponseFromJson(json);
}
