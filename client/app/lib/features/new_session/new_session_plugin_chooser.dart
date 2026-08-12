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
class const NewSessionPluginChooser({
  super.key,
  required final List<PluginMetadata> plugins,
  required final String? selectedPluginId,
  required final bool isSelectionEnabled,
  required final ValueChanged<String> onSelected,
  required final VoidCallback onSettingsPressed,
}) extends StatelessWidget {
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

    // Aligned out here rather than inside the trigger: the menu anchors to the
    // trigger's painted bounds, and a trigger stretched across the row would
    // hang the popup off the middle of the screen instead of under the name.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: PregoAnchorMenu(
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
      ),
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
class const _HarnessTrigger({
  required final String? pluginId,
  required final String label,
  required final double height,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    final pluginId = this.pluginId;

    // The row's own text names the harness but not what the choice is for, so
    // the control announces both: the label says what it picks, the value says
    // what is picked. The visible text is excluded to keep the harness name
    // from being read a second time as a loose node.
    return Semantics(
      button: true,
      label: context.loc.newSessionPluginChooserLabel,
      value: label,
      excludeSemantics: true,
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
    );
  }
}

/// The menu's first row: the section name and the shortcut into harness
/// settings, where harnesses are enabled, restarted and set up.
class const _HarnessesMenuHeader({required final double height, required final VoidCallback onSettingsPressed})
    extends StatelessWidget {
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
            // Flutter's tooltip OverlayPortal cannot be laid out below this
            // anchored menu's follower layer (flutter/flutter#178522). Keep the
            // accessible label without creating that nested overlay.
            IconButton(
              key: const Key("new_session_harness_settings"),
              onPressed: onSettingsPressed,
              icon: Icon(
                TablerRegular.adjustments_horizontal,
                size: 20,
                color: prego.colors.textTertiary,
                semanticLabel: loc.newSessionHarnessSettings,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
