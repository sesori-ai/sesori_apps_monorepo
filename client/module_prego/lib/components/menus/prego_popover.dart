import "dart:async";

import "package:cue/cue.dart";
import "package:material_ui/material_ui.dart";

import "anchored_flat_panel.dart";

/// Builds the trigger that opens the popover. [toggle] opens the popup — wire it
/// to the trigger's tap handler.
typedef PregoPopoverTriggerBuilder = Widget Function(BuildContext context, VoidCallback toggle);

/// Builds the popover body. [close] dismisses the popup — wire it to any
/// in-content dismiss affordance (a "Done" button). The transparent barrier
/// already closes the popover on an outside tap.
typedef PregoPopoverContentBuilder = Widget Function(BuildContext context, VoidCallback close);

/// A popover that anchors free-form content to its trigger.
///
/// It renders a flat Material bubble anchored to the trigger and sprung in with
/// the `cue` package (an [AnchoredFlatPanel]) on every platform. We deliberately
/// keep it flat rather than the iOS-26 liquid-glass bubble even on Apple: for the
/// small, informational popups this backs, the glass shader reads as too heavy
/// and distracting, and staying flat also sidesteps the Android glass jank.
///
/// Unlike [PregoAnchorMenu] (a list of selectable rows), the popover presents
/// arbitrary [contentBuilder] content — a tooltip, a short explanation, a mini
/// form. It anchors to the trigger, springs in, and clamps to the screen edges.
class const PregoPopover({
  super.key,

  /// Builds the tappable trigger. The provided callback opens the popover.
  required final PregoPopoverTriggerBuilder triggerBuilder,

  /// Builds the popover body. The provided callback dismisses it.
  required final PregoPopoverContentBuilder contentBuilder,

  /// Width of the open popover. It narrows to fit the screen, so
  /// [double.infinity] spans it.
  final double popoverWidth = 280,

  /// Caps how tall the open popover grows. Null lets it grow with its content;
  /// either way it stays within the room beside the trigger.
  required final double? popoverMaxHeight,

  /// Whether the content brings its own scroll view, such as a search field
  /// pinned above a list, instead of the popover scrolling it.
  required final bool contentScrolls,

  /// Called once the popover has closed, however it was dismissed.
  required final VoidCallback? onClosed,

  /// Corner radius of the open popover.
  final double popoverBorderRadius = 24,

  /// Minimum gap kept between the popover and the screen edges.
  final EdgeInsets screenPadding = const EdgeInsets.all(12),
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // `cue` still imports the SDK Material library and reads its localizations.
    // ignore: deprecated_member_use
    return MaterialUiCompatibilityBridge(
      child: CueModalTransition(
        barrierColor: Colors.transparent,
        motion: const Spring.smooth(),
        reverseMotion: const Spring.snappy(),
        // No alignment: the panel positions itself from the trigger rect so it can
        // clamp to the screen edges.
        triggerBuilder: (context, showModal) => triggerBuilder(
          context,
          () => unawaited(showModal().then((_) => onClosed?.call())),
        ),
        builder: (context, triggerRect) => AnchoredFlatPanel(
          triggerRect: triggerRect,
          placement: AnchoredPanelPlacement.besideTrigger,
          width: popoverWidth,
          maxHeight: popoverMaxHeight,
          borderRadius: popoverBorderRadius,
          screenPadding: screenPadding,
          contentScrolls: contentScrolls,
          childBuilder: contentBuilder,
        ),
      ),
    );
  }
}
