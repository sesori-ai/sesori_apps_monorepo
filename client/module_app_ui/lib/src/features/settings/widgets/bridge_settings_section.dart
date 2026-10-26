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

  /// Switches to a computer picked from the computer entry's menu.
  required final ComputerSwitchCallback onSwitchComputer,

  /// Opens the Computers page from the computer entry's menu.
  required final VoidCallback onManageComputers,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final offline = state is BridgeSettingsDisconnected;
    final onOpenHarnesses = this.onOpenHarnesses;
    final onOpenProjects = this.onOpenProjects;
    final onOpenArchived = this.onOpenArchived;
    final bridgeRows = <Widget>[
      if (onOpenHarnesses != null)
        PregoGroupedRow(
          icon: TablerRegular.plug,
          title: Text(context.loc.settingsHarnessesTitle),
          trailing: const Icon(TablerRegular.chevron_right),
          onTap: offline ? null : onOpenHarnesses,
        ),
      if (onOpenProjects != null)
        PregoGroupedRow(
          key: const Key("settings_projects"),
          icon: TablerRegular.folder,
          title: Text(context.loc.settingsProjectsTitle),
          trailing: const Icon(TablerRegular.chevron_right),
          onTap: offline ? null : onOpenProjects,
        ),
      if (onOpenArchived != null)
        PregoGroupedRow(
          key: const Key("settings_archived"),
          icon: TablerRegular.archive,
          title: Text(context.loc.archivedSessionsTitle),
          trailing: const Icon(TablerRegular.chevron_right),
          onTap: offline ? null : onOpenArchived,
        ),
      const _YoloSettingsRow(),
      const _PluginWarmupSettingsRow(),
    ];
    // Offline, one line above the group says why every row, Harnesses,
    // Projects and Archived included, is dimmed and disabled, in place of the
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
              for (final row in bridgeRows) Opacity(opacity: offline ? _offlineRowsOpacity : 1, child: row),
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
        ready.pluginWarmupMutation is! PluginWarmupMutationInProgress;
    final bridgeOutdated = switch (state) {
      BridgeSettingsReady(yoloMutation: YoloMutationUnsupported()) || BridgeSettingsUnsupported() => true,
      BridgeSettingsReady() || BridgeSettingsLoading() || BridgeSettingsDisconnected() || BridgeSettingsFailure() =>
        false,
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
    final interactive = ready != null && enabled != null && ready.yoloMutation is! YoloMutationInProgress;
    final bridgeOutdated = switch (state) {
      BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUnsupported()) || BridgeSettingsUnsupported() =>
        true,
      BridgeSettingsReady() || BridgeSettingsLoading() || BridgeSettingsDisconnected() || BridgeSettingsFailure() =>
        false,
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

String _pluginWarmupDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() => context.loc.settingsPluginWarmupLoading,
    BridgeSettingsUnsupported() ||
    BridgeSettingsReady(
      pluginWarmupMutation: PluginWarmupMutationUnsupported(),
    ) => context.loc.settingsPluginWarmupUnsupported,
    BridgeSettingsFailure() => context.loc.settingsPluginWarmupLoadFailed,
    BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationUncertain()) =>
      context.loc.settingsPluginWarmupUncertain,
    BridgeSettingsReady(pluginWarmupMutation: PluginWarmupMutationFailed()) =>
      context.loc.settingsPluginWarmupUpdateFailed,
    BridgeSettingsReady() || BridgeSettingsDisconnected() => context.loc.settingsPluginWarmupDescription,
  };
}

String _yoloDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() => context.loc.settingsYoloLoading,
    BridgeSettingsUnsupported() ||
    BridgeSettingsReady(yoloMutation: YoloMutationUnsupported()) => context.loc.settingsYoloUnsupported,
    BridgeSettingsFailure() => context.loc.settingsYoloLoadFailed,
    BridgeSettingsReady(yoloMutation: YoloMutationUncertain()) => context.loc.settingsYoloUncertain,
    BridgeSettingsReady(yoloMutation: YoloMutationFailed()) => context.loc.settingsYoloUpdateFailed,
    BridgeSettingsReady() || BridgeSettingsDisconnected() => context.loc.settingsYoloDescription,
  };
}
