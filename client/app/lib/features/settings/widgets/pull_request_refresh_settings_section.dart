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

String _description({required BuildContext context, required PullRequestRefreshSettingsState state}) {
  return switch (state) {
    PullRequestRefreshSettingsLoading() => context.loc.settingsPullRequestRefreshLoading,
    PullRequestRefreshSettingsUnsupported() => context.loc.settingsPullRequestRefreshUnsupported,
    PullRequestRefreshSettingsFailure() => context.loc.settingsPullRequestRefreshLoadFailed,
    PullRequestRefreshSettingsUncertain() => context.loc.settingsPullRequestRefreshUncertain,
    PullRequestRefreshSettingsReady(mutation: final PullRequestRefreshSettingsMutationFailed failure) =>
      switch (failure.error) {
        PullRequestRefreshSettingsInvalidInput() ||
        PullRequestRefreshSettingsRejected() => context.loc.settingsPullRequestRefreshInvalid,
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
    builder: (_) => _RefreshIntervalSheet(cubit: cubit, initialSeconds: state.intervalSeconds),
  );
  if (result == null) return;
  await cubit.update(input: result);
}

class _RefreshIntervalSheet extends StatefulWidget {
  const _RefreshIntervalSheet({required this.cubit, required this.initialSeconds});

  final PullRequestRefreshSettingsCubit cubit;
  final int initialSeconds;

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
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              textInputAction: TextInputAction.done,
              validator: (value) => switch (widget.cubit.validateUpdateInput(input: value ?? "")) {
                PullRequestRefreshSettingsInputValidation.valid => null,
                PullRequestRefreshSettingsInputValidation.invalid => context.loc.settingsPullRequestRefreshInvalid,
              },
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: PregoSpacing.sm),
          Text(
            context.loc.settingsPullRequestRefreshHelp,
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
}
