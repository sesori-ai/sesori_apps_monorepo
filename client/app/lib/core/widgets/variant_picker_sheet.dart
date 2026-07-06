import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";

class VariantPickerSheet extends StatelessWidget {
  final String? selectedVariantId;
  final List<SessionVariant> availableVariants;
  final ValueChanged<SessionVariant?> onVariantChanged;

  const VariantPickerSheet({
    super.key,
    required this.selectedVariantId,
    required this.availableVariants,
    required this.onVariantChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String? selectedVariantId,
    required List<SessionVariant> availableVariants,
    required ValueChanged<SessionVariant?> onVariantChanged,
  }) {
    return showPregoBottomSheet<void>(
      context: context,
      title: context.loc.sessionDetailPickerVariant,
      // Full-bleed tiles; each ListTile carries its own horizontal padding.
      contentPadding: EdgeInsetsDirectional.zero,
      builder: (_) => VariantPickerSheet(
        selectedVariantId: selectedVariantId,
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
    final loc = context.loc;

    // Transparent Material so the tiles' ink paints on top of the sheet
    // surface instead of behind it on the modal's transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _VariantTile(
            label: loc.sessionDetailVariantDefault,
            isSelected: selectedVariantId == null,
            onTap: () => onVariantChanged(null),
          ),
          for (final variant in availableVariants)
            _VariantTile(
              label: variant.id,
              isSelected: variant.id == selectedVariantId,
              onTap: () => onVariantChanged(variant),
            ),
          const SizedBox(height: 8),
        ],
      ),
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
    final prego = context.prego;

    return ListTile(
      dense: true,
      title: Text(label),
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: prego.colors.bgBrandSolid)
          : Icon(Icons.radio_button_unchecked, color: prego.colors.borderPrimary),
      onTap: onTap,
    );
  }
}
