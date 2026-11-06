import "dart:async";

import "package:bloc/bloc.dart";

import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../logging/logging.dart";
import "../../platform/app_review_client.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../services/feedback_prompt_service.dart";
import "../../services/product_analytics_service.dart";
import "feedback_prompt_presentation.dart";

/// Acts on each automatic showing [FeedbackPromptService] claims.
///
/// Where Sesori may ask first, it asks the app-root presenter to open the
/// rating sheet. Where it may not (Android, under Google Play's In-App Review
/// policy), it requests the store's in-app review directly, with no sheet.
class FeedbackPromptCubit({
  required final FeedbackPromptService _feedbackPromptService,
  required final AppReviewClient _appReviewClient,
  required final ProductAnalyticsService _productAnalyticsService,
}) extends Cubit<FeedbackPromptPresentation> {
  late final StreamSubscription<void> _subscription;
  int _sequence = 0;

  this : super(const FeedbackPromptPresentation.idle()) {
    _subscription = _feedbackPromptService.prompts.listen((_) => _onPrompt());
  }

  void _onPrompt() {
    if (_appReviewClient.allowsQuestionBeforeReview) {
      emit(FeedbackPromptPresentation.show(sequence: ++_sequence));
      return;
    }
    _reportReviewRequested();
    unawaited(_appReviewClient.requestReview());
  }

  /// Reported as the sheet's love-and-review answer so it lands in the same
  /// rating funnel; the event's platform tells the direct requests apart.
  void _reportReviewRequested() {
    unawaited(
      _productAnalyticsService
          .logEvent(
            event: const ProductAnalyticsEvent.feedbackPromptAnswered(
              answer: AnalyticsFeedbackAnswer.loveReviewRequested,
              source: AnalyticsFeedbackSource.automatic,
            ),
            occurredAtUtc: DateTime.now().toUtc(),
          )
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver the review request analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report the review request analytics event", error, stackTrace);
          }),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
