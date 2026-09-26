import "dart:async";

import "package:bloc/bloc.dart";

import "../../services/feedback_prompt_service.dart";
import "feedback_prompt_presentation.dart";

/// Asks the app-root presenter to open the rating sheet each time
/// [FeedbackPromptService] claims an automatic showing.
class FeedbackPromptCubit({
  required final FeedbackPromptService _feedbackPromptService,
}) extends Cubit<FeedbackPromptPresentation> {
  late final StreamSubscription<void> _subscription;
  int _sequence = 0;

  this : super(const FeedbackPromptPresentation.idle()) {
    _subscription = _feedbackPromptService.prompts.listen(
      (_) => emit(FeedbackPromptPresentation.show(sequence: ++_sequence)),
    );
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
