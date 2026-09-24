import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";

/// The new session card's harness row: the harness the session will run on,
/// over an anchored menu listing every harness this bridge reports.
///
/// The menu's header repeats the section name and hangs the settings shortcut
/// off it, so a harness that needs setting up is one tap from where the user
/// noticed the problem. Its last row refreshes the options, next to the
/// harnesses they belong to.
class const NewSessionPluginChooser({
  super.key,
  required final List<PluginMetadata> plugins,
  required final String? selectedPluginId,
  required final bool isSelectionEnabled,

  /// Whether the options are still loading: the row shimmers its value, or a
  /// placeholder bar while there is no harness to name yet.
  required final bool isLoading,
  required final ValueChanged<String> onSelected,
  required final VoidCallback onSettingsPressed,

  /// Reloads the harnesses and their options. Null disables the menu's refresh
  /// row.
  required final VoidCallback? onRefreshPressed,
}) extends StatelessWidget {
  /// Height of the menu's header row (Figma: 52).
  static const double _menuHeaderHeight = 52;

  /// Width of the open menu, shared with the composer's pickers.
  static const double _menuWidth = 240;

  /// Widest the harness name may grow before it ellipsizes.
  static const double _valueMaxWidth = 200;

  /// Size of the placeholder bar standing in for the harness name.
  static const double _placeholderWidth = 96;
  static const double _placeholderHeight = 12;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final onRefreshPressed = this.onRefreshPressed;

    PluginMetadata? selected;
    for (final plugin in plugins) {
      if (plugin.id == selectedPluginId) selected = plugin;
    }

    return PregoAnchorMenu(
      flat: true,
      menuWidth: _menuWidth,
      acquireOpenLease: null,
      triggerBuilder: (context, toggle) => _HarnessRow(
        name: selected?.displayName,
        isLoading: isLoading,
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
            shortcutLabel: null,
            isEnabled: isSelectionEnabled && plugin.isRoutable,
            leading: PregoBrandLogo(
              pluginId: plugin.id,
              color: context.prego.colors.textSecondary,
            ),
            onTap: () => onSelected(plugin.id),
          ),
        if (plugins.isNotEmpty) const PregoMenuDivider(),
        PregoMenuItem(
          key: const Key("new_session_options_refresh"),
          title: loc.newSessionOptionsRefresh,
          subtitle: null,
          isSelected: false,
          shortcutLabel: null,
          leadingIcon: TablerRegular.refresh,
          isEnabled: onRefreshPressed != null,
          onTap: onRefreshPressed ?? () {},
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

/// The "Harness" row: the picked harness' name over an open-menu chevron.
class const _HarnessRow({
  required final String? name,
  required final bool isLoading,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final name = this.name;

    final Widget? value = switch ((name, isLoading)) {
      (null, true) => const PregoSkeletonBar(
        height: NewSessionPluginChooser._placeholderHeight,
        width: NewSessionPluginChooser._placeholderWidth,
      ),
      (null, false) => null,
      (final String name, _) => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: NewSessionPluginChooser._valueMaxWidth),
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textSecondary),
        ),
      ),
    };

    // The row announces what it picks and what is picked as one button; the
    // visible text is excluded so the name is not read a second time.
    return Semantics(
      button: true,
      label: loc.newSessionPluginChooserLabel,
      value: isLoading ? loc.newSessionOptionsLoadingSemantics : name,
      onTap: onPressed,
      excludeSemantics: true,
      child: PregoGroupedRow(
        key: const Key("new_session_plugin_trigger"),
        title: Text(loc.newSessionPluginChooserLabel),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: PregoSpacing.xs,
          children: [
            if (value != null)
              Flexible(
                child: isLoading ? PregoShimmer(appearDelay: Duration.zero, child: value) : value,
              ),
            const Icon(TablerRegular.chevron_right),
          ],
        ),
        onTap: onPressed,
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
                size: PregoIconSize.md,
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
