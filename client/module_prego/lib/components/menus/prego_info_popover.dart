import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";
import "prego_popover.dart";

/// A small informational popover anchored to its trigger, rendered
/// platform-appropriately.
///
/// It presents a single block of explanatory [message] text — not a list of
/// actions — in a flat, `cue`-sprung Material bubble anchored to its trigger. It
/// builds on [PregoPopover], inheriting its anchoring, spring, screen-edge
/// clamping, and flat-on-every-platform rendering.
///
/// Use it for the "ⓘ" info affordances next to a label, where tapping should
/// reveal a one-line explanation and tapping outside dismisses it.
class const PregoInfoPopover({
  super.key,

  /// Builds the tappable trigger (e.g. an info icon). The provided callback
  /// opens the popover — wire it to the trigger's tap handler.
  required final PregoPopoverTriggerBuilder triggerBuilder,

  /// The explanatory text shown inside the popover.
  required final String message,

  /// Width of the open popover bubble.
  final double popoverWidth = 260,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoPopover(
      popoverWidth: popoverWidth,
      popoverBorderRadius: 20,
      triggerBuilder: triggerBuilder,
      // A single free-form text block instead of tappable rows: the popover is
      // purely informational, so there is nothing to select — the barrier (tap
      // outside) is the only dismissal, so the `close` callback is unused.
      contentBuilder: (context, _) {
        final prego = context.prego;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message,
            style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textPrimary),
          ),
        );
      },
    );
  }
}
