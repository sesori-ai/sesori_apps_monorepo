import "package:flutter/widgets.dart";
import "package:sesori_motion_tuning/sesori_motion_tuning.dart";

/// Replay scenes are preview-owned; the reusable editor receives named targets.
enum FeedbackMotionScene() {
  sheetOpen,
  sheetClose,
  stars,
  step,
  composer,
  issues,
  voice,
  notice,
  flow,
}

const _source = "feedback_flow_playbook.dart";

const feedbackSheetOpenDuration = MotionDuration(
  id: "feedback.sheet.open.duration",
  label: "Opening duration",
  source: "$_source · _PreviewLauncherState._syncSheetMotion",
  initialValue: Duration(milliseconds: 250),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackSheetCloseDuration = MotionDuration(
  id: "feedback.sheet.close.duration",
  label: "Closing duration",
  source: "$_source · _PreviewLauncherState._syncSheetMotion",
  initialValue: Duration(milliseconds: 200),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackStarDuration = MotionDuration(
  id: "feedback.stars.duration",
  label: "Bounce duration",
  source: "$_source · _Stars / _FeedbackSheet",
  initialValue: Duration(milliseconds: 280),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackContentDuration = MotionDuration(
  id: "feedback.content.duration",
  label: "Content in · all feedback content transitions",
  source: "$_source · _FeedbackContentTransition / _FeedbackSheet",
  initialValue: Duration(milliseconds: 220),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackContentReverseDuration = MotionDuration(
  id: "feedback.content.reverseDuration",
  label: "Content out · all feedback content transitions",
  source: "$_source · _FeedbackContentTransition",
  initialValue: Duration(milliseconds: 160),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackControlDuration = MotionDuration(
  id: "feedback.controls.duration",
  label: "Control in · composer, actions, issue pills, presses",
  source: "$_source · _FeedbackActionTransition / _FeedbackPress",
  initialValue: Duration(milliseconds: 160),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackControlReverseDuration = MotionDuration(
  id: "feedback.controls.reverseDuration",
  label: "Control out · actions and presses",
  source: "$_source · _FeedbackActionTransition / _FeedbackPress",
  initialValue: Duration(milliseconds: 100),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackPressFadeDuration = MotionDuration(
  id: "feedback.press.fadeDuration",
  label: "Press fade · all feedback controls",
  source: "$_source · _FeedbackPress",
  initialValue: Duration(milliseconds: 100),
  min: Duration.zero,
  max: Duration(milliseconds: 2000),
);

const feedbackSheetCurve = MotionCurve(
  id: "feedback.sheet.open.curve",
  label: "Opening easing",
  source: "$_source · _feedbackDrawerCurve",
  initialValue: MotionEasing.drawer,
);

const feedbackSheetReverseCurve = MotionCurve(
  id: "feedback.sheet.close.curve",
  label: "Closing easing · reversed by the sheet",
  source: "$_source · _feedbackEaseOut.flipped",
  initialValue: MotionEasing.smooth,
);

const feedbackStarCurve = MotionCurve(
  id: "feedback.stars.curve",
  label: "Dip and final easing",
  source: "$_source · _tapScale · dip and final stage",
  initialValue: MotionEasing.easeOutCubic,
);

const feedbackStarSettleCurve = MotionCurve(
  id: "feedback.stars.settleCurve",
  label: "Pop and settling easing",
  source: "$_source · _tapScale · middle stages",
  initialValue: MotionEasing.easeInOutCubic,
);

const feedbackContentCurve = MotionCurve(
  id: "feedback.content.curve",
  label: "Content easing · all feedback content transitions",
  source: "$_source · _FeedbackContentTransition / _FeedbackSheet",
  initialValue: MotionEasing.smooth,
);

const feedbackControlCurve = MotionCurve(
  id: "feedback.controls.curve",
  label: "Control easing · composer, actions, issue pills, presses",
  source: "$_source · _feedbackEaseOut",
  initialValue: MotionEasing.smooth,
);

const feedbackStarDip = MotionNumber(
  id: "feedback.stars.dip",
  label: "Dip scale",
  source: "$_source · _tapScale",
  initialValue: 0.88,
  min: 0.7,
  max: 1,
  step: 0.01,
);

const feedbackStarPeak = MotionNumber(
  id: "feedback.stars.peak",
  label: "Peak scale",
  source: "$_source · _tapScale",
  initialValue: 1.18,
  min: 1,
  max: 1.4,
  step: 0.01,
);

const feedbackStarSettle = MotionNumber(
  id: "feedback.stars.settle",
  label: "Settling scale",
  source: "$_source · _tapScale",
  initialValue: 0.98,
  min: 0.85,
  max: 1.1,
  step: 0.01,
);

const feedbackContentOffset = MotionNumber(
  id: "feedback.content.offset",
  label: "Content slide · fraction of its height",
  source: "$_source · _FeedbackContentTransition",
  initialValue: 0.03,
  min: 0,
  max: 0.15,
  step: 0.005,
);

const feedbackActionScale = MotionNumber(
  id: "feedback.actions.scale",
  label: "Action starting scale · voice and send",
  source: "$_source · _FeedbackActionTransition",
  initialValue: 0.95,
  min: 0.8,
  max: 1,
  step: 0.01,
);

const feedbackPressScale = MotionNumber(
  id: "feedback.press.scale",
  label: "Pressed scale · all feedback controls",
  source: "$_source · _FeedbackPress",
  initialValue: 0.97,
  min: 0.8,
  max: 1,
  step: 0.01,
);

const feedbackPressOpacity = MotionNumber(
  id: "feedback.press.opacity",
  label: "Pressed opacity · all feedback controls",
  source: "$_source · _FeedbackPress",
  initialValue: 0.8,
  min: 0.3,
  max: 1,
  step: 0.01,
);

// Shared descriptor instances deliberately tune each explicitly named group.
// A preset contains each parameter ID once even when several scenes expose it.
const feedbackMotionTargets = <MotionTarget>[
  MotionTarget(
    id: "sheetOpen",
    label: "Feedback sheet · Open",
    parameters: [feedbackSheetOpenDuration, feedbackSheetCurve],
  ),
  MotionTarget(
    id: "sheetClose",
    label: "Feedback sheet · Close",
    parameters: [feedbackSheetCloseDuration, feedbackSheetReverseCurve],
  ),
  MotionTarget(
    id: "stars",
    label: "Rating stars · Tap bounce",
    parameters: [
      feedbackStarDuration,
      feedbackStarDip,
      feedbackStarPeak,
      feedbackStarSettle,
      feedbackStarCurve,
      feedbackStarSettleCurve,
    ],
  ),
  MotionTarget(
    id: "step",
    label: "Rating → Written feedback · Transition",
    parameters: [feedbackContentDuration, feedbackContentReverseDuration, feedbackContentOffset, feedbackContentCurve],
  ),
  MotionTarget(
    id: "composer",
    label: "Composer · Surface and actions",
    parameters: [
      feedbackControlDuration,
      feedbackControlReverseDuration,
      feedbackControlCurve,
      feedbackActionScale,
      feedbackPressScale,
      feedbackPressOpacity,
      feedbackPressFadeDuration,
    ],
  ),
  MotionTarget(
    id: "issues",
    label: "Issue pills · Selection and press",
    parameters: [
      feedbackControlDuration,
      feedbackControlReverseDuration,
      feedbackControlCurve,
      feedbackPressScale,
      feedbackPressOpacity,
      feedbackPressFadeDuration,
    ],
  ),
  MotionTarget(
    id: "voice",
    label: "Voice controls · State changes",
    parameters: [
      feedbackContentDuration,
      feedbackContentReverseDuration,
      feedbackContentOffset,
      feedbackContentCurve,
      feedbackControlDuration,
      feedbackControlReverseDuration,
      feedbackControlCurve,
      feedbackActionScale,
    ],
  ),
  MotionTarget(
    id: "notice",
    label: "Feedback result · Notice transition",
    parameters: [feedbackContentDuration, feedbackContentReverseDuration, feedbackContentOffset, feedbackContentCurve],
  ),
  MotionTarget(
    id: "flow",
    label: "Whole feedback flow · Simulated sequence",
    parameters: [
      feedbackSheetOpenDuration,
      feedbackSheetCloseDuration,
      feedbackStarDuration,
      feedbackContentDuration,
      feedbackContentReverseDuration,
      feedbackControlDuration,
      feedbackControlReverseDuration,
      feedbackPressFadeDuration,
    ],
  ),
];

/// The existing preview reads captured settings without owning editor state.
class const FeedbackMotionScope({
  super.key,
  required final MotionSnapshot values,
  required final FeedbackMotionScene? scene,
  required final int revision,
  required super.child,
}) extends InheritedWidget {
  static FeedbackMotionScope? maybeOf({required BuildContext context}) =>
      context.dependOnInheritedWidgetOfExactType<FeedbackMotionScope>();

  static MotionSnapshot valuesOf({required BuildContext context}) =>
      maybeOf(context: context)?.values ?? const MotionSnapshot();

  @override
  bool updateShouldNotify(FeedbackMotionScope oldWidget) =>
      values != oldWidget.values || scene != oldWidget.scene || revision != oldWidget.revision;
}

/// Normal previews remain independent of editor selection and geometry.
Widget feedbackMotionRegion({
  required BuildContext context,
  required FeedbackMotionScene scene,
  required Widget child,
}) => FeedbackMotionScope.maybeOf(context: context) == null
    ? child
    : MotionTargetRegion(targetId: scene.name, child: child);
