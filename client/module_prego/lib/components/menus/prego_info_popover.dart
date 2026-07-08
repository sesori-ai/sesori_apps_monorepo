import "package:flutter/material.dart";

import "../../theme/prego_theme.dart";
import "prego_popover.dart";

/// A small informational popover anchored to its trigger, rendered
/// platform-appropriately.
///
/// It presents a single block of explanatory [message] text — not a list of
/// actions — in a popup that morphs out of its trigger. It builds on
/// [PregoPopover], so it renders the iOS-26 liquid-glass bubble on Apple
/// platforms and a flat, `cue`-sprung Material bubble on Android, where the
/// glass shader janks; the platform switch, anchoring, and screen-edge clamping
/// are all inherited from [PregoPopover].
///
/// Use it for the "ⓘ" info affordances next to a label, where tapping should
/// reveal a one-line explanation and tapping outside dismisses it.
class PregoInfoPopover extends StatelessWidget {
  const PregoInfoPopover({
    super.key,
    required this.triggerBuilder,
    required this.message,
    this.popoverWidth = 260,
  });

  /// Builds the tappable trigger (e.g. an info icon). The provided callback
  /// opens the popover — wire it to the trigger's tap handler.
  final PregoPopoverTriggerBuilder triggerBuilder;

  /// The explanatory text shown inside the popover.
  final String message;

  /// Width of the open popover bubble.
  final double popoverWidth;

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
