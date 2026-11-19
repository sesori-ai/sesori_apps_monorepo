import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/page_draft.dart";

/// Why a page shows read-only.
enum PageReadOnlyReason() {
  /// The page was answered before it was opened, here or on another surface.
  answered,

  /// Another surface answered the page while it was open here.
  answeredElsewhere,
  dismissed,
}

enum PageAction() {
  submit,
  dismiss,
}

sealed class const PendingPageState();

final class const PageLoading() extends PendingPageState;

/// The bridge no longer has the page, for example because its session was
/// deleted.
final class const PageMissing() extends PendingPageState;

/// The bridge answered the lookup in a shape this app doesn't know.
final class const PageUnsupported() extends PendingPageState;

final class const PageLoadFailed({required final ApiError cause}) extends PendingPageState;

final class const PageEditing({
  required final PendingPage page,
  required final PageDraft draft,
  required final PageFeedback feedback,
}) extends PendingPageState;

final class const PageSubmitting({
  required final PendingPage page,
  required final PageDraft draft,
  required final PageAction action,
}) extends PendingPageState;

/// The bridge accepted this surface's submit. The page leaves as it was, so
/// nothing on it moves while it goes.
final class const PageSent({required final PendingPage page, required final PageDraft draft}) extends PendingPageState;

/// [draft] holds the answers the page settled with, or this surface's own
/// picks when the page settled elsewhere while open.
final class const PageReadOnly({
  required final PendingPage page,
  required final PageDraft draft,
  required final PageReadOnlyReason reason,
}) extends PendingPageState;

/// What the last submit or dismiss left to tell the user.
sealed class const PageFeedback();

final class const PageFeedbackNone() extends PageFeedback;

/// These questions still need an answer, or the bridge refused their answers.
final class PageFeedbackInvalid({required List<String> questionIds}) extends PageFeedback {
  final List<String> questionIds = List.unmodifiable(questionIds);
}

final class const PageFeedbackFailed({required final PageAction action, required final ApiError cause})
    extends PageFeedback;

/// The bridge answered the submit in a shape this app doesn't know.
final class const PageFeedbackUnknownResult() extends PageFeedback;
