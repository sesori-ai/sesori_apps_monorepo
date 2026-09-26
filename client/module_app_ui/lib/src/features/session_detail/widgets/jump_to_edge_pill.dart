import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Floating pill overlay shown over a detached scrollable, inviting the
/// user to jump back to the follow edge (top or bottom depending on
/// scrollable orientation).
///
/// Bottom-anchored, horizontally centered. Intended to be stacked as
/// an overlay (returned from `FollowDetachScrollable.detachedOverlayBuilder`).
///
/// [tapTargetKey] is applied to the `InkWell` so tests can locate the
/// tappable region directly; the widget's own [key] is for outer
/// element reconciliation.
class const JumpToEdgePill({
  super.key,
  required final Key? tapTargetKey,
  required final String label,
  required final VoidCallback onTap,

  /// Extra distance lifted above the bottom edge so the pill clears a floating
  /// composer overlaid on the scrollable. Zero when nothing overlays the bottom
  /// (e.g. the read-only variant).
  required final double bottomInset,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Positioned(
      bottom: 12 + bottomInset,
      left: 16,
      right: 16,
      child: Center(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(PregoRadius.x3l),
          color: prego.colors.bgSurface3,
          child: InkWell(
            mouseCursor: WidgetStateMouseCursor.clickable,
            key: tapTargetKey,
            borderRadius: BorderRadius.circular(PregoRadius.x3l),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(TablerRegular.arrow_down, size: PregoIconSize.sm, color: prego.colors.textPrimary),
                  const SizedBox(width: 6),
                  // Bounded so large text scales or a narrow pane ellipsize the
                  // label instead of overflowing the pill.
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textSm.bold.copyWith(color: prego.colors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
