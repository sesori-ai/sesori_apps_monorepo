import "dart:async";
import "dart:typed_data";

import "package:bloc/bloc.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/server_connection/models/connection_status.dart";
import "../../capabilities/server_connection/models/sse_event.dart";
import "../../foundation/models/file_preview/file_preview_result.dart";
import "../../foundation/models/page_draft.dart";
import "../../logging/logging.dart";
import "../../repositories/file_preview_repository.dart";
import "../../repositories/page_draft_repository.dart";
import "../../services/pending_page_service.dart";
import "pending_page_state.dart";

/// One open question page. The lookup decides whether it opens for editing or
/// read-only; unsent picks live in [PageDraftRepository] until the page
/// settles, so closing and reopening keeps them.
class PendingPageCubit({
  required final PendingPageService _service,
  required final PageDraftRepository _drafts,
  required final FilePreviewRepository _filePreviews,
  required final ConnectionService _connectionService,
  required final String requestId,
  required final String sessionId,
}) extends Cubit<PendingPageState> {
  this : super(const PageLoading()) {
    _settlements = _connectionService.events.listen(_onEvent);
    _reconnects = MergeStream<void>([
      _connectionService.status
          .map((status) => status is ConnectionConnected)
          .distinct()
          // The first value is the current status, not a reconnect.
          .skip(1)
          .where((isConnected) => isConnected),
      _connectionService.dataMayBeStale,
    ]).listen((_) => unawaited(_lookAgain()));
    unawaited(_lookup());
  }
  late final StreamSubscription<SseEvent> _settlements;
  late final StreamSubscription<void> _reconnects;
  final Map<String, Future<Uint8List?>> _images = {};

  /// Looks the page up again after a failed open.
  Future<void> retry() async {
    if (state is! PageLoadFailed) return;
    emit(const PageLoading());
    await _lookup();
  }

  /// A null [optionId] clears a single-choice question.
  void setChoice({required String questionId, required String? optionId}) => _edit(
    questionId: questionId,
    change: (draft) => draft.withChoice(questionId: questionId, optionId: optionId),
  );

  /// [optionIds] replaces a multiple-choice question's picks; an empty list
  /// clears them.
  void setChoices({required String questionId, required List<String> optionIds}) => _edit(
    questionId: questionId,
    change: (draft) => draft.withChoices(questionId: questionId, optionIds: optionIds),
  );

  void setText({required String questionId, required String? text}) => _edit(
    questionId: questionId,
    change: (draft) => draft.withText(questionId: questionId, text: text),
  );

  void setQuestionNote({required String questionId, required String? note}) => _edit(
    questionId: questionId,
    change: (draft) => draft.withQuestionNote(questionId: questionId, note: note),
  );

  /// The page's closing "Anything else?" note.
  void setNote({required String? note}) => _edit(questionId: null, change: (draft) => draft.withNote(note: note));

  Future<void> submit() async {
    final current = state;
    if (current is! PageEditing) return;
    emit(PageSubmitting(page: current.page, draft: current.draft, action: PageAction.submit));
    try {
      final result = await _service.submit(page: current.page, draft: current.draft);
      if (isClosed) return;
      switch (result) {
        case PageSubmitAccepted():
          _settleHere(from: current, action: PageAction.submit);
        case PageSubmitAlreadySettled():
          _settle(page: current.page, draft: current.draft, reason: PageReadOnlyReason.answeredElsewhere);
        case PageSubmitInvalid(:final questionIds):
          emit(
            _editing(
              from: current,
              feedback: PageFeedbackInvalid(questionIds: questionIds),
            ),
          );
        case PageSubmitUnknown():
          emit(_editing(from: current, feedback: const PageFeedbackUnknownResult()));
      }
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (isClosed) return;
      await _recover(
        from: current,
        failure: PageFeedbackFailed(action: PageAction.submit, cause: error),
      );
    }
  }

  Future<void> dismiss() async {
    final current = state;
    if (current is! PageEditing) return;
    emit(PageSubmitting(page: current.page, draft: current.draft, action: PageAction.dismiss));
    try {
      await _service.dismiss(page: current.page);
      if (!isClosed) _settleHere(from: current, action: PageAction.dismiss);
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (isClosed) return;
      await _recover(
        from: current,
        failure: PageFeedbackFailed(action: PageAction.dismiss, cause: error),
      );
    }
  }

  /// The image's bytes, or null when the bridge can't serve it. Each image
  /// loads once while the page is open, so scrolling back never reloads it.
  Future<Uint8List?> loadImage({required PageImage image}) => _images[image.path] ??= _loadImage(path: image.path);

  Future<Uint8List?> _loadImage({required String path}) async {
    switch (await _filePreviews.load(path: path)) {
      case FilePreviewImageContent(:final bytes):
        return bytes;
      case FilePreviewFailed(:final innerError, :final stackTrace):
        logw("Failed to load image $path of page $requestId", innerError, stackTrace);
        // A failed read may succeed later; an unavailable image will not.
        unawaited(_images.remove(path));
        return null;
      case final FilePreviewResult other:
        logw("Image $path of page $requestId is unavailable: ${other.runtimeType}");
        return null;
    }
  }

  Future<void> _lookup() async {
    try {
      final response = await _service.lookup(requestId: requestId, sessionId: sessionId);
      if (isClosed) return;
      final next = _afterLookup(response: response, current: state);
      if (next != null) emit(next);
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (isClosed) return;
      switch (state) {
        case PageLoading() || PageLoadFailed():
          emit(PageLoadFailed(cause: error));
        case PageEditing():
          // The page stays editable; the next reconnect looks again.
          logw("Failed to look page $requestId up again", error);
        case PageSubmitting() || PageSettledHere() || PageReadOnly() || PageMissing() || PageUnsupported():
          break;
      }
    }
  }

  /// After a failed submit or dismiss, the page may have settled meanwhile (the
  /// bridge refuses a settled page), and a reconnect during the request was not
  /// acted on, so look again before showing [failure]. The page stays
  /// submitting until then, so a page settled elsewhere turns read-only
  /// without flashing the failure first.
  Future<void> _recover({required PageEditing from, required PageFeedbackFailed failure}) async {
    final failed = _editing(from: from, feedback: failure);
    try {
      final response = await _service.lookup(requestId: requestId, sessionId: sessionId);
      if (isClosed) return;
      emit(_afterLookup(response: response, current: failed) ?? failed);
      // ApiError is an expected transport failure despite extending Error.
      // ignore: avoid_catching_errors
    } on ApiError catch (error) {
      if (isClosed) return;
      logw("Failed to look page $requestId up after a failed ${failure.action.name}", error);
      emit(failed);
    }
  }

  /// A reconnect may have missed the page settling, so an open page asks again.
  Future<void> _lookAgain() async {
    if (state is PageEditing || state is PageLoadFailed) await _lookup();
  }

  /// The state [response] leads to from [current], or null to keep [current].
  PendingPageState? _afterLookup({required PageLookupResponse response, required PendingPageState current}) {
    // A submit in flight or a settled page knows more than this lookup.
    if (current is PageSubmitting || current is PageSettledHere || current is PageReadOnly) return null;
    final editing = current is PageEditing ? current : null;
    switch (response) {
      case PageLookupPending(:final page):
        return PageEditing(
          page: page,
          draft: editing?.draft ?? _drafts.get(requestId: requestId) ?? PageDraft.empty,
          feedback: editing?.feedback ?? const PageFeedbackNone(),
        );
      case PageLookupAnswered(:final page, :final answers, :final note):
        _drafts.remove(requestId: requestId);
        if (editing != null) {
          return PageReadOnly(page: page, draft: editing.draft, reason: PageReadOnlyReason.answeredElsewhere);
        }
        return PageReadOnly(
          page: page,
          draft: PageDraft(answers: {for (final answer in answers) answer.questionId: answer}, note: note),
          reason: PageReadOnlyReason.answered,
        );
      case PageLookupDismissed(:final page):
        _drafts.remove(requestId: requestId);
        return PageReadOnly(
          page: page,
          draft: editing?.draft ?? PageDraft.empty,
          reason: PageReadOnlyReason.dismissed,
        );
      case PageLookupMissing():
        _drafts.remove(requestId: requestId);
        return const PageMissing();
      case PageLookupUnknown():
        return editing == null ? const PageUnsupported() : null;
    }
  }

  void _onEvent(SseEvent event) {
    final reason = switch (event.data) {
      SesoriQuestionReplied(requestID: final id) when id == requestId => PageReadOnlyReason.answeredElsewhere,
      SesoriQuestionRejected(requestID: final id) when id == requestId => PageReadOnlyReason.dismissed,
      _ => null,
    };
    if (reason == null) return;
    _drafts.remove(requestId: requestId);
    // A submit in flight learns its own outcome from the bridge's answer.
    if (state case PageEditing(:final page, :final draft)) {
      emit(PageReadOnly(page: page, draft: draft, reason: reason));
    }
  }

  void _edit({required String? questionId, required PageDraft Function(PageDraft draft) change}) {
    final current = state;
    if (current is! PageEditing) return;
    final draft = change(current.draft);
    _drafts.save(requestId: requestId, draft: draft);
    final feedback = switch (current.feedback) {
      PageFeedbackInvalid(:final questionIds) when questionIds.any((id) => id != questionId) => PageFeedbackInvalid(
        questionIds: [
          for (final id in questionIds)
            if (id != questionId) id,
        ],
      ),
      final PageFeedbackInvalid invalid when questionId == null => invalid,
      _ => const PageFeedbackNone(),
    };
    emit(PageEditing(page: current.page, draft: draft, feedback: feedback));
  }

  PageEditing _editing({required PageEditing from, required PageFeedback feedback}) =>
      PageEditing(page: from.page, draft: from.draft, feedback: feedback);

  void _settleHere({required PageEditing from, required PageAction action}) {
    _drafts.remove(requestId: requestId);
    emit(PageSettledHere(page: from.page, draft: from.draft, action: action));
  }

  void _settle({required PendingPage page, required PageDraft draft, required PageReadOnlyReason reason}) {
    _drafts.remove(requestId: requestId);
    emit(PageReadOnly(page: page, draft: draft, reason: reason));
  }

  @override
  Future<void> close() async {
    await _settlements.cancel();
    await _reconnects.cancel();
    await super.close();
  }
}
