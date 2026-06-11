import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../extensions/build_context_x.dart";
import "../sesori_background_widget.dart";

/// Placeholder panel shown in the right pane when no session is selected
/// in wide split mode.
class EmptySessionDetailPanel extends StatelessWidget {
  const EmptySessionDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    final brightness = Theme.of(context).brightness;
    final scrimColor = brightness == Brightness.light ? Colors.white : Colors.black;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          const Positioned.fill(child: SesoriBackgroundWidget()),
          Positioned.fill(
            child: ColoredBox(color: scrimColor.withValues(alpha: 0.85)),
          ),
          Center(
            key: const Key("empty-session-detail-panel"),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: zyra.colors.textTertiary,
                ),
                SizedBox(height: zyra.spacing.md),
                Text(
                  context.loc.emptySessionDetailTitle,
                  style: zyra.textTheme.textMd.bold.copyWith(
                    color: zyra.colors.textSecondary,
                  ),
                ),
                SizedBox(height: zyra.spacing.xs),
                Text(
                  context.loc.emptySessionDetailSubtitle,
                  style: zyra.textTheme.textSm.regular.copyWith(
                    color: zyra.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
