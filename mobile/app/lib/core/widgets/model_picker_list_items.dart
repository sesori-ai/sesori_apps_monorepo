import "package:flutter/material.dart";
import "package:theme_zyra/module_zyra.dart";

/// Provider name header above a group of models in the model picker list.
class ModelPickerProviderHeader extends StatelessWidget {
  final String name;

  const ModelPickerProviderHeader({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Text(
        name,
        style: zyra.textTheme.textXs.medium.copyWith(
          color: zyra.colors.bgBrandSolid,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A single selectable model row in the model picker list.
class ModelPickerModelTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const ModelPickerModelTile({
    super.key,
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final zyra = context.zyra;

    return ListTile(
      dense: true,
      title: Text(name),
      subtitle: switch (subtitle) {
        final text? => Text(text),
        null => null,
      },
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: zyra.colors.bgBrandSolid)
          : Icon(Icons.radio_button_unchecked, color: zyra.colors.borderPrimary),
      onTap: onTap,
    );
  }
}
