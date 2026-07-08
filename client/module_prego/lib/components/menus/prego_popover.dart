import "dart:async";

import "package:cue/cue.dart";
import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";

import "../../theme/prego_glass.dart";
import "../../theme/prego_theme.dart";
import "anchored_flat_panel.dart";

/// Builds the trigger that opens the popover. [toggle] opens (or, on the glass
/// path, toggles) the popup — wire it to the trigger's tap handler.
typedef PregoPopoverTriggerBuilder = Widget Function(BuildContext context, VoidCallback toggle);

/// Builds the popover body. [close] dismisses the popup — wire it to any
/// in-content dismiss affordance (a "Done" button). The transparent barrier
/// already closes the popover on an outside tap.
typedef PregoPopoverContentBuilder = Widget Function(BuildContext context, VoidCallback close);

/// A popover that anchors free-form content to its trigger, rendered
/// platform-appropriately.
///
/// On Apple platforms it is the `liquid_glass_widgets` [GlassPopover] — the
/// iOS-26 liquid-glass bubble that morphs out of the trigger. On Android, where
/// the glass shader + backdrop blur jank, it falls back to a flat Material
/// bubble anchored to the trigger and sprung in with the `cue` package (an
/// [AnchoredFlatPanel]) — same anchored-popup behaviour, zero shader cost.
///
/// Unlike [PregoAnchorMenu] (a list of selectable rows), the popover presents
/// arbitrary [contentBuilder] content — a tooltip, a short explanation, a mini
/// form. The same [triggerBuilder] and [contentBuilder] drive both paths; only
/// the rendering differs. See [glassEffectsEnabled] for the platform switch.
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
    return glassEffectsEnabled() ? _buildGlass(context) : _buildFlat(context);
  }

  // ── Glass path (Apple) ─────────────────────────────────────────────────────

  Widget _buildGlass(BuildContext context) {
    return GlassPopover(
      popoverWidth: popoverWidth,
      popoverBorderRadius: popoverBorderRadius,
      screenPadding: screenPadding,
      settings: LiquidGlassSettings(glassColor: context.prego.colors.buttonGlassPrimaryBackground),
      triggerBuilder: triggerBuilder,
      contentBuilder: contentBuilder,
    );
  }

  // ── Flat path (Android) ────────────────────────────────────────────────────

  Widget _buildFlat(BuildContext context) {
    return CueModalTransition(
      barrierColor: Colors.transparent,
      motion: const Spring.smooth(),
      reverseMotion: const Spring.snappy(),
      // No alignment: the panel positions itself from the trigger rect so it can
      // clamp to the screen edges, mirroring GlassPopover.autoAdjustToScreen.
      triggerBuilder: (context, showModal) =>
          triggerBuilder(context, () => unawaited(showModal())),
      builder: (context, triggerRect) => AnchoredFlatPanel(
        triggerRect: triggerRect,
        width: popoverWidth,
        // Content-sized (still bounded to stay on screen), matching the glass
        // path's intrinsic-height popover.
        height: null,
        borderRadius: popoverBorderRadius,
        screenPadding: screenPadding,
        childBuilder: contentBuilder,
      ),
    );
  }
}
