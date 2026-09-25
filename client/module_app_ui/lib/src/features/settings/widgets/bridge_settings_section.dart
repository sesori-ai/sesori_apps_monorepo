import "dart:async";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "../../session_detail/widgets/yolo_chip.dart";
import "settings_section.dart";

/// How far the rows dim while no bridge is connected.
const double _offlineRowsOpacity = 0.4;

class const BridgeSettingsSection({
  super.key,
  required final String title,

  /// A quiet sentence between the header and the card, or null for none.
  required final String? description,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final rows = PregoGroupedRows(
      children: [
        const _YoloSettingsRow(),
        const _PluginWarmupSettingsRow(),
        PregoGroupedRow(
          key: const Key("pull_request_refresh_interval"),
          icon: TablerRegular.refresh,
          title: Text(context.loc.settingsPullRequestRefreshTitle),
          subtitle: Text(_description(context: context, state: state)),
          trailing: _trailing(context: context, state: state),
          onTap: switch (state) {
            BridgeSettingsReady(:final pullRequestRefreshMutation)
                when pullRequestRefreshMutation is! PullRequestRefreshMutationInProgress &&
                    pullRequestRefreshMutation is! PullRequestRefreshMutationUncertain &&
                    pullRequestRefreshMutation is! PullRequestRefreshMutationUnsupported &&
                    (state is! BridgeSettingsReadyFull ||
                        (state.yoloMutation is! YoloMutationInProgress &&
                            state.pluginWarmupMutation is! PluginWarmupMutationInProgress)) =>
              () => unawaited(_editInterval(context: context, state: state)),
            BridgeSettingsLoading() ||
            BridgeSettingsDisconnected() ||
            BridgeSettingsUnsupported() ||
            BridgeSettingsFailure() ||
            BridgeSettingsReady() => null,
          },
        ),
      ],
    );
    // Offline, one line above the group says why every row is dimmed, in
    // place of the rows each saying it.
    final offline = state is BridgeSettingsDisconnected;
    final description = offline ? context.loc.settingsBridgeOffline : this.description;
    final group = offline ? Opacity(opacity: _offlineRowsOpacity, child: rows) : rows;
    return SettingsSection(
      title: title,
      child: description == null
          ? group
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: PregoSpacing.md,
              children: [
                Text(
                  description,
                  style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textTertiary),
                ),
                group,
              ],
            ),
    );
  }
}

class const _YoloSettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final ready = state is BridgeSettingsReadyFull ? state : null;
    final interactive =
        ready != null &&
        ready.yoloMutation is! YoloMutationInProgress &&
        ready.yoloMutation is! YoloMutationUncertain &&
        ready.yoloMutation is! YoloMutationUnsupported &&
        ready.pullRequestRefreshMutation is! PullRequestRefreshMutationInProgress &&
        ready.pluginWarmupMutation is! PluginWarmupMutationInProgress;

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
          BridgeSettingsReadyFull(yoloMutation: YoloMutationInProgress()) => const PregoActivityIndicator(color: null),
          BridgeSettingsReadyFull(yoloMutation: YoloMutationUnsupported()) => Text(
            context.loc.settingsPullRequestRefreshUnavailable,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          BridgeSettingsReadyFull(:final yoloEnabled) => PregoSwitch(
            key: const Key("yolo_switch"),
            value: yoloEnabled,
            onChanged: interactive ? (enabled) => toggle(enabled: enabled) : null,
          ),
          BridgeSettingsReadyLegacyPartial() || BridgeSettingsUnsupported() => Text(
            context.loc.settingsPullRequestRefreshUnavailable,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          BridgeSettingsDisconnected() => null,
          BridgeSettingsFailure() || BridgeSettingsReadyFull(yoloMutation: YoloMutationUncertain()) => IconButton(
            key: const Key("yolo_retry"),
            tooltip: context.loc.settingsYoloRetry,
            onPressed: context.read<BridgeSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
        },
        onTap: !interactive ? null : () => toggle(enabled: !ready.yoloEnabled),
      ),
    );
  }
}

class const _PluginWarmupSettingsRow() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<BridgeSettingsCubit>().state;
    final ready = state is BridgeSettingsReadyFull ? state : null;
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
        ready.pullRequestRefreshMutation is! PullRequestRefreshMutationInProgress;

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
          BridgeSettingsLoading() || BridgeSettingsReadyFull(pluginWarmupMutation: PluginWarmupMutationInProgress()) =>
            PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
          BridgeSettingsReadyFull(pluginWarmupMutation: PluginWarmupMutationUnsupported()) ||
          BridgeSettingsReadyLegacyPartial() ||
          BridgeSettingsUnsupported() => Text(
            context.loc.settingsPullRequestRefreshUnavailable,
            style: context.prego.textTheme.textSm.regular.copyWith(
              color: context.prego.colors.textSecondary,
            ),
          ),
          BridgeSettingsReadyFull(
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
          BridgeSettingsReadyFull(pluginWarmupMutation: PluginWarmupMutationUncertain()) => IconButton(
            key: const Key("plugin_warmup_retry"),
            tooltip: context.loc.settingsPluginWarmupRetry,
            onPressed: context.read<BridgeSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
        },
        onTap: enabled == null || !interactive ? null : () => toggle(enabled: !enabled),
      ),
    );
  }
}

String _pluginWarmupDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() => context.loc.settingsPluginWarmupLoading,
    BridgeSettingsUnsupported() ||
    BridgeSettingsReadyLegacyPartial() ||
    BridgeSettingsReadyFull(
      pluginWarmupMutation: PluginWarmupMutationUnsupported(),
    ) => context.loc.settingsPluginWarmupUnsupported,
    BridgeSettingsFailure() => context.loc.settingsPluginWarmupLoadFailed,
    BridgeSettingsReadyFull(pluginWarmupMutation: PluginWarmupMutationUncertain()) =>
      context.loc.settingsPluginWarmupUncertain,
    BridgeSettingsReadyFull(pluginWarmupMutation: PluginWarmupMutationFailed()) =>
      context.loc.settingsPluginWarmupUpdateFailed,
    BridgeSettingsReadyFull() || BridgeSettingsDisconnected() => context.loc.settingsPluginWarmupDescription,
  };
}

String _yoloDescription({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() => context.loc.settingsYoloLoading,
    BridgeSettingsUnsupported() ||
    BridgeSettingsReadyLegacyPartial() ||
    BridgeSettingsReadyFull(yoloMutation: YoloMutationUnsupported()) => context.loc.settingsYoloUnsupported,
    BridgeSettingsFailure() => context.loc.settingsYoloLoadFailed,
    BridgeSettingsReadyFull(yoloMutation: YoloMutationUncertain()) => context.loc.settingsYoloUncertain,
    BridgeSettingsReadyFull(yoloMutation: YoloMutationFailed()) => context.loc.settingsYoloUpdateFailed,
    BridgeSettingsReadyFull() || BridgeSettingsDisconnected() => context.loc.settingsYoloDescription,
  };
}

String _description({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() => context.loc.settingsPullRequestRefreshLoading,
    BridgeSettingsUnsupported() => context.loc.settingsPullRequestRefreshUnsupported,
    BridgeSettingsFailure() => context.loc.settingsPullRequestRefreshLoadFailed,
    BridgeSettingsReady(
      pullRequestRefreshMutation: PullRequestRefreshMutationUnsupported(),
    ) =>
      context.loc.settingsPullRequestRefreshUnsupported,
    BridgeSettingsReady(
      pullRequestRefreshMutation: PullRequestRefreshMutationUncertain(),
    ) =>
      context.loc.settingsPullRequestRefreshUncertain,
    BridgeSettingsReady(
      pullRequestRefreshMutation: PullRequestRefreshMutationRangeRejected(:final bounds),
    ) =>
      context.loc.settingsPullRequestRefreshRangeInvalid(
        bounds.minimumIntervalSeconds,
        bounds.maximumIntervalSeconds,
      ),
    BridgeSettingsReady(pullRequestRefreshMutation: final PullRequestRefreshMutationFailed failure) =>
      switch (failure.error) {
        PullRequestRefreshInvalidInput() => context.loc.settingsPullRequestRefreshInvalid,
        PullRequestRefreshRequestFailed() => context.loc.settingsPullRequestRefreshUpdateFailed,
      },
    BridgeSettingsReady() || BridgeSettingsDisconnected() => context.loc.settingsPullRequestRefreshDescription,
  };
}

Widget? _trailing({required BuildContext context, required BridgeSettingsState state}) {
  return switch (state) {
    BridgeSettingsLoading() ||
    BridgeSettingsReady(
      pullRequestRefreshMutation: PullRequestRefreshMutationInProgress(),
    ) => const PregoActivityIndicator(color: null),
    BridgeSettingsReady(pullRequestRefreshMutation: PullRequestRefreshMutationUnsupported()) => Text(
      context.loc.settingsPullRequestRefreshUnavailable,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
    BridgeSettingsReady(pullRequestRefreshMutation: PullRequestRefreshMutationUncertain()) => IconButton(
      key: const Key("pull_request_refresh_retry"),
      tooltip: context.loc.settingsPullRequestRefreshRetry,
      onPressed: context.read<BridgeSettingsCubit>().refresh,
      icon: const Icon(TablerRegular.refresh),
    ),
    // The value opens an editor, so it carries a chevron.
    BridgeSettingsReady(:final pullRequestRefreshIntervalSeconds) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: PregoSpacing.xs,
      children: [
        Text(
          context.loc.settingsPullRequestRefreshSeconds(pullRequestRefreshIntervalSeconds),
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
        ),
        Icon(TablerRegular.chevron_right, size: PregoIconSize.sm, color: context.prego.colors.textTertiary),
      ],
    ),
    BridgeSettingsUnsupported() => Text(
      context.loc.settingsPullRequestRefreshUnavailable,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
    BridgeSettingsDisconnected() => null,
    BridgeSettingsFailure() => IconButton(
      key: const Key("pull_request_refresh_retry"),
      tooltip: context.loc.settingsPullRequestRefreshRetry,
      onPressed: context.read<BridgeSettingsCubit>().refresh,
      icon: const Icon(TablerRegular.refresh),
    ),
  };
}

Future<void> _editInterval({
  required BuildContext context,
  required BridgeSettingsReady state,
}) async {
  final cubit = context.read<BridgeSettingsCubit>();
  final result = await showPregoModal<String>(
    context: context,
    title: context.loc.settingsPullRequestRefreshDialogTitle,
    builder: (_) => _RefreshIntervalSheet(
      cubit: cubit,
      initialSeconds: state.pullRequestRefreshIntervalSeconds,
      validationBounds: state.validationBounds,
    ),
  );
  if (result == null) return;
  final acceptance = await cubit.updatePullRequestRefresh(input: result, expectedState: state);
  if (!context.mounted || acceptance == BridgeSettingsUpdateAcceptance.accepted) return;
  PregoPopupAlertPresenter.of(context).show(
    title: context.loc.settingsPullRequestRefreshStateChanged,
    variant: PregoPopupAlertsNotificationsVariant.warning,
  );
}

class const _RefreshIntervalSheet({
  required final BridgeSettingsCubit cubit,
  required final int initialSeconds,
  required final PullRequestRefreshSettingsBounds? validationBounds,
}) extends StatefulWidget {
  @override
  State<_RefreshIntervalSheet> createState() => _RefreshIntervalSheetState();
}

class _RefreshIntervalSheetState() extends State<_RefreshIntervalSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(text: widget.initialSeconds.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Form(
            key: _formKey,
            child: PregoInputField(
              key: const Key("pull_request_refresh_input"),
              controller: _controller,
              label: context.loc.settingsPullRequestRefreshSecondsLabel,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) => switch (widget.cubit.validatePullRequestRefreshInput(input: value ?? "")) {
                PullRequestRefreshInputValidation.valid => null,
                PullRequestRefreshInputValidation.invalid => _inputMessage(context: context),
              },
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: PregoSpacing.sm),
          Text(
            _inputMessage(context: context),
            style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              key: const Key("pull_request_refresh_cancel"),
              label: context.loc.settingsPullRequestRefreshCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
            primary: PregoButtonsSolid(
              key: const Key("pull_request_refresh_save"),
              label: context.loc.settingsPullRequestRefreshSave,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }

  String _inputMessage({required BuildContext context}) {
    final bounds = widget.validationBounds;
    return bounds == null
        ? context.loc.settingsPullRequestRefreshInvalid
        : context.loc.settingsPullRequestRefreshRangeInvalid(
            bounds.minimumIntervalSeconds,
            bounds.maximumIntervalSeconds,
          );
  }
}
