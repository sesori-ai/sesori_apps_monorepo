import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

import "../../extensions/build_context_x.dart";

/// Placeholder panel shown in the right pane when no session is selected
/// in wide split mode.
class EmptySessionDetailPanel extends StatelessWidget {
  const EmptySessionDetailPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return Center(
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
    );
  }
}
