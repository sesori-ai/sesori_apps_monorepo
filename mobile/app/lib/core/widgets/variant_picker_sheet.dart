import "package:flutter/material.dart";
import "package:go_router/go_router.dart";

import "../extensions/build_context_x.dart";
import "app_modal_bottom_sheet.dart";

class VariantPickerSheet extends StatelessWidget {
  final String? selectedVariant;
  final List<String> availableVariants;
  final ValueChanged<String?> onVariantChanged;

  const VariantPickerSheet({
    super.key,
    required this.selectedVariant,
    required this.availableVariants,
    required this.onVariantChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String? selectedVariant,
    required List<String> availableVariants,
    required ValueChanged<String?> onVariantChanged,
  }) {
    return showAppModalBottomSheet(
      context: context,
      builder: (_) => VariantPickerSheet(
        selectedVariant: selectedVariant,
        availableVariants: availableVariants,
        onVariantChanged: (variant) {
          onVariantChanged(variant);
          if (context.mounted) {
            context.pop();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Column(
      mainAxisSize: MainAxisSize.min,
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
            loc.sessionDetailPickerVariant,
            style: theme.textTheme.titleMedium,
          ),
        ),
        _VariantTile(
          label: loc.sessionDetailVariantDefault,
          isSelected: selectedVariant == null,
          onTap: () => onVariantChanged(null),
        ),
        for (final variant in availableVariants)
          _VariantTile(
            label: variant,
            isSelected: variant == selectedVariant,
            onTap: () => onVariantChanged(variant),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _VariantTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _VariantTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      title: Text(label),
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary)
          : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}
