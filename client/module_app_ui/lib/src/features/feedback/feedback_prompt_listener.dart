import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "feedback_sheet.dart";

/// Opens the automatic rating sheet on a product shell's root navigator,
/// over whichever screen is showing, whenever [FeedbackPromptCubit] asks.
///
/// Reads the [FeedbackSheetCubit] for the automatic entry from above.
class const FeedbackPromptListener({
  required final GlobalKey<NavigatorState> navigatorKey,
  required final FeedbackVoiceInputScopeBuilder voiceInputScopeBuilder,
  required final Widget child,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedbackPromptCubit, FeedbackPromptPresentation>(
      listenWhen: (_, current) => current is FeedbackPromptShow,
      listener: (context, _) => unawaited(
        _present(
          navigatorKey: navigatorKey,
          cubit: context.read<FeedbackSheetCubit>(),
          voiceInputScopeBuilder: voiceInputScopeBuilder,
        ),
      ),
      child: child,
    );
  }
}

Future<void> _present({
  required GlobalKey<NavigatorState> navigatorKey,
  required FeedbackSheetCubit cubit,
  required FeedbackVoiceInputScopeBuilder voiceInputScopeBuilder,
}) async {
  final outcome = await showFeedbackSheetOnNavigator(
    navigatorKey: navigatorKey,
    cubit: cubit,
    voiceInputScopeBuilder: voiceInputScopeBuilder,
  );
  switch (outcome) {
    case FeedbackSheetOutcomeLoveLeaveReview():
      await cubit.requestStoreReview();
    case FeedbackSheetOutcomeLoveNotNow() ||
        FeedbackSheetOutcomeCouldBeBetter() ||
        FeedbackSheetOutcomeDismissed() ||
        null:
      break;
  }
}
