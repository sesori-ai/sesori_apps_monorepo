import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../../core/extensions/build_context_x.dart";

/// Wraps a single chat row so that a horizontal "peek" gesture on the
/// transcript reveals the message's timestamp in a gutter on the right —
/// the iMessage / Telegram interaction.
///
/// Driven by a shared [progress] animation (0 = closed, 1 = fully
/// revealed) owned by the message list, so every visible row moves in
/// lockstep from a single drag. The row content slides left by
/// `progress * maxReveal` while the timestamp gutter slides in from
/// off-screen on the right by the same amount: the two meet exactly at
/// the content's new right edge, so the timestamp never overlaps the
/// message and never bleeds through transparent rows while closed.
///
/// Rows without a timestamp ([createdAtMs] is null — e.g. the synthetic
/// retry-error row) still translate in lockstep but render no gutter.
class MessageTimestampReveal extends StatelessWidget {
  /// Shared reveal progress, clamped to `[0, 1]` at use.
  final Animation<double> progress;

  /// Width of the timestamp gutter, and therefore the maximum distance
  /// the row content slides left.
  final double maxReveal;

  /// Message creation time in milliseconds since the Unix epoch, or null
  /// when the row has no timestamp to show.
  final int? createdAtMs;

  final Widget child;

  const MessageTimestampReveal({
    super.key,
    required this.progress,
    required this.maxReveal,
    required this.createdAtMs,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final createdAtMs = this.createdAtMs;
    // Formatting is locale-dependent but progress-independent, so resolve
    // the label once here rather than inside the per-frame builder.
    final label = createdAtMs == null ? null : context.formatMessageTimestamp(createdAtMs);
    final zyra = context.zyra;

    return AnimatedBuilder(
      animation: progress,
      // The row content is the expensive part and does not depend on
      // progress, so build it once and let AnimatedBuilder reuse it.
      child: child,
      builder: (context, child) {
        final p = progress.value.clamp(0.0, 1.0);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (label != null)
              Positioned(
                top: 0,
                bottom: 0,
                width: maxReveal,
                // Off-screen to the right while closed; flush against the
                // right edge when fully revealed.
                right: -maxReveal * (1 - p),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.clip,
                      style: zyra.textTheme.textXs.regular.copyWith(
                        color: zyra.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(-maxReveal * p, 0),
              child: child,
            ),
          ],
        );
      },
    );
  }
}
