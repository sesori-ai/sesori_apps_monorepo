import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/settings_section.dart";

const double _contentTopPadding = 10.0;

class HarnessesSettingsScreen extends StatelessWidget {
  const HarnessesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginManagementCubit(service: getIt<PluginManagementService>()),
      child: const _HarnessesSettingsBody(),
    );
  }
}

class _HarnessesSettingsBody extends StatelessWidget {
  const _HarnessesSettingsBody();

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final cubit = context.read<PluginManagementCubit>();
    final state = context.watch<PluginManagementCubit>().state;

    return PregoGlassScaffold(
      title: loc.settingsHarnessesTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      banner: ConnectionBanner.maybeFor(context),
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
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
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.loc.harnessesLoading,
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
          title: Text(loc.harnessesUnsupportedTitle),
          subtitle: Text(loc.harnessesUnsupportedDescription),
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
          title: Text(loc.harnessesLoadFailedTitle),
          subtitle: Text(loc.harnessesLoadFailedDescription),
          trailing: TextButton(
            key: const Key("harnesses_retry"),
            onPressed: context.read<PluginManagementCubit>().refresh,
            child: Text(loc.harnessesRetry),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.refreshError != null) ...[
          PregoGroupedRows(
            children: [
              PregoGroupedRow(
                key: const Key("harnesses_refresh_error"),
                icon: TablerRegular.alert_triangle,
                title: Text(loc.harnessesRefreshFailedTitle),
                subtitle: Text(loc.harnessesRefreshFailedDescription),
                trailing: IconButton(
                  tooltip: loc.harnessesDismissRefreshError,
                  onPressed: context.read<PluginManagementCubit>().dismissRefreshError,
                  icon: const Icon(TablerRegular.x),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        Text(
          loc.harnessesDescription,
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.xl),
        SettingsSection(
          title: loc.harnessesRegisteredSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < response.plugins.length; index++) ...[
                _HarnessCard(
                  plugin: response.plugins[index],
                  isDefault: response.plugins[index].setup.id == response.defaultPluginId,
                ),
                if (index != response.plugins.length - 1) const SizedBox(height: PregoSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HarnessCard extends StatelessWidget {
  const _HarnessCard({required this.plugin, required this.isDefault});

  final PluginManagementMetadata plugin;
  final bool isDefault;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pluginId = plugin.setup.id;
    final actionHint = plugin.actionHint ?? plugin.setup.actionHint;

    return PregoGroupedRows(
      key: Key("harnesses_card_$pluginId"),
      children: [
        PregoGroupedRow(
          leading: PregoBrandLogo(
            pluginId: pluginId,
            color: context.prego.colors.textTertiary,
          ),
          title: Row(
            children: [
              Flexible(child: Text(plugin.setup.displayName)),
              if (isDefault) ...[
                const SizedBox(width: PregoSpacing.md),
                PregoTag(label: loc.harnessesDefaultBadge),
              ],
            ],
          ),
          subtitle: actionHint == null ? null : Text(actionHint),
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
        PregoGroupedRow(
          title: Text(loc.harnessesEffectiveIdleTimeout),
          subtitle: Text(
            plugin.hasIdleTimeoutOverride ? loc.harnessesCustomIdleTimeout : loc.harnessesUsesDefaultIdleTimeout,
          ),
          trailing: Text(loc.harnessesIdleTimeoutMinutes(plugin.idleTimeoutMins)),
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
