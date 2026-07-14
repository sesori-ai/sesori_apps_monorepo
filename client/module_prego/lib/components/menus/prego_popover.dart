import "dart:async";

import "package:cue/cue.dart";
import "package:flutter/material.dart";

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
class PregoPopover extends StatelessWidget {
  const PregoPopover({
    super.key,
    required this.triggerBuilder,
    required this.contentBuilder,
    this.popoverWidth = 280,
    this.popoverBorderRadius = 24,
    this.screenPadding = const EdgeInsets.all(12),
  });

  /// Builds the tappable trigger. The provided callback opens the popover.
  final PregoPopoverTriggerBuilder triggerBuilder;

  /// Builds the popover body. The provided callback dismisses it.
  final PregoPopoverContentBuilder contentBuilder;

  /// Width of the open popover.
  final double popoverWidth;

  /// Corner radius of the open popover.
  final double popoverBorderRadius;

  /// Minimum gap kept between the popover and the screen edges.
  final EdgeInsets screenPadding;

  @override
  Widget build(BuildContext context) {
    return CueModalTransition(
      barrierColor: Colors.transparent,
      motion: const Spring.smooth(),
      reverseMotion: const Spring.snappy(),
      // No alignment: the panel positions itself from the trigger rect so it can
      // clamp to the screen edges.
      triggerBuilder: (context, showModal) =>
          triggerBuilder(context, () => unawaited(showModal())),
      builder: (context, triggerRect) => AnchoredFlatPanel(
        triggerRect: triggerRect,
        width: popoverWidth,
        // Content-sized (still bounded to stay on screen).
        maxHeight: null,
        borderRadius: popoverBorderRadius,
        screenPadding: screenPadding,
        childBuilder: contentBuilder,
      ),
    );
  }
}
