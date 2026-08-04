import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/extensions/build_context_x.dart";

/// The harness the new session will run on, shown as the picked harness' mark
/// and name over an anchored menu listing every harness this bridge reports.
///
/// The row carries no chrome of its own: the unfold caret is what says it can
/// be tapped, matching the Figma "Harness options" block (node 4435:16803).
/// The menu's header repeats the section name and hangs the settings shortcut
/// off it, so a harness that needs setting up is one tap from where the user
/// noticed the problem.
class NewSessionPluginChooser extends StatelessWidget {
  final List<PluginMetadata> plugins;
  final String? selectedPluginId;
  final bool isSelectionEnabled;
  final ValueChanged<String> onSelected;
  final VoidCallback onSettingsPressed;

  const NewSessionPluginChooser({
    super.key,
    required this.plugins,
    required this.selectedPluginId,
    required this.isSelectionEnabled,
    required this.onSelected,
    required this.onSettingsPressed,
  });

  /// Height of the trigger row and of the menu's header row (Figma: 40 / 52).
  static const double _triggerHeight = 40;
  static const double _menuHeaderHeight = 52;

  /// Width of the open menu, shared with the composer's pickers.
  static const double _menuWidth = 240;

  @override
  Widget build(BuildContext context) {
    if (plugins.isEmpty) return const SizedBox.shrink();
    final loc = context.loc;

    PluginMetadata? selected;
    for (final plugin in plugins) {
      if (plugin.id == selectedPluginId) selected = plugin;
    }

    return PregoAnchorMenu(
      // The trigger is flat, so the popup is too — a glass bubble hung off a
      // chrome-less row would read as belonging to something else.
      flat: true,
      menuWidth: _menuWidth,
      triggerBuilder: (context, toggle) => _HarnessTrigger(
        pluginId: selected?.id,
        label: selected?.displayName ?? loc.newSessionPluginChooserLabel,
        height: _triggerHeight,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuCustom(
          height: _menuHeaderHeight,
          builder: (context, close) => _HarnessesMenuHeader(
            height: _menuHeaderHeight,
            onSettingsPressed: () {
              close();
              onSettingsPressed();
            },
          ),
        ),
        for (final plugin in plugins)
          PregoMenuItem(
            key: Key("new_session_plugin_${plugin.id}"),
            title: plugin.displayName,
            subtitle: _lifecycleStatus(context, state: plugin.state),
            isSelected: plugin.id == selectedPluginId,
            isEnabled: isSelectionEnabled && plugin.isRoutable,
            leading: PregoBrandLogo(
              pluginId: plugin.id,
              color: context.prego.colors.textSecondary,
            ),
            onTap: () => onSelected(plugin.id),
          ),
      ],
    );
  }

  /// What a harness row says about itself below its name. A ready harness says
  /// nothing — the absence is the good news.
  static String? _lifecycleStatus(BuildContext context, {required PluginLifecycleState state}) => switch (state) {
    PluginLifecycleState.ready => null,
    PluginLifecycleState.degraded => context.loc.newSessionPluginDegraded,
    PluginLifecycleState.unavailable => context.loc.newSessionPluginUnavailable,
    PluginLifecycleState.failed => context.loc.newSessionPluginFailed,
  };
}

/// The picked harness' mark and name over an unfold caret.
class _HarnessTrigger extends StatelessWidget {
  final String? pluginId;
  final String label;
  final double height;
  final VoidCallback onPressed;

  const _HarnessTrigger({
    required this.pluginId,
    required this.label,
    required this.height,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    final pluginId = this.pluginId;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Semantics(
        button: true,
        label: context.loc.newSessionPluginChooserLabel,
        child: InkWell(
          key: const Key("new_session_plugin_trigger"),
          onTap: onPressed,
          borderRadius: borderRadius,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: prego.spacing.lg),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pluginId != null) ...[
                    PregoBrandLogo(pluginId: pluginId, color: prego.colors.textSecondary),
                    SizedBox(width: prego.spacing.sm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textSecondary),
                    ),
                  ),
                  SizedBox(width: prego.spacing.sm),
                  Icon(TablerRegular.selector, size: 16, color: prego.colors.textPrimary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The menu's first row: the section name and the shortcut into harness
/// settings, where harnesses are enabled, restarted and set up.
class _HarnessesMenuHeader extends StatelessWidget {
  final double height;
  final VoidCallback onSettingsPressed;

  const _HarnessesMenuHeader({required this.height, required this.onSettingsPressed});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: prego.spacing.xl, end: prego.spacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                loc.settingsHarnessesTitle,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ),
            IconButton(
              key: const Key("new_session_harness_settings"),
              onPressed: onSettingsPressed,
              icon: Icon(
                TablerRegular.adjustments_horizontal,
                size: 20,
                color: prego.colors.textTertiary,
              ),
              tooltip: loc.newSessionHarnessSettings,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
