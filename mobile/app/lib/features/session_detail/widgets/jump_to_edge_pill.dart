import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

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
class JumpToEdgePill extends StatelessWidget {
  final Key? tapTargetKey;
  final String label;
  final VoidCallback onTap;

  const JumpToEdgePill({
    super.key,
    required this.tapTargetKey,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(20),
          color: zyra.colors.bgBrandPrimary,
          child: InkWell(
            key: tapTargetKey,
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: zyra.colors.bgBrandPrimaryAlt),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: zyra.textTheme.textSm.bold.copyWith(
                      color: zyra.colors.bgBrandPrimaryAlt,
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
