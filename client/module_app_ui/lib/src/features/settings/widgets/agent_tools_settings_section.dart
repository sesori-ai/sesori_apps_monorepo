import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../session_detail/widgets/transcript_motion.dart";
import "settings_section.dart";

/// How far rows dim while they cannot be changed.
const double _dimmedOpacity = 0.4;

/// The connected computer's Sesori tools: a master switch, then one switch
/// per tool group, dimmed while the master is off. Shown only for bridges
/// that report them; it grows in and folds away rather than appearing.
/// While the bridge reconnects it keeps the last switches, dimmed, so the
/// page below it does not jump.
class const AgentToolsSettingsSection({super.key}) extends StatefulWidget {
  @override
  State<AgentToolsSettingsSection> createState() => _AgentToolsSettingsSectionState();
}

class _AgentToolsSettingsSectionState() extends State<AgentToolsSettingsSection> {
  AgentToolsSettings? _lastShown;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final (AgentToolsSettings? shown, BridgeSettingsReady? ready) = switch (state) {
      BridgeSettingsReady(:final agentTools) => (agentTools, state),
      BridgeSettingsLoading() || BridgeSettingsDisconnected() => (_lastShown, null),
      BridgeSettingsUnsupported() || BridgeSettingsFailure() => (null, null),
    };
    _lastShown = shown;
    return AnimatedSize(
      duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
      curve: transcriptMotionCurve,
      alignment: AlignmentDirectional.topStart,
      child: switch (shown) {
        null => const SizedBox(width: double.infinity),
        final agentTools => Padding(
          padding: const EdgeInsets.only(top: PregoSpacing.xl),
          child: _AgentToolsCard(agentTools: agentTools, ready: ready),
        ),
      },
    );
  }
}

class const _AgentToolsCard({
  required final AgentToolsSettings agentTools,

  /// The settings these switches change, or null while the bridge is away.
  required final BridgeSettingsReady? ready,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final prego = context.prego;
    final ready = this.ready;
    final mutation = agentTools.mutation;
    final interactive =
        ready != null &&
        mutation is! AgentToolsMutationInProgress &&
        mutation is! AgentToolsMutationUncertain &&
        ready.yoloMutation is! YoloMutationInProgress &&
        ready.pluginWarmupMutation is! PluginWarmupMutationInProgress;
    final cubit = context.read<BridgeSettingsCubit>();

    String? failedSubtitle(AgentToolsSwitch target) => switch (mutation) {
      AgentToolsMutationFailed(target: final failed) when _same(failed, target) => loc.settingsAgentToolsUpdateFailed,
      AgentToolsMutationUncertain() when target is AgentToolsMasterSwitch => loc.settingsAgentToolsUncertain,
      _ => null,
    };

    Widget? trailing({required AgentToolsSwitch target, required bool value, required ValueChanged<bool> onChanged}) {
      return switch (mutation) {
        AgentToolsMutationInProgress(target: final busy) when _same(busy, target) => PregoActivityIndicator(
          color: prego.colors.fgBrandPrimary,
        ),
        AgentToolsMutationUncertain() when target is AgentToolsMasterSwitch => IconButton(
          key: const Key("agent_tools_retry"),
          tooltip: loc.settingsAgentToolsRetry,
          onPressed: ready == null ? null : cubit.refresh,
          icon: const Icon(TablerRegular.refresh),
        ),
        _ => PregoSwitch(value: value, onChanged: interactive ? onChanged : null),
      };
    }

    void setMaster({required bool enabled}) {
      final current = ready;
      if (current == null || !interactive) return;
      unawaited(cubit.updateAgentTools(enabled: enabled, expectedState: current));
    }

    void setGroup({required BridgeToolGroupSetting group, required bool enabled}) {
      final current = ready;
      if (current == null || !interactive) return;
      unawaited(cubit.updateToolGroup(id: group.id, enabled: enabled, expectedState: current));
    }

    // A tap on a group the master holds off answers with why, never a dead tap.
    void explainOff({required BridgeToolGroupSetting group}) => PregoPopupAlertPresenter.of(context).show(
      title: loc.settingsAgentToolsOff(group.title),
      variant: PregoPopupAlertsNotificationsVariant.info,
    );

    const master = AgentToolsMasterSwitch();
    final masterRow = MergeSemantics(
      child: PregoGroupedRow(
        key: const Key("agent_tools_setting"),
        icon: TablerRegular.tools,
        title: Text(loc.settingsAgentToolsTitle),
        subtitle: Text(failedSubtitle(master) ?? loc.settingsAgentToolsDescription),
        trailing: trailing(
          target: master,
          value: agentTools.enabled,
          onChanged: (enabled) => setMaster(enabled: enabled),
        ),
        onTap: interactive ? () => setMaster(enabled: !agentTools.enabled) : null,
      ),
    );
    final groupRows = [
      for (final group in agentTools.groups)
        _groupRow(
          context: context,
          group: group,
          masterOn: agentTools.enabled,
          subtitle: failedSubtitle(AgentToolGroupSwitch(id: group.id)) ?? group.summary,
          trailing: trailing(
            target: AgentToolGroupSwitch(id: group.id),
            value: group.enabled,
            onChanged: (enabled) => setGroup(group: group, enabled: enabled),
          ),
          onTap: ready == null
              ? null
              : !agentTools.enabled
              ? () => explainOff(group: group)
              : interactive
              ? () => setGroup(group: group, enabled: !group.enabled)
              : null,
        ),
    ];
    return SettingsSection(
      title: loc.settingsAgentToolsSection,
      child: Opacity(
        opacity: ready == null ? _dimmedOpacity : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: PregoSpacing.md,
          children: [
            PregoGroupedRows(children: [masterRow, ...groupRows]),
            Text(
              loc.settingsAgentToolsFootnote,
              style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  /// A group's row. While the master is off it dims, and its switch takes no
  /// taps so the row's tap can say why.
  Widget _groupRow({
    required BuildContext context,
    required BridgeToolGroupSetting group,
    required bool masterOn,
    required String subtitle,
    required Widget? trailing,
    required VoidCallback? onTap,
  }) {
    return AnimatedOpacity(
      key: Key("agent_tool_group_${group.id}"),
      opacity: masterOn ? 1 : _dimmedOpacity,
      duration: context.isReducedMotion ? Duration.zero : transcriptMotionDuration,
      curve: transcriptMotionCurve,
      child: MergeSemantics(
        child: PregoGroupedRow(
          title: Text(group.title),
          subtitle: Text(subtitle),
          trailing: IgnorePointer(ignoring: !masterOn, child: trailing),
          onTap: onTap,
        ),
      ),
    );
  }

  static bool _same(AgentToolsSwitch a, AgentToolsSwitch b) => switch ((a, b)) {
    (AgentToolsMasterSwitch(), AgentToolsMasterSwitch()) => true,
    (AgentToolGroupSwitch(id: final x), AgentToolGroupSwitch(id: final y)) => x == y,
    _ => false,
  };
}
