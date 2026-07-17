import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

class NewSessionPluginChooser extends StatelessWidget {
  final List<PluginMetadata> plugins;
  final String? selectedPluginId;
  final bool isComposerDataLoading;
  final ValueChanged<String> onSelected;

  const NewSessionPluginChooser({
    super.key,
    required this.plugins,
    required this.selectedPluginId,
    required this.isComposerDataLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) return const SizedBox.shrink();
    final prego = context.prego;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(
            start: prego.spacing.md,
            bottom: prego.spacing.xs,
          ),
          child: Text(
            context.loc.newSessionPluginChooserLabel,
            style: prego.textTheme.textSm.bold.copyWith(color: prego.colors.textPrimary),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: prego.colors.bgSurface1,
            border: Border.all(color: prego.colors.borderSecondary),
            borderRadius: BorderRadius.circular(prego.radius.lg),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(prego.radius.lg),
            child: Column(
              children: [
                for (var index = 0; index < plugins.length; index++) ...[
                  if (index > 0) Divider(height: 1, color: prego.colors.borderSecondary),
                  _PluginChoice(
                    plugin: plugins[index],
                    isSelected: plugins[index].id == selectedPluginId,
                    isLoading: isComposerDataLoading && plugins[index].id == selectedPluginId,
                    onSelected: onSelected,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PluginChoice extends StatelessWidget {
  final PluginMetadata plugin;
  final bool isSelected;
  final bool isLoading;
  final ValueChanged<String> onSelected;

  const _PluginChoice({
    required this.plugin,
    required this.isSelected,
    required this.isLoading,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final isEnabled = plugin.isRoutable;
    final primaryTextColor = isSelected
        ? prego.colors.textPrimaryOnBrand
        : isEnabled
        ? prego.colors.textPrimary
        : prego.colors.textTertiary;
    final secondaryTextColor = isSelected ? prego.colors.textSecondaryOnBrand : prego.colors.textSecondary;
    final iconColor = isSelected
        ? prego.colors.iconFgBrandOnBrand
        : isEnabled
        ? prego.colors.bgBrandSolid
        : prego.colors.textTertiary;
    final status = switch (plugin.state) {
      PluginLifecycleState.ready => null,
      PluginLifecycleState.degraded => context.loc.newSessionPluginDegraded,
      PluginLifecycleState.unavailable => context.loc.newSessionPluginUnavailable,
      PluginLifecycleState.failed => context.loc.newSessionPluginFailed,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      child: Material(
        color: isSelected ? prego.colors.bgBrandPrimary : prego.colors.bgSurface1.withValues(alpha: 0),
        child: InkWell(
          key: Key("new_session_plugin_${plugin.id}"),
          onTap: isEnabled ? () => onSelected(plugin.id) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: prego.spacing.md,
              vertical: prego.spacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 20,
                  color: iconColor,
                ),
                SizedBox(width: prego.spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plugin.displayName,
                              style: prego.textTheme.textSm.medium.copyWith(
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (isLoading) ...[
                            SizedBox(width: prego.spacing.sm),
                            SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: iconColor,
                                semanticsLabel: context.loc.newSessionPluginLoading,
                              ),
                            ),
                          ] else if (status != null)
                            Text(
                              status,
                              style: prego.textTheme.textXs.medium.copyWith(
                                color: isSelected
                                    ? prego.colors.textSecondaryOnBrand
                                    : plugin.state == PluginLifecycleState.degraded
                                    ? prego.colors.textBrandPrimary
                                    : prego.colors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                      if (plugin.actionHint case final hint?) ...[
                        SizedBox(height: prego.spacing.xs),
                        Text(
                          hint,
                          style: prego.textTheme.textXs.regular.copyWith(
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
