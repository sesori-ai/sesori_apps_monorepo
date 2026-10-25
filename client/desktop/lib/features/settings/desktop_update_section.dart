import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/external_link.dart";

/// Renders [DesktopUpdateCubit]. "Restart to update" exits through
/// [BridgeControlCubit], which owns every quit.
class const DesktopUpdateSection({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final update = context.watch<DesktopUpdateCubit>().state.update;
    return SettingsSection(
      title: loc.desktopUpdatesTitle,
      child: switch (update) {
        DesktopUpdateManagedBySystem() => const _AutomaticUpdateRows(readyVersion: null),
        DesktopUpdateReady(:final version) => _AutomaticUpdateRows(readyVersion: version),
        DesktopUpdateManualDownload(:final downloadsUri) => PregoGroupedRows(
          children: [
            PregoGroupedRow(
              icon: TablerRegular.download,
              title: Text(loc.desktopUpdatesViewDownloads),
              subtitle: Text(loc.desktopUpdatesViewDownloadsDescription),
              onTap: () => unawaited(openDesktopExternalLink(url: downloadsUri, mode: UrlLaunchMode.externalApp)),
            ),
          ],
        ),
        DesktopUpdateUnavailable(reason: DesktopUpdateUnavailableReason.developmentBuild) => PregoGroupedRows(
          children: [
            PregoGroupedRow(
              icon: TablerRegular.download,
              title: Text(loc.desktopUpdatesDevelopmentBuild),
              subtitle: Text(loc.desktopUpdatesDevelopmentBuildDescription),
            ),
          ],
        ),
      },
    );
  }
}

/// The toggle and "Check for updates" stay put; "Restart to update" opens
/// below them once a newer version is installed.
class const _AutomaticUpdateRows({required final String? readyVersion}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<DesktopUpdateCubit>();
    final enabled = cubit.state.automaticUpdates.isEnabled;
    final exitLocked = context.select((BridgeControlCubit control) => control.state.activity.locksCommands);
    final readyVersion = this.readyVersion;

    void toggle({required bool enabled}) => unawaited(cubit.setAutomaticUpdates(enabled: enabled));

    return PregoGroupedRows(
      children: [
        MergeSemantics(
          child: PregoGroupedRow(
            icon: TablerRegular.refresh,
            title: Text(loc.desktopUpdatesAutomatic),
            subtitle: Text(loc.desktopUpdatesAutomaticDescription),
            trailing: PregoSwitch(
              value: enabled,
              onChanged: (enabled) => toggle(enabled: enabled),
            ),
            onTap: () => toggle(enabled: !enabled),
          ),
        ),
        PregoGroupedRowPosition(
          isLast: readyVersion == null,
          child: PregoGroupedRow(
            icon: TablerRegular.search,
            title: Text(loc.desktopUpdatesCheck),
            subtitle: Text(loc.desktopUpdatesCheckPackageDescription),
            onTap: cubit.checkForUpdates,
          ),
        ),
        PregoAnimatedList<String>(
          items: [?readyVersion],
          itemKey: (version) => ValueKey("desktop-restart-to-update-$version"),
          itemBuilder: (context, index, version) => PregoGroupedRowPosition(
            isLast: true,
            child: PregoGroupedRow(
              icon: TablerRegular.rotate_clockwise,
              title: Text(loc.desktopUpdatesRestart),
              subtitle: Text(loc.desktopUpdatesRestartDescription(version)),
              onTap: exitLocked ? null : () => unawaited(context.read<BridgeControlCubit>().restartToUpdate()),
            ),
          ),
        ),
      ],
    );
  }
}
