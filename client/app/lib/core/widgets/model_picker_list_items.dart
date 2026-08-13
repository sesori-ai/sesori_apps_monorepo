import "package:flutter/material.dart";
import "package:theme_prego/module_prego.dart";

/// Provider name header above a group of models in the model picker list.
class const ModelPickerProviderHeader({super.key, required final String name}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 4),
      child: Text(
        name,
        style: prego.textTheme.textXs.medium.copyWith(
          color: prego.colors.bgBrandSolid,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A single selectable model row in the model picker list.
class const ModelPickerModelTile({
  super.key,
  required final String name,
  required final String? subtitle,
  required final bool isSelected,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;

    return ListTile(
      dense: true,
      // Exposes the selection state to assistive technology (TalkBack /
      // VoiceOver); the radio icon below only communicates it visually.
      selected: isSelected,
      title: Text(name),
      subtitle: switch (subtitle) {
        final text? => Text(text),
        null => null,
      },
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: prego.colors.bgBrandSolid)
          : Icon(Icons.radio_button_unchecked, color: prego.colors.borderPrimary),
      onTap: onTap,
    );
  }
}
