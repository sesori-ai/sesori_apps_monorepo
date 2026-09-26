import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "feedback_private_step.dart";
import "feedback_rating_motion.dart";
import "feedback_sheet_motion.dart";

/// Presents the rating sheet driven by [cubit] and resolves with its outcome
/// once the sheet's route has fully closed, so a follow-up such as opening
/// the store never cuts the exit animation short. Sent private feedback is
/// confirmed with a toast once the sheet has gone.
Future<FeedbackSheetOutcome> showFeedbackSheet({
  required BuildContext context,
  required FeedbackSheetCubit cubit,
}) async {
  cubit.start();
  final reducedMotion = prefersReducedMotion(context);
  ModalRoute<void>? sheetRoute;
  // ignore: no_slop_linter/avoid_raw_modal_presenters, mobile-only grabber sheet with the approved drawer motion, which showPregoModalRoute cannot carry
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.62),
    sheetAnimationStyle: AnimationStyle(
      duration: reducedMotion ? Duration.zero : feedbackSheetOpenDuration,
      reverseDuration: reducedMotion ? Duration.zero : feedbackSheetCloseDuration,
      curve: feedbackDrawerCurve,
      reverseCurve: feedbackEaseOut.flipped,
    ),
    builder: (context) {
      sheetRoute = ModalRoute.of<void>(context);
      return BlocProvider.value(value: cubit, child: const FeedbackSheet());
    },
  );
  // A popped sheet's result completes before its closing animation does.
  await sheetRoute?.completed;
  final outcome = cubit.outcome;
  if (outcome case FeedbackSheetOutcomeCouldBeBetter(sent: true) when context.mounted) {
    PregoPopupAlertPresenter.of(context).show(
      title: context.loc.feedbackSent,
      variant: PregoPopupAlertsNotificationsVariant.success,
    );
  }
  return outcome;
}

/// Grabber-only sheet from Figma 5527:8368. `PregoBottomSheet` carries a
/// navigation header, so this chrome stays local to the feedback flow.
class const FeedbackSheet({super.key}) extends StatefulWidget {
  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState() extends State<FeedbackSheet> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _celebration = AnimationController(vsync: this, duration: feedbackCelebrationDuration);
  // Keep the first 1.2s of Figma's 2s sequence at its authored pace. Only the
  // quiet tail is compressed into 300ms.
  late final Animation<double> _celebrationTimeline = _celebration.drive(
    TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 0, end: 0.6), weight: 80),
      TweenSequenceItem(tween: Tween<double>(begin: 0.6, end: 1), weight: 20),
    ]),
  );
  // Keeps the draft when Reduce Motion removes the surrounding AnimatedSize.
  final _privateStepKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _celebration.addStatusListener(_celebrationStatusChanged);
  }

  @override
  void didChangeAccessibilityFeatures() {
    setState(() {});
    // MediaQuery has not rebuilt yet when this platform callback arrives.
    final features = View.of(context).platformDispatcher.accessibilityFeatures;
    if ((features.disableAnimations || features.reduceMotion) && _celebration.isAnimating) {
      // Finish the celebration promptly when Reduce Motion turns on mid-flight.
      _celebration.value = 1;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _celebration.dispose();
    super.dispose();
  }

  void _chooseLove() {
    final cubit = context.read<FeedbackSheetCubit>();
    cubit.chooseLove();
    if (prefersReducedMotion(context)) {
      cubit.finishCelebration();
    } else {
      _celebration.forward();
    }
  }

  void _celebrationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) context.read<FeedbackSheetCubit>().finishCelebration();
  }

  void _chooseCouldBeBetter() => context.read<FeedbackSheetCubit>().chooseCouldBeBetter();

  void _leaveReview() {
    context.read<FeedbackSheetCubit>().chooseLeaveReview();
    _close();
  }

  // ignore: no_slop_linter/avoid_navigator_of, pops the pageless sheet route that showFeedbackSheet pushed
  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FeedbackSheetCubit>().state;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final reducedMotion = prefersReducedMotion(context);
    final privateStep = state is FeedbackSheetPrivateFeedback;
    final content = FeedbackContentTransition(
      layoutBuilder: (current, previous) => feedbackStepLayout(current: current, previous: previous),
      child: privateStep
          ? FeedbackPrivateStep(key: _privateStepKey, onCancel: _close)
          : _RatingStep(
              key: const ValueKey("feedback-rating-step"),
              animation: reducedMotion ? const AlwaysStoppedAnimation(0) : _celebrationTimeline,
              state: state,
              onLove: _chooseLove,
              onCouldBeBetter: _chooseCouldBeBetter,
              onLeaveReview: _leaveReview,
              onClose: _close,
            ),
    );
    final sheet = Material(
      color: context.prego.colors.bgSurface2,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(PregoRadius.x8l)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsetsDirectional.only(bottom: keyboard),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.prego.colors.textPrimary,
                      borderRadius: BorderRadius.circular(PregoRadius.full),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: reducedMotion
                    ? content
                    : AnimatedSize(
                        duration: feedbackContentDuration,
                        curve: feedbackEaseOut,
                        alignment: Alignment.topCenter,
                        child: content,
                      ),
              ),
              SizedBox(height: keyboard > 0 ? 12 : math.max(32, MediaQuery.paddingOf(context).bottom + 16)),
            ],
          ),
        ),
      ),
    );
    return BlocListener<FeedbackSheetCubit, FeedbackSheetState>(
      listenWhen: (_, next) => next is FeedbackSheetPrivateFeedback && next.submission == FeedbackSubmission.sent,
      listener: (_, _) => _close(),
      child: sheet,
    );
  }
}

/// The hero stays in place while the answers below it hand over to the
/// review confirmation (D10), so the celebration settles into the question.
class const _RatingStep({
  super.key,
  required final Animation<double> animation,
  required final FeedbackSheetState state,
  required final VoidCallback onLove,
  required final VoidCallback onCouldBeBetter,
  required final VoidCallback onLeaveReview,
  required final VoidCallback onClose,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final answering = state is FeedbackSheetRating;
    final confirming = state is FeedbackSheetReviewConfirmation || state is FeedbackSheetReviewAccepted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            FeedbackRatingHero(animation: animation),
            Positioned(
              right: -2,
              top: -1,
              child: IconButton(
                key: const ValueKey("feedback-close"),
                constraints: const BoxConstraints.tightFor(width: 52, height: 52),
                icon: Icon(
                  TablerRegular.x,
                  size: 20,
                  color: context.prego.colors.textTertiary,
                  semanticLabel: context.loc.feedbackClose,
                ),
                onPressed: onClose,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FeedbackContentTransition(
          layoutBuilder: (current, previous) => feedbackStepLayout(current: current, previous: previous),
          child: confirming
              ? _ReviewConfirmation(
                  key: const ValueKey("feedback-review-confirmation"),
                  onLeaveReview: state is FeedbackSheetReviewConfirmation ? onLeaveReview : null,
                  onNotNow: onClose,
                )
              : _RatingChoices(
                  key: const ValueKey("feedback-rating-choices"),
                  animation: animation,
                  onLove: answering ? onLove : null,
                  onCouldBeBetter: answering ? onCouldBeBetter : null,
                ),
        ),
      ],
    );
  }
}

class const _RatingChoices({
  super.key,
  required final Animation<double> animation,
  required final VoidCallback? onLove,
  required final VoidCallback? onCouldBeBetter,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 67),
          child: Align(
            alignment: Alignment.topCenter,
            child: Text(
              context.loc.feedbackRatingTitle,
              textAlign: TextAlign.center,
              style: prego.textTheme.textXl.medium,
            ),
          ),
        ),
        FeedbackLoveButton(animation: animation, onPressed: onLove),
        const SizedBox(height: 12),
        TextButton(
          key: const ValueKey("feedback-improve"),
          onPressed: onCouldBeBetter,
          // This Figma instance uses bgSurface4; the shared secondary
          // button's bgSecondary belongs to other existing screens.
          style: TextButton.styleFrom(
            backgroundColor: prego.colors.bgSurface4,
            disabledBackgroundColor: prego.colors.bgSurface4,
            foregroundColor: prego.colors.textSecondary,
            disabledForegroundColor: prego.colors.textSecondary,
            textStyle: prego.textTheme.textMd.bold,
            minimumSize: const Size(double.infinity, 52),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: StadiumBorder(side: BorderSide(color: prego.colors.borderSecondary)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.loc.feedbackCouldBeBetter),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

/// D10: every jump to a store page is confirmed first, because leaving the
/// app must never be a surprise.
class const _ReviewConfirmation({
  super.key,
  required final VoidCallback? onLeaveReview,
  required final VoidCallback onNotNow,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final store = defaultTargetPlatform == TargetPlatform.iOS ? loc.feedbackStoreAppStore : loc.feedbackStoreGooglePlay;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(loc.feedbackReviewTitle, textAlign: TextAlign.center, style: prego.textTheme.textXl.medium),
        const SizedBox(height: PregoSpacing.md),
        Text(
          loc.feedbackReviewBody(store),
          textAlign: TextAlign.center,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.x3l),
        PregoButtonsSolid(
          key: const ValueKey("feedback-leave-review"),
          label: loc.feedbackLeaveReview,
          hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
          size: PregoButtonsSolidSize.xl,
          fullWidth: true,
          onPressed: onLeaveReview,
        ),
        const SizedBox(height: 12),
        PregoButtonsSolid(
          key: const ValueKey("feedback-not-now"),
          label: loc.feedbackNotNow,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.xl,
          fullWidth: true,
          onPressed: onNotNow,
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
