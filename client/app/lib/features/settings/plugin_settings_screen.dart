import "dart:async";

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

class PluginSettingsScreen extends StatelessWidget {
  const PluginSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginManagementCubit(service: getIt<PluginManagementService>()),
      child: const _PluginSettingsBody(),
    );
  }
}

class _PluginSettingsBody extends StatelessWidget {
  const _PluginSettingsBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PluginManagementCubit>().state;
    final loc = context.loc;

    return BlocListener<PluginManagementCubit, PluginManagementState>(
      listenWhen: (previous, current) {
        final previousAction = previous is PluginManagementReady ? previous.pendingForceAction : null;
        final currentAction = current is PluginManagementReady ? current.pendingForceAction : null;
        return previousAction != currentAction && currentAction != null;
      },
      listener: (context, state) {
        if (state case PluginManagementReady(pendingForceAction: final action?)) {
          unawaited(_showForceConfirmation(context: context, action: action));
        }
      },
      child: PregoGlassScaffold(
        title: loc.pluginSettingsTitle,
        titleMode: PregoTopNavigationTitleMode.inline,
        banner: ConnectionBanner.maybeFor(context),
        actions: [
          PregoButtonsIconGlass(
            icon: TablerRegular.x,
            semanticLabel: loc.settingsClose,
            onPressed: () => context.goRoute(const AppRoute.projects()),
          ),
        ],
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PregoSpacing.xl,
                vertical: _contentTopPadding,
              ),
              child: switch (state) {
                PluginManagementLoading() => const _LoadingView(),
                PluginManagementUnsupportedState() => const _UnsupportedView(),
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

  Future<void> _showForceConfirmation({
    required BuildContext context,
    required PluginManagementForceAction action,
  }) async {
    final loc = context.loc;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          switch (action) {
            PluginManagementForceAction.disable => loc.pluginSettingsForceDisableTitle,
            PluginManagementForceAction.restart => loc.pluginSettingsForceRestartTitle,
          },
        ),
        content: Text(loc.pluginSettingsForceDescription),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(false),
            child: Text(loc.pluginSettingsCancel),
          ),
          TextButton(
            onPressed: () => dialogContext.pop(true),
            child: Text(
              loc.pluginSettingsForceAction,
              style: TextStyle(color: context.prego.colors.fgErrorPrimary),
            ),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    final cubit = context.read<PluginManagementCubit>();
    if (confirmed ?? false) {
      await cubit.confirmForce();
    } else {
      cubit.dismissActionError();
    }
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.loc.pluginSettingsLoading,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(top: PregoSpacing.x4l),
        child: Center(
          child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
        ),
      ),
    );
  }
}

class _UnsupportedView extends StatelessWidget {
  const _UnsupportedView();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.info_circle,
          title: Text(loc.pluginSettingsUnsupportedTitle),
          subtitle: Text(loc.pluginSettingsUnsupportedDescription),
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
    final loc = context.loc;
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(loc.pluginSettingsLoadFailed),
          subtitle: Text(loc.pluginSettingsLoadFailedDescription),
          trailing: TextButton(
            key: const Key("plugin_settings_retry"),
            onPressed: () => context.read<PluginManagementCubit>().refresh(),
            child: Text(loc.pluginSettingsRetry),
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
    final response = state.response;
    final actionsEnabled = state.actionStatus != PluginManagementActionStatus.inProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          loc.pluginSettingsDescription,
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.xl),
        if (state.actionError case final error?) ...[
          _ActionError(error: error),
          const SizedBox(height: PregoSpacing.xl),
        ],
        SettingsSection(
          title: loc.pluginSettingsIdleTimeoutSection,
          child: PregoGroupedRows(
            children: [
              PregoGroupedRow(
                key: const Key("plugin_settings_global_timeout"),
                icon: TablerRegular.clock,
                title: Text(loc.pluginSettingsGlobalIdleTimeout),
                subtitle: Text(loc.pluginSettingsGlobalIdleTimeoutDescription),
                trailing: TextButton(
                  key: const Key("plugin_settings_edit_global_timeout"),
                  onPressed: actionsEnabled
                      ? () => _editGlobalTimeout(context: context, currentValue: response.defaultIdleTimeoutMins)
                      : null,
                  child: Text(loc.pluginSettingsTimeoutMinutes(response.defaultIdleTimeoutMins)),
                ),
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: PregoSpacing.xl),
        SettingsSection(
          title: loc.pluginSettingsRegistrationsSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < response.plugins.length; index++) ...[
                _PluginCard(
                  plugin: response.plugins[index],
                  isDefault: response.plugins[index].setup.id == response.defaultPluginId,
                  actionsEnabled: actionsEnabled,
                  actionInProgress:
                      state.actionStatus == PluginManagementActionStatus.inProgress &&
                      (state.actingPluginId == null || state.actingPluginId == response.plugins[index].setup.id),
                ),
                if (index != response.plugins.length - 1) const SizedBox(height: PregoSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editGlobalTimeout({required BuildContext context, required int currentValue}) async {
    final input = await _showIdleTimeoutDialog(
      context: context,
      title: context.loc.pluginSettingsGlobalTimeoutDialogTitle,
      currentValue: currentValue,
    );
    if (!context.mounted || input == null) return;
    await context.read<PluginManagementCubit>().applyIdleTimeoutToAll(input: input);
  }
}

class _ActionError extends StatelessWidget {
  const _ActionError({required this.error});

  final PluginManagementActionError error;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final message = switch (error) {
      PluginManagementInvalidIdleTimeout() => loc.pluginSettingsInvalidIdleTimeout,
      PluginManagementActionNotFound() => loc.pluginSettingsActionNotFound,
      PluginManagementActionConflict() => loc.pluginSettingsActionConflict,
      PluginManagementActionRequestError() => loc.pluginSettingsActionFailed,
    };
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(loc.pluginSettingsActionFailedTitle),
          subtitle: Text(message),
          trailing: IconButton(
            tooltip: loc.pluginSettingsDismissError,
            onPressed: context.read<PluginManagementCubit>().dismissActionError,
            icon: const Icon(TablerRegular.x),
          ),
          isLast: true,
        ),
      ],
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({
    required this.plugin,
    required this.isDefault,
    required this.actionsEnabled,
    required this.actionInProgress,
  });

  final PluginManagementMetadata plugin;
  final bool isDefault;
  final bool actionsEnabled;
  final bool actionInProgress;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.read<PluginManagementCubit>();
    final pluginId = plugin.setup.id;
    final isEligible = plugin.runtimeState.isEnabled;
    final actionHint = plugin.actionHint ?? plugin.setup.actionHint;

    return PregoGroupedRows(
      key: Key("plugin_settings_card_$pluginId"),
      children: [
        PregoGroupedRow(
          leading: actionInProgress
              ? SizedBox.square(
                  dimension: 24,
                  child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary),
                )
              : const Icon(TablerRegular.plug),
          title: Row(
            children: [
              Flexible(child: Text(plugin.setup.displayName)),
              if (isDefault) ...[
                const SizedBox(width: PregoSpacing.md),
                PregoTag(label: loc.pluginSettingsDefaultBadge),
              ],
            ],
          ),
          subtitle: actionHint == null ? null : Text(actionHint),
          trailing: PregoSwitch(
            key: Key("plugin_settings_enabled_$pluginId"),
            value: isEligible,
            onChanged: actionsEnabled
                ? (enabled) {
                    if (enabled) {
                      cubit.enable(pluginId: pluginId);
                    } else {
                      cubit.disable(pluginId: pluginId);
                    }
                  }
                : null,
          ),
        ),
        _FactRow(
          title: loc.pluginSettingsSetupStatus,
          value: _setupStatus(context: context, state: plugin.setup.state),
        ),
        _FactRow(
          title: loc.pluginSettingsRuntimeStatus,
          value: _runtimeStatus(context: context, state: plugin.runtimeState),
        ),
        _FactRow(
          title: loc.pluginSettingsWorkStatus,
          value: _workStatus(context: context, state: plugin.workState),
        ),
        _FactRow(
          title: loc.pluginSettingsEligibility,
          value: isEligible ? loc.pluginSettingsEligible : loc.pluginSettingsNotEligible,
        ),
        PregoGroupedRow(
          key: Key("plugin_settings_timeout_$pluginId"),
          title: Text(loc.pluginSettingsEffectiveIdleTimeout),
          subtitle: Text(
            plugin.hasIdleTimeoutOverride
                ? loc.pluginSettingsCustomIdleTimeout
                : loc.pluginSettingsUsesGlobalIdleTimeout,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.pluginSettingsTimeoutMinutes(plugin.idleTimeoutMins)),
              const SizedBox(width: PregoSpacing.xs),
              const Icon(TablerRegular.chevron_right),
            ],
          ),
          onTap: actionsEnabled ? () => _editOverride(context: context) : null,
        ),
        PregoGroupedRow(
          title: Wrap(
            spacing: PregoSpacing.xs,
            runSpacing: PregoSpacing.xs,
            children: [
              TextButton.icon(
                key: Key("plugin_settings_refresh_$pluginId"),
                onPressed: actionsEnabled ? () => cubit.refreshPlugin(pluginId: pluginId) : null,
                icon: const Icon(TablerRegular.refresh, size: 18),
                label: Text(loc.pluginSettingsRefreshSetup),
              ),
              TextButton.icon(
                key: Key("plugin_settings_restart_$pluginId"),
                onPressed: actionsEnabled && isEligible ? () => cubit.restart(pluginId: pluginId) : null,
                icon: const Icon(TablerRegular.rotate_clockwise, size: 18),
                label: Text(loc.pluginSettingsRestart),
              ),
              TextButton(
                key: Key("plugin_settings_set_override_$pluginId"),
                onPressed: actionsEnabled ? () => _editOverride(context: context) : null,
                child: Text(loc.pluginSettingsSetOverride),
              ),
              if (plugin.hasIdleTimeoutOverride)
                TextButton(
                  key: Key("plugin_settings_clear_override_$pluginId"),
                  onPressed: actionsEnabled ? () => cubit.clearIdleTimeoutOverride(pluginId: pluginId) : null,
                  child: Text(loc.pluginSettingsClearOverride),
                ),
            ],
          ),
          isLast: true,
        ),
      ],
    );
  }

  Future<void> _editOverride({required BuildContext context}) async {
    final input = await _showIdleTimeoutDialog(
      context: context,
      title: context.loc.pluginSettingsOverrideDialogTitle(plugin.setup.displayName),
      currentValue: plugin.idleTimeoutMins,
    );
    if (!context.mounted || input == null) return;
    await context.read<PluginManagementCubit>().setIdleTimeoutOverride(pluginId: plugin.setup.id, input: input);
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

Future<String?> _showIdleTimeoutDialog({
  required BuildContext context,
  required String title,
  required int currentValue,
}) async {
  final loc = context.loc;
  var input = currentValue.toString();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      final prego = dialogContext.prego;
      final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(PregoRadius.lg),
        borderSide: BorderSide(color: prego.colors.borderPrimary),
      );
      return AlertDialog(
        title: Text(title),
        content: TextFormField(
          key: const Key("plugin_settings_timeout_input"),
          initialValue: input,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          textInputAction: TextInputAction.done,
          style: prego.textTheme.textMd.regular.copyWith(color: prego.colors.textPrimary),
          decoration: InputDecoration(
            labelText: loc.pluginSettingsIdleTimeoutField,
            suffixText: loc.pluginSettingsMinutesUnit,
            filled: true,
            fillColor: prego.colors.bgSurface3,
            border: border,
            enabledBorder: border,
          ),
          onChanged: (value) => input = value,
          onFieldSubmitted: (value) => dialogContext.pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => dialogContext.pop(),
            child: Text(loc.pluginSettingsCancel),
          ),
          TextButton(
            key: const Key("plugin_settings_save_timeout"),
            onPressed: () => dialogContext.pop(input),
            child: Text(loc.pluginSettingsSave),
          ),
        ],
      );
    },
  );
}

String _setupStatus({required BuildContext context, required PluginSetupState state}) => switch (state) {
  PluginSetupState.notInspected => context.loc.pluginSettingsSetupNotInspected,
  PluginSetupState.ready => context.loc.pluginSettingsSetupReady,
  PluginSetupState.runtimeMissing => context.loc.pluginSettingsSetupRuntimeMissing,
  PluginSetupState.authenticationRequired => context.loc.pluginSettingsSetupAuthenticationRequired,
  PluginSetupState.unavailable => context.loc.pluginSettingsSetupUnavailable,
  PluginSetupState.unknown => context.loc.pluginSettingsStatusUnknown,
};

String _runtimeStatus({required BuildContext context, required PluginRuntimeState state}) => switch (state) {
  PluginRuntimeState.disabled => context.loc.pluginSettingsStatusDisabled,
  PluginRuntimeState.blocked => context.loc.pluginSettingsStatusBlocked,
  PluginRuntimeState.dormant => context.loc.pluginSettingsStatusDormant,
  PluginRuntimeState.starting => context.loc.pluginSettingsStatusStarting,
  PluginRuntimeState.active => context.loc.pluginSettingsStatusActive,
  PluginRuntimeState.degraded => context.loc.pluginSettingsStatusDegraded,
  PluginRuntimeState.stopping => context.loc.pluginSettingsStatusStopping,
  PluginRuntimeState.failed => context.loc.pluginSettingsStatusFailed,
  PluginRuntimeState.unknown => context.loc.pluginSettingsStatusUnknown,
};

String _workStatus({required BuildContext context, required PluginManagementWorkState state}) => switch (state) {
  PluginManagementWorkState.idle => context.loc.pluginSettingsWorkIdle,
  PluginManagementWorkState.busy => context.loc.pluginSettingsWorkBusy,
  PluginManagementWorkState.unknown => context.loc.pluginSettingsStatusUnknown,
};
