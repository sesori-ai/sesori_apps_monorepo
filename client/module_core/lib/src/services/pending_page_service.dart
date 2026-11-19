import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../foundation/models/page_draft.dart";
import "../foundation/models/product_analytics/product_analytics_event.dart";
import "../logging/logging.dart";
import "../repositories/models/analytics_delivery_result.dart";
import "../repositories/session_repository.dart";
import "product_analytics_service.dart";

/// Opens, submits and dismisses an agent's question page. It holds no page
/// state; the bridge's answer to each call is the authority.
@lazySingleton
class PendingPageService({
  required final SessionRepository _repository,
  required final ProductAnalyticsService _productAnalyticsService,
}) {
  /// Throws the [ApiError] when the lookup fails.
  Future<PageLookupResponse> lookup({required String requestId, required String sessionId}) async {
    return switch (await _repository.lookupPage(
      request: PageLookupRequest(sessionId: sessionId, requestId: requestId),
    )) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
  }

  /// The required questions [draft] leaves unanswered, in page order. A
  /// question of a kind this app doesn't know can't be answered here, so it
  /// never blocks Submit.
  List<String> unansweredRequired({required PendingPage page, required PageDraft draft}) => [
    for (final question in draft.unanswered(page: page))
      if (question.isRequired) question.id,
  ];

  /// Refuses locally, without asking the bridge, while a required question is
  /// unanswered. Throws the [ApiError] when the request fails.
  Future<PageSubmitResult> submit({required PendingPage page, required PageDraft draft}) async {
    final unanswered = unansweredRequired(page: page, draft: draft);
    if (unanswered.isNotEmpty) return PageSubmitInvalid(questionIds: unanswered);
    final result = switch (await _repository.submitPage(
      request: SubmitPageRequest(
        requestId: page.id,
        sessionId: page.sessionId,
        answers: [
          for (final question in _questions(page: page)) ?draft.answers[question.id],
        ],
        note: draft.note,
      ),
    )) {
      SuccessResponse(:final data) => data,
      ErrorResponse(:final error) => throw error,
    };
    if (result is PageSubmitAccepted) _report(outcome: AnalyticsQuestionPageOutcome.answered, page: page);
    return result;
  }

  /// Dismisses through the question pipeline's reject, which the bridge
  /// settles as a dismissed page. Throws the [ApiError] when the request fails.
  Future<void> dismiss({required PendingPage page}) async {
    switch (await _repository.rejectQuestion(requestId: page.id, sessionId: page.sessionId)) {
      case SuccessResponse():
        _report(outcome: AnalyticsQuestionPageOutcome.dismissed, page: page);
      case ErrorResponse(:final error):
        throw error;
    }
  }

  Iterable<PageQuestion> _questions({required PendingPage page}) =>
      page.sections.expand((section) => section.questions);

  void _report({required AnalyticsQuestionPageOutcome outcome, required PendingPage page}) {
    final event = QuestionPageFinishedEvent.of(outcome: outcome, page: page);
    unawaited(
      _productAnalyticsService
          .logEvent(event: event, occurredAtUtc: DateTime.now().toUtc())
          .then<void>((delivery) {
            if (delivery == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver ${event.wireName} analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report ${event.wireName} analytics event", error, stackTrace);
          }),
    );
  }
}
