import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../extensions/build_context_x.dart";
import "app_modal_bottom_sheet.dart";

class EffortPickerSheet extends StatelessWidget {
  final SessionEffort selectedEffort;
  final ValueChanged<SessionEffort> onEffortChanged;

  const EffortPickerSheet({
    super.key,
    required this.selectedEffort,
    required this.onEffortChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required SessionEffort selectedEffort,
    required ValueChanged<SessionEffort> onEffortChanged,
  }) {
    return showAppModalBottomSheet(
      context: context,
      builder: (_) => EffortPickerSheet(
        selectedEffort: selectedEffort,
        onEffortChanged: (effort) {
          onEffortChanged(effort);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: .min,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsetsDirectional.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            context.loc.sessionDetailPickerEffort,
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final effort in SessionEffort.values)
          ListTile(
            dense: true,
            title: Text(_labelFor(context: context, effort: effort)),
            leading: effort == selectedEffort
                ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary)
                : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline),
            onTap: () => onEffortChanged(effort),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _labelFor({required BuildContext context, required SessionEffort effort}) {
    final loc = context.loc;
    return switch (effort) {
      SessionEffort.low => loc.sessionDetailEffortLow,
      SessionEffort.medium => loc.sessionDetailEffortMedium,
      SessionEffort.max => loc.sessionDetailEffortMax,
    };
  }
}
