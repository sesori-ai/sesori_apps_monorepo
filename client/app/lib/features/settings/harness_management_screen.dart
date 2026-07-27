import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/settings_section.dart";

const double _contentTopPadding = 10.0;

class HarnessManagementScreen extends StatelessWidget {
  const HarnessManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginManagementCubit(service: getIt<PluginManagementService>()),
      child: const _HarnessManagementBody(),
    );
  }
}

class _HarnessManagementBody extends StatelessWidget {
  const _HarnessManagementBody();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PluginManagementCubit>();
    final state = context.watch<PluginManagementCubit>().state;

    return BlocListener<PluginManagementCubit, PluginManagementState>(
      listenWhen: (previous, current) => _forceConfirmation(previous) != _forceConfirmation(current),
      listener: (context, state) {
        final confirmation = _forceConfirmation(state);
        if (confirmation != null) {
          _showForceConfirmation(context: context, cubit: cubit, confirmation: confirmation);
        }
      },
      child: PregoGlassScaffold(
        title: context.loc.settingsHarnessManagementTitle,
        titleMode: PregoTopNavigationTitleMode.backLeading,
        banner: ConnectionBanner.maybeFor(context),
        onBack: () => context.pop(),
        actions: [
          PregoButtonsIconGlass(
            icon: TablerRegular.x,
            semanticLabel: context.loc.settingsClose,
            onPressed: () => context.goRoute(const AppRoute.projects()),
          ),
        ],
        onRefresh: cubit.refresh,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PregoSpacing.xl,
                vertical: _contentTopPadding,
              ),
              child: switch (state) {
                PluginManagementLoading() => const _LoadingView(),
                PluginManagementUnsupported() => const _UnsupportedView(),
                PluginManagementFailure() => const _FailureView(),
                PluginManagementReady() => _ReadyView(state: state),
              },
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MediaQuery.paddingOf(context).bottom + PregoSpacing.xl),
          ),
        ],
      ),
    );
  }
}

PluginManagementActionForceConfirmationRequired? _forceConfirmation(PluginManagementState state) => switch (state) {
  PluginManagementReady(action: final PluginManagementActionForceConfirmationRequired confirmation) => confirmation,
  PluginManagementReady() ||
  PluginManagementLoading() ||
  PluginManagementUnsupported() ||
  PluginManagementFailure() => null,
};

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.loc.harnessesLoading,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: PregoSpacing.x4l),
        child: Center(child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)),
      ),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView();

  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.info_circle,
          title: Text(context.loc.harnessesUnsupportedTitle),
          subtitle: Text(context.loc.harnessesUnsupportedDescription),
          isLast: true,
        ),
      ],
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView();

  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(context.loc.harnessesLoadFailedTitle),
          subtitle: Text(context.loc.harnessesLoadFailedDescription),
          trailing: TextButton(
            key: const Key("harness_management_retry"),
            onPressed: context.read<PluginManagementCubit>().refresh,
            child: Text(context.loc.harnessesRetry),
          ),
          isLast: true,
        ),
      ],
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state});

  final PluginManagementReady state;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final timeoutCapable = state.response.plugins.any(
      (plugin) => plugin.managementCapabilities.contains(PluginManagementCapability.idleTimeout),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.refresh is PluginManagementRefreshFailed) ...[
          _MessageRow(
            key: const Key("harness_management_refresh_error"),
            title: loc.harnessesRefreshFailedTitle,
            description: loc.harnessesRefreshFailedDescription,
            dismissLabel: loc.harnessesDismissRefreshError,
            onDismiss: context.read<PluginManagementCubit>().dismissRefreshError,
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        if (state.action case final PluginManagementActionFailed failure) ...[
          _MessageRow(
            key: const Key("harness_management_action_error"),
            title: loc.harnessManagementActionFailedTitle,
            description: _actionErrorDescription(context: context, error: failure.error),
            dismissLabel: loc.harnessManagementDismissActionError,
            onDismiss: context.read<PluginManagementCubit>().dismissActionError,
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        Text(
          loc.harnessManagementDescription,
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
        ),
        if (timeoutCapable) ...[
          const SizedBox(height: PregoSpacing.xl),
          SettingsSection(
            title: loc.harnessManagementDefaultsSection,
            child: PregoGroupedRows(
              children: [
                PregoGroupedRow(
                  key: const Key("harness_management_default_timeout"),
                  icon: TablerRegular.clock,
                  title: Text(loc.harnessManagementDefaultTimeout),
                  subtitle: Text(loc.harnessManagementDefaultTimeoutDescription),
                  trailing: Text(_timeoutLabel(context: context, minutes: state.response.defaultIdleTimeoutMins)),
                  onTap: _controlsBlocked(state.action)
                      ? null
                      : () => _editDefaultTimeout(context: context, state: state),
                  isLast: true,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: PregoSpacing.xl),
        SettingsSection(
          title: loc.harnessesRegisteredSection,
          child: state.response.plugins.isEmpty
              ? PregoGroupedRows(
                  children: [
                    PregoGroupedRow(
                      icon: TablerRegular.info_circle,
                      title: Text(loc.harnessesEmptyTitle),
                      subtitle: Text(loc.harnessesEmptyDescription),
                      isLast: true,
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var index = 0; index < state.response.plugins.length; index++) ...[
                      _HarnessControlCard(plugin: state.response.plugins[index], action: state.action),
                      if (index != state.response.plugins.length - 1) const SizedBox(height: PregoSpacing.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    super.key,
    required this.title,
    required this.description,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final String title;
  final String description;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(title),
          subtitle: Text(description),
          trailing: IconButton(
            tooltip: dismissLabel,
            onPressed: onDismiss,
            icon: const Icon(TablerRegular.x),
          ),
          isLast: true,
        ),
      ],
    );
  }
}

class _HarnessControlCard extends StatelessWidget {
  const _HarnessControlCard({required this.plugin, required this.action});

  final PluginManagementMetadata plugin;
  final PluginManagementActionState action;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pluginId = plugin.setup.id;
    final capabilities = plugin.managementCapabilities;
    final lifecycle = capabilities.contains(PluginManagementCapability.lifecycle);
    final setupRefresh = capabilities.contains(PluginManagementCapability.setupRefresh);
    final idleTimeout = capabilities.contains(PluginManagementCapability.idleTimeout);
    final enabled = plugin.runtimeState.isEnabled;
    final blocked = _controlsBlocked(action);
    final actionForThisHarness = switch (action) {
      PluginManagementActionInProgress(
        target: PluginManagementActionTargetHarness(pluginId: final targetPluginId),
      ) =>
        targetPluginId == pluginId,
      PluginManagementActionIdle() ||
      PluginManagementActionInProgress(target: PluginManagementActionTargetAllHarnesses()) ||
      PluginManagementActionFailed() ||
      PluginManagementActionForceConfirmationRequired() => false,
    };
    final actionHint = plugin.actionHint ?? plugin.setup.actionHint;

    return PregoGroupedRows(
      key: Key("harness_management_card_$pluginId"),
      children: [
        PregoGroupedRow(
          leading: PregoBrandLogo(pluginId: pluginId, color: context.prego.colors.textTertiary),
          title: Text(plugin.setup.displayName),
          subtitle: actionHint == null ? null : Text(actionHint),
          trailing: actionForThisHarness ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary) : null,
        ),
        _FactRow(
          title: loc.harnessesSetupStatus,
          value: _setupStatus(context: context, state: plugin.setup.state),
        ),
        _FactRow(
          title: loc.harnessesRuntimeStatus,
          value: _runtimeStatus(context: context, state: plugin.runtimeState),
        ),
        _FactRow(
          title: loc.harnessesWorkStatus,
          value: _workStatus(context: context, state: plugin.workState),
        ),
        if (!lifecycle)
          PregoGroupedRow(
            key: Key("harness_management_external_$pluginId"),
            icon: TablerRegular.info_circle,
            title: Text(loc.harnessManagementExternalTitle),
            subtitle: Text(loc.harnessManagementExternalDescription),
            isLast: !setupRefresh && !idleTimeout,
          ),
        if (lifecycle)
          MergeSemantics(
            child: PregoGroupedRow(
              key: Key("harness_management_enabled_$pluginId"),
              title: Text(loc.harnessManagementEnabled),
              trailing: PregoSwitch(
                value: enabled,
                onChanged: blocked
                    ? null
                    : (value) => value
                          ? context.read<PluginManagementCubit>().enable(pluginId: pluginId)
                          : context.read<PluginManagementCubit>().disable(pluginId: pluginId),
              ),
              onTap: blocked
                  ? null
                  : () => enabled
                        ? context.read<PluginManagementCubit>().disable(pluginId: pluginId)
                        : context.read<PluginManagementCubit>().enable(pluginId: pluginId),
            ),
          ),
        if (setupRefresh)
          PregoGroupedRow(
            key: Key("harness_management_refresh_$pluginId"),
            icon: TablerRegular.refresh,
            title: Text(loc.harnessManagementRefreshSetup),
            onTap: blocked ? null : () => context.read<PluginManagementCubit>().refreshSetup(pluginId: pluginId),
            isLast: !lifecycle && !idleTimeout,
          ),
        if (lifecycle)
          PregoGroupedRow(
            key: Key("harness_management_restart_$pluginId"),
            icon: TablerRegular.rotate_clockwise,
            title: Text(loc.harnessManagementRestart),
            onTap: blocked || !enabled ? null : () => context.read<PluginManagementCubit>().restart(pluginId: pluginId),
            isLast: !idleTimeout,
          ),
        if (idleTimeout)
          PregoGroupedRow(
            key: Key("harness_management_timeout_$pluginId"),
            icon: TablerRegular.clock,
            title: Text(loc.harnessManagementIdleTimeout),
            subtitle: Text(
              plugin.hasIdleTimeoutOverride ? loc.harnessesCustomIdleTimeout : loc.harnessesUsesDefaultIdleTimeout,
            ),
            trailing: Text(_timeoutLabel(context: context, minutes: plugin.idleTimeoutMins)),
            onTap: blocked ? null : () => _editHarnessTimeout(context: context, plugin: plugin),
            isLast: !plugin.hasIdleTimeoutOverride,
          ),
        if (idleTimeout && plugin.hasIdleTimeoutOverride)
          PregoGroupedRow(
            key: Key("harness_management_clear_timeout_$pluginId"),
            icon: TablerRegular.x,
            title: Text(loc.harnessManagementClearOverride),
            onTap: blocked
                ? null
                : () => context.read<PluginManagementCubit>().clearIdleTimeoutOverride(pluginId: pluginId),
            isLast: true,
          ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      title: Text(title),
      trailing: Text(
        value,
        textAlign: TextAlign.end,
        style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
      ),
    );
  }
}

bool _controlsBlocked(PluginManagementActionState action) =>
    action is PluginManagementActionInProgress || action is PluginManagementActionForceConfirmationRequired;

Future<void> _editDefaultTimeout({required BuildContext context, required PluginManagementReady state}) async {
  final cubit = context.read<PluginManagementCubit>();
  final input = await _showTimeoutDialog(
    context: context,
    title: context.loc.harnessManagementDefaultTimeoutDialogTitle,
    initialValue: state.response.defaultIdleTimeoutMins,
  );
  if (input != null) await cubit.applyIdleTimeoutToAll(input: input);
}

Future<void> _editHarnessTimeout({required BuildContext context, required PluginManagementMetadata plugin}) async {
  final cubit = context.read<PluginManagementCubit>();
  final input = await _showTimeoutDialog(
    context: context,
    title: context.loc.harnessManagementTimeoutDialogTitle(plugin.setup.displayName),
    initialValue: plugin.idleTimeoutMins,
  );
  if (input != null) await cubit.setIdleTimeoutOverride(pluginId: plugin.setup.id, input: input);
}

Future<String?> _showTimeoutDialog({
  required BuildContext context,
  required String title,
  required int initialValue,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TimeoutDialog(title: title, initialValue: initialValue),
  );
}

class _TimeoutDialog extends StatefulWidget {
  const _TimeoutDialog({required this.title, required this.initialValue});

  final String title;
  final int initialValue;

  @override
  State<_TimeoutDialog> createState() => _TimeoutDialogState();
}

class _TimeoutDialogState extends State<_TimeoutDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialValue.toString());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key("harness_management_timeout_input"),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(signed: true),
        decoration: InputDecoration(
          labelText: context.loc.harnessManagementTimeoutMinutesLabel,
          helperText: context.loc.harnessManagementTimeoutHelp,
        ),
        onSubmitted: (value) => context.pop(value),
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: Text(context.loc.harnessManagementCancel)),
        TextButton(
          key: const Key("harness_management_timeout_save"),
          onPressed: () => context.pop(_controller.text),
          child: Text(context.loc.harnessManagementSave),
        ),
      ],
    );
  }
}

Future<void> _showForceConfirmation({
  required BuildContext context,
  required PluginManagementCubit cubit,
  required PluginManagementActionForceConfirmationRequired confirmation,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        confirmation.action == PluginManagementForceAction.disable
            ? context.loc.harnessManagementForceDisableTitle
            : context.loc.harnessManagementForceRestartTitle,
      ),
      content: Text(context.loc.harnessManagementForceDescription),
      actions: [
        TextButton(
          key: const Key("harness_management_force_cancel"),
          onPressed: () => dialogContext.pop(false),
          child: Text(context.loc.harnessManagementCancel),
        ),
        TextButton(
          key: const Key("harness_management_force_confirm"),
          onPressed: () => dialogContext.pop(true),
          child: Text(
            context.loc.harnessManagementForceAction,
            style: TextStyle(color: context.prego.colors.fgErrorPrimary),
          ),
        ),
      ],
    ),
  );
  if (confirmed ?? false) {
    await cubit.confirmForce();
  } else {
    cubit.dismissForceConfirmation();
  }
}

String _actionErrorDescription({required BuildContext context, required PluginManagementActionError error}) =>
    switch (error) {
      PluginManagementInvalidIdleTimeout() => context.loc.harnessManagementInvalidTimeout,
      PluginManagementActionNotFound() => context.loc.harnessManagementNotFound,
      PluginManagementActionConflict() => context.loc.harnessManagementConflict,
      PluginManagementActionUncertain() => context.loc.harnessManagementUncertain,
      PluginManagementActionRequestError() => context.loc.harnessManagementRequestFailed,
    };

String _timeoutLabel({required BuildContext context, required int minutes}) =>
    minutes <= 0 ? context.loc.harnessesNoIdleTimeout : context.loc.harnessesIdleTimeoutMinutes(minutes);

String _setupStatus({required BuildContext context, required PluginSetupState state}) => switch (state) {
  PluginSetupState.notInspected => context.loc.harnessesSetupNotInspected,
  PluginSetupState.ready => context.loc.harnessesSetupReady,
  PluginSetupState.runtimeMissing => context.loc.harnessesSetupRuntimeMissing,
  PluginSetupState.authenticationRequired => context.loc.harnessesSetupAuthenticationRequired,
  PluginSetupState.unavailable => context.loc.harnessesSetupUnavailable,
  PluginSetupState.unknown => context.loc.harnessesStatusUnknown,
};

String _runtimeStatus({required BuildContext context, required PluginRuntimeState state}) => switch (state) {
  PluginRuntimeState.disabled => context.loc.harnessesStatusDisabled,
  PluginRuntimeState.blocked => context.loc.harnessesStatusBlocked,
  PluginRuntimeState.dormant => context.loc.harnessesStatusDormant,
  PluginRuntimeState.starting => context.loc.harnessesStatusStarting,
  PluginRuntimeState.active => context.loc.harnessesStatusActive,
  PluginRuntimeState.degraded => context.loc.harnessesStatusDegraded,
  PluginRuntimeState.stopping => context.loc.harnessesStatusStopping,
  PluginRuntimeState.failed => context.loc.harnessesStatusFailed,
  PluginRuntimeState.unknown => context.loc.harnessesStatusUnknown,
};

String _workStatus({required BuildContext context, required PluginManagementWorkState state}) => switch (state) {
  PluginManagementWorkState.idle => context.loc.harnessesWorkIdle,
  PluginManagementWorkState.busy => context.loc.harnessesWorkBusy,
  PluginManagementWorkState.unknown => context.loc.harnessesStatusUnknown,
};
