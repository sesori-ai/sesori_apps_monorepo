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
class const DesktopGeneralSettingsScreen({super.key, required final VoidCallback onClose}) extends StatefulWidget {
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
    return PregoGlassScaffold(
      title: loc.desktopSettingsGeneral,
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      actions: [
        PregoButtonsIconGlass(icon: TablerRegular.x, semanticLabel: loc.settingsClose, onPressed: widget.onClose),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PregoSpacing.xl),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.xl,
              children: [
                SettingsSection(title: loc.settingsSectionAppearance, child: const AppearancePicker()),
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

Future<AppVersionInfo?> _loadAppVersionInfo() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
  } on Object catch (error, stackTrace) {
    logw("Failed to load desktop package information", error, stackTrace);
    return null;
  }
}
