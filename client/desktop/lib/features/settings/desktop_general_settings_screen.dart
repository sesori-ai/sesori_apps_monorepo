import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/desktop_update_configuration.dart";
import "../../core/external_link.dart";
import "desktop_update_section.dart";

/// App-wide preferences, without the mobile settings navigation rows.
class const DesktopGeneralSettingsScreen({super.key}) extends StatefulWidget {
  @override
  State<DesktopGeneralSettingsScreen> createState() => _DesktopGeneralSettingsScreenState();
}

class _DesktopGeneralSettingsScreenState() extends State<DesktopGeneralSettingsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<BridgeControlCubit>().refreshLaunchAtLogin());
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final control = context.watch<BridgeControlCubit>();
    final state = control.state;
    return SettingsWindowPage(
      onRefresh: null,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.xl,
              children: [
                SettingsSection(
                  title: loc.settingsSectionAppearance,
                  child: PregoGroupedRows(
                    children: [
                      PregoGroupedRow(
                        icon: TablerRegular.palette,
                        // A wrap rather than a trailing slot: at large text sizes the
                        // segments drop below the label instead of overflowing.
                        title: SizedBox(
                          width: double.infinity,
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: PregoSpacing.md,
                            runSpacing: PregoSpacing.sm,
                            children: [Text(loc.desktopSettingsTheme), const _ThemeSegments()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PregoGroupedRows(
                  children: [
                    MergeSemantics(
                      child: PregoGroupedRow(
                        icon: TablerRegular.power,
                        title: Text(loc.desktopSettingsLaunchAtLogin),
                        subtitle: Text(loc.desktopSettingsLaunchAtLoginDescription),
                        trailing: PregoSwitch(
                          value: state.launchAtLoginEnabled,
                          onChanged: state.activity.locksCommands
                              ? null
                              : (enabled) => unawaited(control.setLaunchAtLogin(enabled: enabled)),
                        ),
                      ),
                    ),
                  ],
                ),
                DesktopUpdateSection(
                  destination: resolveDesktopUpdateDestination(
                    encodedIdentity: const bool.hasEnvironment(DesktopBundleIdentity.defineName)
                        ? const String.fromEnvironment(DesktopBundleIdentity.defineName)
                        : null,
                    encodedChannel: const String.fromEnvironment(
                      DesktopReleaseChannel.defineName,
                      defaultValue: "stable",
                    ),
                  ),
                ),
                SettingsAppInfo(
                  onOpenRateSesori: null,
                  openSupportLink: ({required url}) =>
                      openDesktopExternalLink(url: url, mode: UrlLaunchMode.externalApp),
                  openLegalDocument: ({required document}) => openDesktopExternalLink(
                    url: LegalLinks.uriFor(document: document),
                    mode: UrlLaunchMode.externalApp,
                  ),
                  loadAppVersionInfo: _loadAppVersionInfo,
                  logo: null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Light, Dark and System as one segmented control: the desktop has room for
/// the words, so it skips the phone's preview tiles.
class const _ThemeSegments() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    final cubit = context.watch<AppearanceCubit>();
    final labels = {
      AppearanceMode.light: loc.settingsAppearanceLight,
      AppearanceMode.dark: loc.settingsAppearanceDark,
      AppearanceMode.system: loc.settingsAppearanceSystem,
    };
    // A Material, not a DecoratedBox: the selected segment's Ink paints on it.
    return Material(
      color: prego.colors.bgTertiary,
      borderRadius: BorderRadius.circular(PregoRadius.md),
      child: Padding(
        padding: const EdgeInsets.all(PregoSpacing.xxs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final MapEntry(key: mode, value: label) in labels.entries)
              Flexible(
                child: _ThemeSegment(
                  key: ValueKey("desktop-theme-${mode.name}"),
                  label: label,
                  selected: cubit.state == mode,
                  onPressed: () => cubit.select(mode: mode),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class const _ThemeSegment({
  super.key,
  required final String label,
  required final bool selected,
  required final VoidCallback onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final radius = BorderRadius.circular(PregoRadius.sm);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        mouseCursor: WidgetStateMouseCursor.clickable,
        onTap: onPressed,
        borderRadius: radius,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: PregoSpacing.md, vertical: PregoSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? prego.colors.bgSurface1 : null,
            borderRadius: radius,
            border: selected ? Border.all(color: prego.colors.borderSecondary) : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textSm.medium.copyWith(
              color: selected ? prego.colors.textPrimary : prego.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

Future<AppVersionInfo?> _loadAppVersionInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
  } on Object catch (error, stackTrace) {
    logw("Failed to load desktop package information", error, stackTrace);
    return null;
  }
}
