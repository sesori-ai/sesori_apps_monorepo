import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// Wraps a single chat row so that a horizontal "peek" gesture on the
/// transcript reveals the message's timestamp in a gutter on the right —
/// the iMessage / Telegram interaction.
///
/// Driven by a shared [progress] animation (0 = closed, 1 = fully
/// revealed) owned by the message list, so every visible row moves in
/// lockstep from a single drag. The row content slides left by
/// `progress * maxReveal` while the timestamp gutter slides in from the
/// right by the same amount: the two meet exactly at the content's new
/// right edge, so the timestamp never overlaps the message. The label is
/// bottom-aligned within the gutter so it reads as belonging to the foot
/// of its message.
///
/// The gutter is anchored to the reading column, not to the row's own
/// content, so every row — whatever its width and whatever kind of
/// message it holds — reveals its timestamp on one shared alignment
/// line.
///
/// Rows without a timestamp ([createdAtMs] is null — e.g. the synthetic
/// retry-error row) still translate in lockstep but render no gutter.
class const MessageTimestampReveal({
  super.key,

  /// Shared reveal progress, clamped to `[0, 1]` at use.
  required final Animation<double> progress,

  /// Width of the timestamp gutter, and therefore the maximum distance
  /// the row content slides left.
  required final double maxReveal,

  /// Message creation time in milliseconds since the Unix epoch, or null
  /// when the row has no timestamp to show.
  required final int? createdAtMs,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final createdAtMs = this.createdAtMs;
    // Formatting is locale-dependent but progress-independent, so resolve
    // the label once here rather than inside the per-frame builder.
    final label = createdAtMs == null ? null : context.formatMessageTimestamp(createdAtMs);
    final prego = context.prego;
    final labelColor = prego.colors.textTertiary;

    // Fill the reading column even when the row's own content is narrower.
    // Every transcript row is wrapped in an `Align(widthFactor: 1)` that
    // loosens the width constraint, so without this the gutter below would
    // ride each message's own right edge and every row would reveal its
    // timestamp at a different x. The row content itself still receives the
    // same loose constraints from the Stack, so nothing stretches.
    return SizedBox(
      width: double.infinity,
      child: AnimatedBuilder(
        animation: progress,
        // The row content is the expensive part and does not depend on
        // progress, so build it once and let AnimatedBuilder reuse it.
        child: child,
        builder: (context, child) {
          final p = progress.value.clamp(0.0, 1.0);
          return Stack(
            // Unclipped so the gutter travels through the empty margin beside
            // the reading column on a wide pane, instead of being sliced
            // mid-window at the column's edge. On a pane with no margin the
            // scroll viewport clips it at the window edge, as on the phone.
            // Nothing is built while closed, so no label lingers in the
            // margin.
            clipBehavior: Clip.none,
            children: [
              if (label != null && p > 0)
                Positioned(
                  top: 0,
                  bottom: 0,
                  width: maxReveal,
                  // One full gutter beyond the column's right edge while
                  // closed; flush against that edge when fully revealed, so a
                  // settled reveal is never clipped at any window width.
                  right: -maxReveal * (1 - p),
                  child: Align(
                    // Bottom-aligned so the timestamp sits at the foot of the
                    // message it belongs to (matching the iMessage reveal),
                    // rather than floating at the row's vertical centre.
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 6),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        // Ellipsize rather than hard-clip so an unusually
                        // long label (e.g. a dated cross-year timestamp, or
                        // large text scaling) degrades gracefully instead of
                        // being silently cut mid-character.
                        overflow: TextOverflow.ellipsis,
                        style: prego.textTheme.textXs.regular.copyWith(
                          // Fades in over the travel, so a label crossing an
                          // empty margin materialises with the drag instead of
                          // appearing at full strength beside the column.
                          color: labelColor.withValues(alpha: labelColor.a * p),
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
      ),
    );
  }
}
