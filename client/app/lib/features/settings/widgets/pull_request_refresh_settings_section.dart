import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../core/extensions/build_context_x.dart";
import "settings_section.dart";

class PullRequestRefreshSettingsSection extends StatelessWidget {
  const PullRequestRefreshSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PullRequestRefreshSettingsCubit>().state;
    return SettingsSection(
      title: context.loc.settingsSectionBridge,
      child: PregoGroupedRows(
        children: [
          const _YoloSettingsRow(),
          PregoGroupedRow(
            key: const Key("pull_request_refresh_interval"),
            icon: TablerRegular.refresh,
            title: Text(context.loc.settingsPullRequestRefreshTitle),
            subtitle: Text(_description(context: context, state: state)),
            trailing: _trailing(context: context, state: state),
            onTap: switch (state) {
              PullRequestRefreshSettingsReady(:final mutation)
                  when mutation is! PullRequestRefreshSettingsMutationInProgress =>
                () => unawaited(_editInterval(context: context, state: state)),
              PullRequestRefreshSettingsLoading() ||
              PullRequestRefreshSettingsDisconnected() ||
              PullRequestRefreshSettingsUnsupported() ||
              PullRequestRefreshSettingsFailure() ||
              PullRequestRefreshSettingsUncertain() ||
              PullRequestRefreshSettingsReady() => null,
            },
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _YoloSettingsRow extends StatelessWidget {
  const _YoloSettingsRow();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<YoloSettingsCubit>().state;
    final ready = state is YoloSettingsReady ? state : null;
    final updating = ready?.mutation is YoloSettingsMutationInProgress;

    void toggle({required bool enabled}) {
      final current = ready;
      if (current == null || updating) return;
      unawaited(context.read<YoloSettingsCubit>().update(enabled: enabled, expectedState: current));
    }

    return MergeSemantics(
      child: PregoGroupedRow(
        key: const Key("yolo_setting"),
        icon: TablerRegular.shield_off,
        title: Text(context.loc.settingsYoloTitle),
        subtitle: Text(_yoloDescription(context: context, state: state)),
        trailing: switch (state) {
          YoloSettingsLoading() || YoloSettingsReady(mutation: YoloSettingsMutationInProgress()) =>
            PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
          YoloSettingsReady(:final enabled) => PregoSwitch(
            key: const Key("yolo_switch"),
            value: enabled,
            onChanged: (enabled) => toggle(enabled: enabled),
          ),
          YoloSettingsUnsupported() => Text(
            context.loc.settingsPullRequestRefreshUnavailable,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          YoloSettingsDisconnected() => Text(
            context.loc.settingsPullRequestRefreshOffline,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          YoloSettingsFailure() || YoloSettingsUncertain() => IconButton(
            key: const Key("yolo_retry"),
            tooltip: context.loc.settingsYoloRetry,
            onPressed: context.read<YoloSettingsCubit>().refresh,
            icon: const Icon(TablerRegular.refresh),
          ),
        },
        onTap: ready == null || updating ? null : () => toggle(enabled: !ready.enabled),
      ),
    );
  }
}

String _yoloDescription({required BuildContext context, required YoloSettingsState state}) {
  return switch (state) {
    YoloSettingsLoading() => context.loc.settingsYoloLoading,
    YoloSettingsDisconnected() => context.loc.settingsYoloDisconnected,
    YoloSettingsUnsupported() => context.loc.settingsYoloUnsupported,
    YoloSettingsFailure() => context.loc.settingsYoloLoadFailed,
    YoloSettingsUncertain() => context.loc.settingsYoloUncertain,
    YoloSettingsReady(mutation: YoloSettingsMutationFailed()) => context.loc.settingsYoloUpdateFailed,
    YoloSettingsReady() => context.loc.settingsYoloWarning,
  };
}

String _description({required BuildContext context, required PullRequestRefreshSettingsState state}) {
  return switch (state) {
    PullRequestRefreshSettingsLoading() => context.loc.settingsPullRequestRefreshLoading,
    PullRequestRefreshSettingsDisconnected() => context.loc.settingsPullRequestRefreshDisconnected,
    PullRequestRefreshSettingsUnsupported() => context.loc.settingsPullRequestRefreshUnsupported,
    PullRequestRefreshSettingsFailure() => context.loc.settingsPullRequestRefreshLoadFailed,
    PullRequestRefreshSettingsUncertain() => context.loc.settingsPullRequestRefreshUncertain,
    PullRequestRefreshSettingsReady(
      mutation: PullRequestRefreshSettingsMutationRangeRejected(:final bounds),
    ) =>
      context.loc.settingsPullRequestRefreshRangeInvalid(
        bounds.minimumIntervalSeconds,
        bounds.maximumIntervalSeconds,
      ),
    PullRequestRefreshSettingsReady(mutation: final PullRequestRefreshSettingsMutationFailed failure) =>
      switch (failure.error) {
        PullRequestRefreshSettingsInvalidInput() => context.loc.settingsPullRequestRefreshInvalid,
        PullRequestRefreshSettingsRequestFailed() => context.loc.settingsPullRequestRefreshUpdateFailed,
      },
    PullRequestRefreshSettingsReady() => context.loc.settingsPullRequestRefreshDescription,
  };
}

Widget _trailing({required BuildContext context, required PullRequestRefreshSettingsState state}) {
  return switch (state) {
    PullRequestRefreshSettingsLoading() ||
    PullRequestRefreshSettingsReady(
      mutation: PullRequestRefreshSettingsMutationInProgress(),
    ) => PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
    PullRequestRefreshSettingsReady(:final intervalSeconds) => Text(
      context.loc.settingsPullRequestRefreshSeconds(intervalSeconds),
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
    PullRequestRefreshSettingsUnsupported() => Text(
      context.loc.settingsPullRequestRefreshUnavailable,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
    PullRequestRefreshSettingsDisconnected() => Text(
      context.loc.settingsPullRequestRefreshOffline,
      style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
    ),
    PullRequestRefreshSettingsFailure() || PullRequestRefreshSettingsUncertain() => IconButton(
      key: const Key("pull_request_refresh_retry"),
      tooltip: context.loc.settingsPullRequestRefreshRetry,
      onPressed: context.read<PullRequestRefreshSettingsCubit>().refresh,
      icon: const Icon(TablerRegular.refresh),
    ),
  };
}

Future<void> _editInterval({
  required BuildContext context,
  required PullRequestRefreshSettingsReady state,
}) async {
  final cubit = context.read<PullRequestRefreshSettingsCubit>();
  final result = await showPregoBottomSheet<String>(
    context: context,
    title: context.loc.settingsPullRequestRefreshDialogTitle,
    builder: (_) => _RefreshIntervalSheet(
      cubit: cubit,
      initialSeconds: state.intervalSeconds,
      validationBounds: state.validationBounds,
    ),
  );
  if (result == null) return;
  final acceptance = await cubit.update(input: result, expectedState: state);
  if (!context.mounted || acceptance == PullRequestRefreshSettingsUpdateAcceptance.accepted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(context.loc.settingsPullRequestRefreshStateChanged)));
}

class _RefreshIntervalSheet extends StatefulWidget {
  const _RefreshIntervalSheet({
    required this.cubit,
    required this.initialSeconds,
    required this.validationBounds,
  });

  final PullRequestRefreshSettingsCubit cubit;
  final int initialSeconds;
  final PullRequestRefreshSettingsBounds? validationBounds;

  @override
  State<_RefreshIntervalSheet> createState() => _RefreshIntervalSheetState();
}

class _RefreshIntervalSheetState extends State<_RefreshIntervalSheet> {
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
              isRequired: true,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (value) => switch (widget.cubit.validateUpdateInput(input: value ?? "")) {
                PullRequestRefreshSettingsInputValidation.valid => null,
                PullRequestRefreshSettingsInputValidation.invalid => _inputMessage(context: context),
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
          Row(
            children: [
              Expanded(
                child: PregoButtonsSolid(
                  key: const Key("pull_request_refresh_cancel"),
                  label: context.loc.settingsPullRequestRefreshCancel,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  fullWidth: true,
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: PregoSpacing.md),
              Expanded(
                child: PregoButtonsSolid(
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
