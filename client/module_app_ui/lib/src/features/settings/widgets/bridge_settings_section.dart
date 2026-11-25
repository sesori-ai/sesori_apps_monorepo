import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../../widgets/bridge_update_sheet.dart";
import "../../../widgets/computer_menu.dart";
import "../../session_detail/widgets/yolo_chip.dart";
import "computer_settings_entry.dart";
import "settings_section.dart";

/// How far the rows dim while no bridge is connected.
const double _offlineRowsOpacity = 0.4;

/// The computer the app works on, followed by the settings that apply to that
/// computer only.
class const BridgeSettingsSection({
  super.key,
  required final String title,

  /// A quiet sentence between the computer entry and the settings card, or
  /// null for none.
  required final String? description,

  /// Opens harness management, or null where the surface gives harnesses a
  /// place of their own.
  required final VoidCallback? onOpenHarnesses,

  /// Opens Settings › Projects, or null where the surface gives projects a
  /// place of their own.
  required final VoidCallback? onOpenProjects,

  /// Opens Archived, or null where the surface gives Archived a row of its
  /// own.
  required final VoidCallback? onOpenArchived,

  /// Opens Scheduled, or null where the surface gives Scheduled a row of its
  /// own.
  required final VoidCallback? onOpenScheduled,

  /// Switches to a computer picked from the computer entry's menu.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Opens the Computers page from the computer entry's menu.
  required final VoidCallback onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    // The row waits out a reload or a dropped connection instead of closing
    // and opening again under the finger.
    final showReleaseTrack = switch (state) {
      BridgeSettingsReady(:final releaseTrack) => releaseTrack != null,
      BridgeSettingsLoading(:final hasReleaseTrack) ||
      BridgeSettingsDisconnected(:final hasReleaseTrack) ||
      BridgeSettingsFailure(:final hasReleaseTrack) => hasReleaseTrack,
      BridgeSettingsUnsupported() => false,
    };
    final offline = state is BridgeSettingsDisconnected;
    final onOpenHarnesses = this.onOpenHarnesses;
    final onOpenProjects = this.onOpenProjects;
    final onOpenArchived = this.onOpenArchived;
    final onOpenScheduled = this.onOpenScheduled;
    // Keyed, so a row that comes with the loaded settings, such as Internal
    // builds, opens in place instead of snapping in.
    final bridgeRows = <(String, Widget)>[
      if (onOpenHarnesses != null)
        (
          "harnesses",
          PregoGroupedRow(
            icon: TablerRegular.plug,
            title: Text(context.loc.settingsHarnessesTitle),
            trailing: const Icon(TablerRegular.chevron_right),
            onTap: offline ? null : onOpenHarnesses,
          ),
        ),
      if (onOpenProjects != null)
        (
          "projects",
          PregoGroupedRow(
            key: const Key("settings_projects"),
            icon: TablerRegular.folder,
            title: Text(context.loc.settingsProjectsTitle),
            trailing: const Icon(TablerRegular.chevron_right),
            onTap: offline ? null : onOpenProjects,
          ),
        ),
      if (onOpenArchived != null)
        (
          "archived",
          PregoGroupedRow(
            key: const Key("settings_archived"),
            icon: TablerRegular.archive,
            title: Text(context.loc.archivedSessionsTitle),
            trailing: const Icon(TablerRegular.chevron_right),
            onTap: offline ? null : onOpenArchived,
          ),
        ),
      if (onOpenScheduled != null)
        (
          "scheduled",
          PregoGroupedRow(
            key: const Key("settings_scheduled"),
            icon: TablerRegular.calendar_time,
            title: Text(context.loc.scheduledTasksTitle),
            trailing: const Icon(TablerRegular.chevron_right),
            onTap: offline ? null : onOpenScheduled,
          ),
        ),
      ("yolo", const _YoloSettingsRow()),
      ("plugin_warmup", const _PluginWarmupSettingsRow()),
      if (showReleaseTrack) ("release_track", const _ReleaseTrackSettingsRow()),
    ];
    // Offline, one line above the group says why every row, Harnesses,
    // Projects, Archived and Scheduled included, is dimmed and disabled, in place of the
    // rows each saying it.
    final description = offline ? context.loc.settingsBridgeOffline : this.description;
    return SettingsSection(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ComputerSettingsEntry(onSwitchComputer: onSwitchComputer, onManageComputers: onManageComputers),
          if (description != null) ...[
            Text(
              description,
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textTertiary),
            ),
            const SizedBox(height: PregoSpacing.md),
          ],
          PregoGroupedRows(
            children: [
              PregoAnimatedList<(String, Widget)>(
                items: bridgeRows,
                itemKey: (row) => ValueKey(row.$1),
                itemBuilder: (context, index, row) => PregoGroupedRowPosition(
                  isLast: index == bridgeRows.length - 1,
                  child: Opacity(opacity: offline ? _offlineRowsOpacity : 1, child: row.$2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class const _YoloSettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final ready = state is BridgeSettingsReady ? state : null;
    final interactive =
        ready != null &&
        ready.yoloMutation is! YoloMutationInProgress &&
        ready.yoloMutation is! YoloMutationUncertain &&
        ready.yoloMutation is! YoloMutationUnsupported &&
        ready.pluginWarmupMutation is! PluginWarmupMutationInProgress &&
        ready.releaseTrack?.mutation is! ReleaseTrackMutationInProgress;
    final bridgeOutdated = switch (state) {
      BridgeSettingsReady(yoloMutation: YoloMutationUnsupported()) || BridgeSettingsUnsupported() => true,
      BridgeSettingsReady() ||
      BridgeSettingsLoading() ||
      BridgeSettingsDisconnected() ||
      BridgeSettingsFailure() => false,
    };

    void toggle({required bool enabled}) {
      final current = ready;
      if (current == null || !interactive) return;
      unawaited(context.read<BridgeSettingsCubit>().updateYolo(enabled: enabled, expectedState: current));
    }

    return MergeSemantics(
      child: PregoGroupedRow(
        key: const Key("yolo_setting"),
        icon: YoloChip.icon,
        title: Text(context.loc.settingsYoloTitle),
        subtitle: Text(_yoloDescription(context: context, state: state)),
        trailing: switch (state) {
          BridgeSettingsLoading() ||
          BridgeSettingsReady(yoloMutation: YoloMutationInProgress()) => const PregoActivityIndicator(color: null),
          BridgeSettingsReady(yoloMutation: YoloMutationUnsupported()) ||
          BridgeSettingsUnsupported() => const BridgeUpdateRowTrailing(),
          BridgeSettingsFailure() || BridgeSettingsReady(yoloMutation: YoloMutationUncertain()) => IconButton(
            key: const Key("yolo_retry"),
            tooltip: context.loc.settingsYoloRetry,
            onPressed: context.read<BridgeSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
          BridgeSettingsReady(:final yoloEnabled) => PregoSwitch(
            key: const Key("yolo_switch"),
            value: yoloEnabled,
            onChanged: interactive ? (enabled) => toggle(enabled: enabled) : null,
          ),
          BridgeSettingsDisconnected() => null,
        },
        onTap: bridgeOutdated
            ? () => unawaited(showBridgeUpdateSheet(context: context))
            : !interactive
            ? null
            : () => toggle(enabled: !ready.yoloEnabled),
      ),
    );
  }
}

class const _PluginWarmupSettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final ready = state is BridgeSettingsReady ? state : null;
    final enabled = switch (ready?.pluginWarmupMutation) {
      PluginWarmupMutationIdle(:final enabled) || PluginWarmupMutationFailed(:final enabled) => enabled,
      PluginWarmupMutationInProgress() ||
      PluginWarmupMutationUncertain() ||
      PluginWarmupMutationUnsupported() ||
      null => null,
    };
    final interactive =
        ready != null &&
        enabled != null &&
        ready.yoloMutation is! YoloMutationInProgress &&
        ready.releaseTrack?.mutation is! ReleaseTrackMutationInProgress;
    final bridgeOutdated = switch (state) {
      BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUnsupported()) ||
      BridgeSettingsUnsupported() => true,
      BridgeSettingsReady() ||
      BridgeSettingsLoading() ||
      BridgeSettingsDisconnected() ||
      BridgeSettingsFailure() => false,
    };

    void toggle({required bool enabled}) {
      final current = ready;
      if (current == null || !interactive) return;
      unawaited(
        context.read<BridgeSettingsCubit>().updatePluginWarmup(
          enabled: enabled,
          expectedState: current,
        ),
      );
    }

    return MergeSemantics(
      child: PregoGroupedRow(
        key: const Key("plugin_warmup_setting"),
        icon: TablerRegular.rocket,
        title: Text(context.loc.settingsPluginWarmupTitle),
        subtitle: Text(_pluginWarmupDescription(context: context, state: state)),
        trailing: switch (state) {
          BridgeSettingsLoading() || BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationInProgress()) =>
            PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
          BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUnsupported()) ||
          BridgeSettingsUnsupported() => const BridgeUpdateRowTrailing(),
          BridgeSettingsReady(
            pluginWarmupMutation: PluginWarmupMutationIdle(:final enabled) ||
                PluginWarmupMutationFailed(:final enabled),
          ) =>
            PregoSwitch(
              key: const Key("plugin_warmup_switch"),
              value: enabled,
              onChanged: interactive ? (enabled) => toggle(enabled: enabled) : null,
            ),
          BridgeSettingsDisconnected() => null,
          BridgeSettingsFailure() ||
          BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUncertain()) => IconButton(
            key: const Key("plugin_warmup_retry"),
            tooltip: context.loc.settingsPluginWarmupRetry,
            onPressed: context.read<BridgeSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
        },
        onTap: bridgeOutdated
            ? () => unawaited(showBridgeUpdateSheet(context: context))
            : enabled == null || !interactive
            ? null
            : () => toggle(enabled: !enabled),
      ),
    );
  }
}

/// Whether the bridge's auto-updater also takes internal pre-releases. Shown
/// only for a bridge that updates itself and reports its track; it waits out a
/// reload or a dropped connection like the rows above it.
class const _ReleaseTrackSettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final ready = state is BridgeSettingsReady ? state : null;
    final releaseTrack = ready?.releaseTrack;
    final interactive =
        ready != null &&
        ready.yoloMutation is! YoloMutationInProgress &&
        ready.pluginWarmupMutation is! PluginWarmupMutationInProgress &&
        switch (releaseTrack?.mutation) {
          ReleaseTrackMutationIdle() || ReleaseTrackMutationFailed() => true,
          ReleaseTrackMutationInProgress() || ReleaseTrackMutationUncertain() || null => false,
        };

    void toggle({required bool internalBuilds}) {
      if (ready == null || !interactive) return;
      unawaited(
        context.read<BridgeSettingsCubit>().updateReleaseTrack(internalBuilds: internalBuilds, expectedState: ready),
      );
    }

    return MergeSemantics(
      child: PregoGroupedRow(
        key: const Key("release_track_setting"),
        icon: TablerRegular.flask,
        title: Text(context.loc.settingsReleaseTrackTitle),
        subtitle: Text(switch (releaseTrack?.mutation) {
          ReleaseTrackMutationUncertain() => context.loc.settingsReleaseTrackUncertain,
          ReleaseTrackMutationFailed() => context.loc.settingsReleaseTrackUpdateFailed,
          ReleaseTrackMutationIdle() ||
          ReleaseTrackMutationInProgress() ||
          null => context.loc.settingsReleaseTrackDescription,
        }),
        trailing: switch (state) {
          BridgeSettingsLoading() ||
          BridgeSettingsReady(
            releaseTrack: ReleaseTrackSettings(mutation: ReleaseTrackMutationInProgress()),
          ) => PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
          BridgeSettingsReady(
            releaseTrack: ReleaseTrackSettings(
              :final internalBuilds,
              mutation: ReleaseTrackMutationIdle() || ReleaseTrackMutationFailed(),
            ),
          ) =>
            PregoSwitch(
              key: const Key("release_track_switch"),
              value: internalBuilds,
              onChanged: interactive ? (internalBuilds) => toggle(internalBuilds: internalBuilds) : null,
            ),
          BridgeSettingsFailure() ||
          BridgeSettingsReady(
            releaseTrack: ReleaseTrackSettings(mutation: ReleaseTrackMutationUncertain()),
          ) => IconButton(
            key: const Key("release_track_retry"),
            tooltip: context.loc.settingsReleaseTrackRetry,
            onPressed: context.read<BridgeSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
          // Leaving: the bridge no longer reports a track.
          BridgeSettingsReady(releaseTrack: null) ||
          BridgeSettingsDisconnected() ||
          BridgeSettingsUnsupported() => null,
        },
        onTap: switch (releaseTrack) {
          ReleaseTrackSettings(:final internalBuilds) when interactive => () => toggle(internalBuilds: !internalBuilds),
          _ => null,
        },
      ),
    );
  }
}

String _pluginWarmupDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsUnsupported() ||
    BridgeSettingsReady(
      pluginWarmupMutation: PluginWarmupMutationUnsupported(),
    ) => context.loc.settingsPluginWarmupUnsupported,
    BridgeSettingsFailure() => context.loc.settingsPluginWarmupLoadFailed,
    BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUncertain()) =>
      context.loc.settingsPluginWarmupUncertain,
    BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationFailed()) =>
      context.loc.settingsPluginWarmupUpdateFailed,
    BridgeSettingsLoading() ||
    BridgeSettingsReady() ||
    BridgeSettingsDisconnected() => context.loc.settingsPluginWarmupDescription,
  };
}

String _yoloDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsUnsupported() ||
    BridgeSettingsReady(yoloMutation: YoloMutationUnsupported()) => context.loc.settingsYoloUnsupported,
    BridgeSettingsFailure() => context.loc.settingsYoloLoadFailed,
    BridgeSettingsReady(yoloMutation: YoloMutationUncertain()) => context.loc.settingsYoloUncertain,
    BridgeSettingsReady(yoloMutation: YoloMutationFailed()) => context.loc.settingsYoloUpdateFailed,
    BridgeSettingsLoading() ||
    BridgeSettingsReady() ||
    BridgeSettingsDisconnected() => context.loc.settingsYoloDescription,
  };
}
