import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:theme_prego/module_prego.dart";

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
        DesktopUpdateIdle() || DesktopUpdateManagedBySystem() => const _AutomaticUpdateRows(ready: null),
        final DesktopUpdateReady ready => _AutomaticUpdateRows(ready: ready),
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

/// The toggle stays put; below it, "Check for updates" and "Restart to update"
/// share one row slot and cross-fade, so nothing jumps when an update arrives.
class const _AutomaticUpdateRows({required final DesktopUpdateReady? ready}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<DesktopUpdateCubit>();
    final enabled = cubit.state.automaticUpdates.isEnabled;
    final ready = this.ready;
    final Duration duration = context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 200);

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
          isLast: true,
          child: AnimatedSize(
            duration: duration,
            curve: Curves.easeOut,
            alignment: AlignmentDirectional.topCenter,
            child: AnimatedSwitcher(
              duration: duration,
              // Retained fade-out content must neither intercept clicks nor re-announce.
              layoutBuilder: (current, previous) => Stack(
                alignment: AlignmentDirectional.topCenter,
                children: [
                  for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child)),
                  ?current,
                ],
              ),
              child: switch (ready) {
                final DesktopUpdateReady ready => _RestartToUpdateRow(key: const ValueKey("restart"), ready: ready),
                null => const _CheckForUpdatesRow(key: ValueKey("check")),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class const _CheckForUpdatesRow({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.watch<DesktopUpdateCubit>();
    final check = cubit.state.check;
    final String subtitle = switch (check) {
      DesktopUpdateCheckStatus.checking => loc.desktopUpdatesChecking,
      DesktopUpdateCheckStatus.upToDate => loc.desktopUpdatesUpToDate,
      DesktopUpdateCheckStatus.failed => loc.desktopUpdatesCheckFailed,
      DesktopUpdateCheckStatus.idle =>
        cubit.installKind == DesktopInstallKind.linuxPackage
            ? loc.desktopUpdatesCheckPackageDescription
            : loc.desktopUpdatesCheckDescription,
    };
    final Duration duration = context.isReducedMotion ? Duration.zero : const Duration(milliseconds: 180);
    return PregoGroupedRow(
      icon: TablerRegular.search,
      title: Text(loc.desktopUpdatesCheck),
      subtitle: AnimatedSize(
        duration: duration,
        curve: Curves.easeOut,
        alignment: AlignmentDirectional.topStart,
        child: AnimatedSwitcher(
          duration: duration,
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topStart,
            children: [
              for (final child in previous) ExcludeSemantics(child: child),
              ?current,
            ],
          ),
          child: Text(subtitle, key: ValueKey(check)),
        ),
      ),
      trailing: AnimatedSwitcher(
        duration: duration,
        child: switch (check) {
          DesktopUpdateCheckStatus.checking => const SizedBox.square(
            key: ValueKey("checking"),
            dimension: 18,
            child: PregoActivityIndicator(color: null),
          ),
          DesktopUpdateCheckStatus.upToDate => const Icon(TablerRegular.check, key: ValueKey("up-to-date")),
          DesktopUpdateCheckStatus.idle || DesktopUpdateCheckStatus.failed => const SizedBox.shrink(),
        },
      ),
      // Stays tappable while checking so focus and hover remain; the cubit ignores repeat taps.
      onTap: () => unawaited(cubit.checkForUpdates()),
    );
  }
}

class const _RestartToUpdateRow({super.key, required final DesktopUpdateReady ready}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final exitLocked = context.select((BridgeControlCubit control) => control.state.activity.locksCommands);
    final String version = switch (ready.internalBuildNumber) {
      final int build => loc.desktopUpdatesInternalBuildVersion(ready.version, build),
      null => ready.version,
    };
    return PregoGroupedRow(
      icon: TablerRegular.rotate_clockwise,
      title: Text(loc.desktopUpdatesRestart),
      subtitle: Text(loc.desktopUpdatesRestartDescription(version)),
      onTap: exitLocked ? null : () => unawaited(context.read<BridgeControlCubit>().restartToUpdate()),
    );
  }
}
