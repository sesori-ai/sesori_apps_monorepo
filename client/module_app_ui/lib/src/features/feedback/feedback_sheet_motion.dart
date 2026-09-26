import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

// Approved feedback-flow motion (preview #1361, signed off 2026-09-26).
const feedbackDrawerCurve = Cubic(0.32, 0.72, 0, 1);
const feedbackEaseOut = Cubic(0.23, 1, 0.32, 1);

const feedbackSheetOpenDuration = Duration(milliseconds: 250);
const feedbackSheetCloseDuration = Duration(milliseconds: 200);
const feedbackCelebrationDuration = Duration(milliseconds: 1500);
// The review question takes over once the love button's pink pop has peaked
// (~200ms), while the hero celebration keeps playing above it.
const feedbackCelebrationHandoff = Duration(milliseconds: 300);
// Without a confirmation, the sheet leaves for the OS review prompt once the
// button has settled back from pink and the hearts have risen, so the
// celebration still reads as intentional.
const feedbackReviewPromptCloseDelay = Duration(milliseconds: 800);
// The review question's arrival: the answers leave first, then the question
// rises into place, so the swap is legible rather than a crossfade.
const _stepInDuration = Duration(milliseconds: 360);
const _stepOutDuration = Duration(milliseconds: 180);
const _stepInDelay = Interval(0.25, 1, curve: feedbackEaseOut);
const _stepInOffset = 20.0;
const _stepOutOffset = -12.0;
// Content transitions: step changes and inline messages.
const feedbackContentDuration = Duration(milliseconds: 220);
const feedbackContentReverseDuration = Duration(milliseconds: 160);
const _contentOffset = 0.03;
// Controls: composer, issue pills and presses.
const feedbackControlDuration = Duration(milliseconds: 160);
const feedbackControlReverseDuration = Duration(milliseconds: 100);

/// Retire outgoing content without leaving duplicate hit targets or semantics.
class const FeedbackContentTransition({
  super.key,
  required final Widget child,
  final AnimatedSwitcherLayoutBuilder layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reducedMotion = prefersReducedMotion(context);
    return AnimatedSwitcher(
      duration: feedbackContentDuration,
      reverseDuration: feedbackContentReverseDuration,
      switchInCurve: feedbackEaseOut,
      switchOutCurve: feedbackEaseOut.flipped,
      layoutBuilder: (current, previous) => layoutBuilder(
        current,
        [for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child))],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: reducedMotion ? Offset.zero : const Offset(0, _contentOffset),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Hands one step over to the next: the outgoing step fades while lifting
/// away, then the incoming step fades in while rising into place. Reduce
/// Motion keeps the fades without travel.
class const FeedbackStepTransition({super.key, required final Widget child}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reducedMotion = prefersReducedMotion(context);
    return AnimatedSwitcher(
      duration: reducedMotion ? Duration.zero : _stepInDuration,
      reverseDuration: reducedMotion ? Duration.zero : _stepOutDuration,
      layoutBuilder: (current, previous) => feedbackStepLayout(
        current: current,
        previous: [for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child))],
      ),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          // The switcher reverses the outgoing child's animation.
          final leaving = animation.status == AnimationStatus.reverse;
          final progress = leaving
              ? feedbackEaseOut.flipped.transform(animation.value)
              : _stepInDelay.transform(animation.value);
          final travel = reducedMotion ? 0.0 : (leaving ? _stepOutOffset : _stepInOffset) * (1 - progress);
          return Opacity(
            opacity: progress,
            child: Transform.translate(offset: Offset(0, travel), child: child),
          );
        },
      ),
      child: child,
    );
  }
}

/// Sizes the incoming step immediately so its fade and the sheet resize share
/// one transition. Outgoing content keeps its intrinsic size while fading out.
Widget feedbackStepLayout({required Widget? current, required List<Widget> previous}) => Stack(
  alignment: Alignment.topCenter,
  clipBehavior: Clip.none,
  children: [
    for (final child in previous)
      Positioned.fill(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: child,
        ),
      ),
    ?current,
  ],
);
