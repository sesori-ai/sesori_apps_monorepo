import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../core/di/injection.dart";
import "../../core/extensions/build_context_x.dart";
import "../../core/routing/app_router.dart";
import "../../core/widgets/connection_banner.dart";
import "widgets/settings_section.dart";

const double _contentTopPadding = 10.0;

class const HarnessesSettingsScreen({
  super.key,
  /// How the page was raised, which decides how the user leaves it: a pushed
  /// page goes back, a modal one closes.
  required final HarnessSettingsPresentation presentation,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PluginManagementCubit(
        service: getIt<PluginManagementService>(),
        urlLauncher: getIt<UrlLauncher>(),
      ),
      child: _HarnessesSettingsBody(presentation: presentation),
    );
  }
}

class const _HarnessesSettingsBody({required final HarnessSettingsPresentation presentation}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isModal = switch (presentation) {
      HarnessSettingsPresentation.modal => true,
      HarnessSettingsPresentation.pushed => false,
    };
    final cubit = context.read<PluginManagementCubit>();
    final state = context.watch<PluginManagementCubit>().state;

    return MultiBlocListener(
      listeners: [
        BlocListener<PluginManagementCubit, PluginManagementState>(
          listenWhen: (previous, current) => _forceConfirmation(previous) != _forceConfirmation(current),
          listener: (context, state) {
            final confirmation = _forceConfirmation(state);
            if (confirmation == null) return;
            unawaited(_showForceConfirmation(context: context, cubit: cubit, confirmation: confirmation));
          },
        ),
        BlocListener<PluginManagementCubit, PluginManagementState>(
          listenWhen: (previous, current) =>
              _authenticationChallenge(state: previous) == null && _authenticationChallenge(state: current) != null,
          listener: (context, state) {
            final challenge = _authenticationChallenge(state: state);
            if (challenge == null) return;
            unawaited(_showAuthenticationSheet(context: context, cubit: cubit));
          },
        ),
      ],
      child: PregoGlassScaffold(
        title: loc.settingsHarnessesTitle,
        titleMode: PregoTopNavigationTitleMode.inline,
        banner: ConnectionBanner.maybeFor(context),
        // A modal has no page below it to go back to, so the close button is
        // its only way out and an implied back chevron would be a second,
        // redundant dismissal in the same bar. A pushed page is the other way
        // round: the settings list sits underneath and the back chevron is the
        // way back to it.
        automaticallyImplyLeading: !isModal,
        actions: [
          if (isModal)
            PregoButtonsIconGlass(
              icon: TablerRegular.x,
              semanticLabel: loc.settingsClose,
              // Closing the modal means going back to whatever raised it. Only
              // a deep link arrives with nothing underneath, and that falls
              // back to the app's home.
              onPressed: () => context.canPop() ? context.pop() : context.goRoute(const AppRoute.projects()),
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

({String pluginId, Uri verificationUri, String userCode, bool cancelling, bool uncertain, bool browserFailed})?
_authenticationChallenge({required PluginManagementState state}) => switch (state) {
  PluginManagementReady(
    authentication: PluginAuthenticationPresentationChallenge(:final pluginId, :final verificationUri, :final userCode),
  ) =>
    (
      pluginId: pluginId,
      verificationUri: verificationUri,
      userCode: userCode,
      cancelling: false,
      uncertain: false,
      browserFailed: false,
    ),
  PluginManagementReady(
    authentication: PluginAuthenticationPresentationBrowserLaunchFailedState(
      :final pluginId,
      :final verificationUri,
      :final userCode,
    ),
  ) =>
    (
      pluginId: pluginId,
      verificationUri: verificationUri,
      userCode: userCode,
      cancelling: false,
      uncertain: false,
      browserFailed: true,
    ),
  PluginManagementReady(
    authentication: PluginAuthenticationPresentationCancelling(
      :final pluginId,
      :final verificationUri,
      :final userCode,
    ),
  ) =>
    (
      pluginId: pluginId,
      verificationUri: verificationUri,
      userCode: userCode,
      cancelling: true,
      uncertain: false,
      browserFailed: false,
    ),
  PluginManagementReady(
    authentication: PluginAuthenticationPresentationCancellingUncertain(
      :final pluginId,
      :final verificationUri,
      :final userCode,
    ),
  ) =>
    (
      pluginId: pluginId,
      verificationUri: verificationUri,
      userCode: userCode,
      cancelling: true,
      uncertain: true,
      browserFailed: false,
    ),
  PluginManagementReady() ||
  PluginManagementLoading() ||
  PluginManagementUnsupported() ||
  PluginManagementFailure() => null,
};

PluginManagementActionForceConfirmationRequired? _forceConfirmation(PluginManagementState state) => switch (state) {
  PluginManagementReady(action: final PluginManagementActionForceConfirmationRequired confirmation) => confirmation,
  PluginManagementReady() ||
  PluginManagementLoading() ||
  PluginManagementUnsupported() ||
  PluginManagementFailure() => null,
};

class const _LoadingView() extends StatelessWidget {
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

class const _UnsupportedView() extends StatelessWidget {
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

class const _FailureView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRows(
      children: [
        PregoGroupedRow(
          icon: TablerRegular.alert_triangle,
          title: Text(context.loc.harnessesLoadFailedTitle),
          subtitle: Text(context.loc.harnessesLoadFailedDescription),
          trailing: KeyedSubtree(
            key: const Key("harness_management_retry"),
            child: PregoButtonsSolid(
              key: const Key("harnesses_retry"),
              label: context.loc.harnessesRetry,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.sm,
              onPressed: context.read<PluginManagementCubit>().refresh,
            ),
          ),
          isLast: true,
        ),
      ],
    );
  }
}

class const _ReadyView({required final PluginManagementReady state}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final response = state.response;
    final showDefaultTimeout = response.plugins.any(_supportsOperationalTimeout);
    final defaultTimeoutActionInProgress = switch (state.action) {
      PluginManagementActionInProgress(target: PluginManagementActionTargetAllHarnesses()) => true,
      PluginManagementActionIdle() ||
      PluginManagementActionInProgress() ||
      PluginManagementActionFailed() ||
      PluginManagementActionForceConfirmationRequired() => false,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.refresh is PluginManagementRefreshFailed) ...[
          KeyedSubtree(
            key: const Key("harness_management_refresh_error"),
            child: _MessageRow(
              key: const Key("harnesses_refresh_error"),
              title: loc.harnessesRefreshFailedTitle,
              description: loc.harnessesRefreshFailedDescription,
              dismissLabel: loc.harnessesDismissRefreshError,
              onDismiss: context.read<PluginManagementCubit>().dismissRefreshError,
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        if (state.action case final PluginManagementActionFailed failure) ...[
          KeyedSubtree(
            key: const Key("harnesses_action_error"),
            child: _MessageRow(
              key: const Key("harness_management_action_error"),
              title: loc.harnessManagementActionFailedTitle,
              description: _actionErrorDescription(context: context, error: failure.error),
              dismissLabel: loc.harnessManagementDismissActionError,
              onDismiss: context.read<PluginManagementCubit>().dismissActionError,
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        if (state.authentication case final PluginAuthenticationPresentationFailed failure) ...[
          _MessageRow(
            key: const Key("harness_authentication_error"),
            title: loc.harnessAuthenticationFailedTitle,
            description: _authenticationErrorDescription(context: context, error: failure.error),
            dismissLabel: loc.harnessAuthenticationDismissError,
            onDismiss: context.read<PluginManagementCubit>().dismissAuthentication,
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        Text(
          loc.harnessManagementDescription,
          style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
        ),
        const SizedBox(height: PregoSpacing.xl),
        if (showDefaultTimeout) ...[
          SettingsSection(
            title: loc.harnessManagementDefaultsSection,
            child: PregoGroupedRows(
              children: [
                PregoGroupedRow(
                  key: const Key("harness_management_default_timeout"),
                  icon: TablerRegular.clock,
                  title: Text(loc.harnessManagementDefaultTimeout),
                  subtitle: Text(loc.harnessManagementDefaultTimeoutDescription),
                  trailing: defaultTimeoutActionInProgress
                      ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)
                      : Text(_timeoutLabel(context: context, minutes: response.defaultIdleTimeoutMins)),
                  onTap: _controlsBlocked(state.action)
                      ? null
                      : () => _editDefaultTimeout(context: context, state: state),
                  isLast: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
        ],
        SettingsSection(
          title: loc.harnessesRegisteredSection,
          child: response.plugins.isEmpty
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
                    for (var index = 0; index < response.plugins.length; index++) ...[
                      _HarnessControlCard(
                        plugin: response.plugins[index],
                        isDefault: response.plugins[index].setup.id == response.defaultPluginId,
                        action: state.action,
                        authentication: state.authentication,
                        install: state.installs[response.plugins[index].setup.id],
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

class const _MessageRow({
    super.key,
    required final String title,
    required final String description,
    required final String dismissLabel,
    required final VoidCallback onDismiss,
  }) extends StatelessWidget {
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

class const _HarnessControlCard({
    required final PluginManagementMetadata plugin,
    required final bool isDefault,
    required final PluginManagementActionState action,
    required final PluginAuthenticationPresentationState authentication,
    /// This harness' in-flight managed runtime install, when one is running.
  required final PluginInstallProgress? install,
  }) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pluginId = plugin.setup.id;
    final capabilities = plugin.managementCapabilities;
    final supportsLifecycle = capabilities.contains(PluginManagementCapability.lifecycle);
    final showSetupRefresh = capabilities.contains(PluginManagementCapability.setupRefresh);
    final supportsIdleTimeout = capabilities.contains(PluginManagementCapability.idleTimeout);
    final showExternal = !supportsLifecycle && !capabilities.contains(PluginManagementCapability.unknown);
    final setupReady = plugin.setup.state == PluginSetupState.ready;
    final runtimeKnown = plugin.runtimeState != PluginRuntimeState.unknown;
    final enabled = plugin.runtimeState.isEnabled;
    final showOperational = setupReady && enabled;
    final showRuntime = showOperational;
    final showWork = showOperational && plugin.workState != PluginManagementWorkState.unknown;
    final showLifecycle = supportsLifecycle && runtimeKnown;
    // Install is offered only while the bridge advertises it and the runtime
    // is genuinely missing or too old — the two states a managed install fixes.
    final showInstall =
        capabilities.contains(PluginManagementCapability.install) &&
        (plugin.setup.state == PluginSetupState.runtimeMissing || plugin.setup.state == PluginSetupState.unavailable);
    final showRestart = showOperational && supportsLifecycle;
    final showTimeout = showOperational && supportsIdleTimeout;
    final showClearTimeout = showTimeout && plugin.hasIdleTimeoutOverride;
    final supportsAuthentication = capabilities.contains(PluginManagementCapability.authentication);
    final showAuthentication = supportsAuthentication && plugin.setup.state == PluginSetupState.authenticationRequired;
    final authenticationForThisHarness = switch (authentication) {
      PluginAuthenticationPresentationStarting(pluginId: final targetPluginId) ||
      PluginAuthenticationPresentationChallenge(pluginId: final targetPluginId) ||
      PluginAuthenticationPresentationBrowserLaunchFailedState(pluginId: final targetPluginId) ||
      PluginAuthenticationPresentationCancelling(pluginId: final targetPluginId) ||
      PluginAuthenticationPresentationCancellingUncertain(pluginId: final targetPluginId) => targetPluginId == pluginId,
      PluginAuthenticationPresentationIdle() || PluginAuthenticationPresentationFailed() => false,
    };
    final authenticationStarting = switch (authentication) {
      PluginAuthenticationPresentationStarting(pluginId: final targetPluginId) => targetPluginId == pluginId,
      PluginAuthenticationPresentationIdle() ||
      PluginAuthenticationPresentationChallenge() ||
      PluginAuthenticationPresentationBrowserLaunchFailedState() ||
      PluginAuthenticationPresentationCancelling() ||
      PluginAuthenticationPresentationCancellingUncertain() ||
      PluginAuthenticationPresentationFailed() => false,
    };
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
    // The service reports an install as in-flight from the moment its command
    // is issued until the bridge's terminal event, so this covers the window
    // before the first progress event without borrowing the generic action
    // spinner (which any harness action would trigger).
    final installing = install != null;

    return KeyedSubtree(
      key: Key("harness_management_card_$pluginId"),
      child: PregoGroupedRows(
        key: Key("harnesses_card_$pluginId"),
        children: [
          PregoGroupedRow(
            leading: PregoBrandLogo(pluginId: pluginId, color: context.prego.colors.textTertiary),
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
            trailing: actionForThisHarness ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary) : null,
          ),
          _FactRow(
            title: loc.harnessesSetupStatus,
            value: _setupStatus(context: context, state: plugin.setup.state),
            isLast:
                !(showRuntime ||
                    showWork ||
                    showExternal ||
                    showInstall ||
                    showAuthentication ||
                    showLifecycle ||
                    showSetupRefresh ||
                    showRestart ||
                    showTimeout ||
                    showClearTimeout),
          ),
          if (showAuthentication)
            PregoGroupedRow(
              key: Key("harness_authentication_$pluginId"),
              icon: TablerRegular.login,
              title: Text(
                plugin.authenticationState == PluginAuthenticationState.inProgress || authenticationForThisHarness
                    ? loc.harnessAuthenticationContinue
                    : loc.harnessAuthenticationLogIn,
              ),
              subtitle: Text(loc.harnessAuthenticationDescription),
              trailing: authenticationStarting
                  ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)
                  : null,
              onTap: blocked || authenticationStarting
                  ? null
                  : () => context.read<PluginManagementCubit>().startAuthentication(pluginId: pluginId),
              isLast:
                  !(showRuntime ||
                      showWork ||
                      showExternal ||
                      showInstall ||
                      showLifecycle ||
                      showSetupRefresh ||
                      showRestart ||
                      showTimeout ||
                      showClearTimeout),
            ),
          if (showRuntime)
            _FactRow(
              title: loc.harnessesRuntimeStatus,
              value: _runtimeStatus(context: context, state: plugin.runtimeState),
              isLast:
                  !(showWork ||
                      showExternal ||
                      showInstall ||
                      showLifecycle ||
                      showSetupRefresh ||
                      showRestart ||
                      showTimeout ||
                      showClearTimeout),
            ),
          if (showWork)
            _FactRow(
              title: loc.harnessesWorkStatus,
              value: _workStatus(context: context, state: plugin.workState),
              isLast:
                  !(showExternal ||
                      showInstall ||
                      showLifecycle ||
                      showSetupRefresh ||
                      showRestart ||
                      showTimeout ||
                      showClearTimeout),
            ),
          if (showExternal)
            PregoGroupedRow(
              key: Key("harness_management_external_$pluginId"),
              icon: TablerRegular.info_circle,
              title: Text(loc.harnessManagementExternalTitle),
              subtitle: Text(loc.harnessManagementExternalDescription),
              isLast:
                  !(showInstall || showLifecycle || showSetupRefresh || showRestart || showTimeout || showClearTimeout),
            ),
          if (showInstall)
            PregoGroupedRow(
              key: Key("harness_management_install_$pluginId"),
              icon: TablerRegular.download,
              title: Text(loc.harnessManagementInstall),
              subtitle: Text(
                switch (install) {
                  null => loc.harnessManagementInstallDescription,
                  PluginInstallProgress(phase: PluginInstallPhase.downloading, :final percent?) =>
                    loc.harnessManagementInstallDownloadingPercent(percent),
                  PluginInstallProgress(phase: PluginInstallPhase.downloading) =>
                    loc.harnessManagementInstallDownloading,
                  PluginInstallProgress(phase: PluginInstallPhase.verifying) => loc.harnessManagementInstallVerifying,
                  PluginInstallProgress(phase: PluginInstallPhase.extracting) => loc.harnessManagementInstallExtracting,
                  PluginInstallProgress(phase: PluginInstallPhase.finalizing) => loc.harnessManagementInstallFinishing,
                  // A phase only a newer bridge names: report work without
                  // claiming which step it is.
                  PluginInstallProgress() => loc.harnessManagementInstallInProgress,
                },
              ),
              trailing: installing ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary) : null,
              // Also blocked between the tap and the first progress event: the
              // command returns as soon as the bridge accepts it, long before
              // any phase arrives.
              onTap: blocked || installing
                  ? null
                  : () => context.read<PluginManagementCubit>().install(pluginId: pluginId),
              isLast: !(showLifecycle || showSetupRefresh || showRestart || showTimeout || showClearTimeout),
            ),
          if (showLifecycle)
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
                isLast: !(showSetupRefresh || showRestart || showTimeout || showClearTimeout),
              ),
            ),
          if (showSetupRefresh)
            PregoGroupedRow(
              key: Key("harness_management_refresh_$pluginId"),
              icon: TablerRegular.refresh,
              title: Text(loc.harnessManagementRefreshSetup),
              onTap: blocked ? null : () => context.read<PluginManagementCubit>().refreshSetup(pluginId: pluginId),
              isLast: !(showRestart || showTimeout || showClearTimeout),
            ),
          if (showRestart)
            PregoGroupedRow(
              key: Key("harness_management_restart_$pluginId"),
              icon: TablerRegular.rotate_clockwise,
              title: Text(loc.harnessManagementRestart),
              onTap: blocked ? null : () => context.read<PluginManagementCubit>().restart(pluginId: pluginId),
              isLast: !(showTimeout || showClearTimeout),
            ),
          if (showTimeout)
            PregoGroupedRow(
              key: Key("harness_management_timeout_$pluginId"),
              icon: TablerRegular.clock,
              title: Text(loc.harnessManagementIdleTimeout),
              subtitle: Text(
                plugin.idleTimeoutMins <= 0
                    ? loc.harnessesNoIdleTimeoutDescription
                    : plugin.hasIdleTimeoutOverride
                    ? loc.harnessesCustomIdleTimeout
                    : loc.harnessesUsesDefaultIdleTimeout,
              ),
              trailing: Text(_timeoutLabel(context: context, minutes: plugin.idleTimeoutMins)),
              onTap: blocked ? null : () => _editHarnessTimeout(context: context, plugin: plugin),
              isLast: !showClearTimeout,
            ),
          if (showClearTimeout)
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
      ),
    );
  }
}

class const _FactRow({required final String title, required final String value, required final bool isLast}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedRow(
      title: Text(title),
      trailing: Text(
        value,
        textAlign: TextAlign.end,
        style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
      ),
      isLast: isLast,
    );
  }
}

bool _supportsOperationalTimeout(PluginManagementMetadata plugin) {
  return plugin.setup.state == PluginSetupState.ready &&
      plugin.runtimeState.isEnabled &&
      plugin.managementCapabilities.contains(PluginManagementCapability.idleTimeout);
}

bool _controlsBlocked(PluginManagementActionState action) {
  return action is PluginManagementActionInProgress || action is PluginManagementActionForceConfirmationRequired;
}

Future<void> _editDefaultTimeout({required BuildContext context, required PluginManagementReady state}) async {
  final cubit = context.read<PluginManagementCubit>();
  final result = await _showTimeoutSheet(
    context: context,
    title: context.loc.harnessManagementDefaultTimeoutDialogTitle,
    allowUseDefault: false,
    initialChoice: state.response.defaultIdleTimeoutMins <= 0 ? _TimeoutChoice.noTimeout : _TimeoutChoice.custom,
    initialMinutes: state.response.defaultIdleTimeoutMins,
  );
  switch (result) {
    case null:
      return;
    case _UseDefaultTimeoutResult():
      throw StateError("The global timeout cannot inherit another timeout");
    case _ApplyTimeoutResult(:final input):
      await cubit.applyIdleTimeoutToAll(input: input);
  }
}

Future<void> _editHarnessTimeout({required BuildContext context, required PluginManagementMetadata plugin}) async {
  final cubit = context.read<PluginManagementCubit>();
  final initialChoice = switch ((plugin.hasIdleTimeoutOverride, plugin.idleTimeoutMins)) {
    (false, _) => _TimeoutChoice.useDefault,
    (true, <= 0) => _TimeoutChoice.noTimeout,
    (true, _) => _TimeoutChoice.custom,
  };
  final result = await _showTimeoutSheet(
    context: context,
    title: context.loc.harnessManagementTimeoutDialogTitle(plugin.setup.displayName),
    allowUseDefault: true,
    initialChoice: initialChoice,
    initialMinutes: plugin.idleTimeoutMins,
  );
  switch (result) {
    case null:
      return;
    case _UseDefaultTimeoutResult():
      await cubit.clearIdleTimeoutOverride(pluginId: plugin.setup.id);
    case _ApplyTimeoutResult(:final input):
      await cubit.setIdleTimeoutOverride(pluginId: plugin.setup.id, input: input);
  }
}

Future<_TimeoutResult?> _showTimeoutSheet({
  required BuildContext context,
  required String title,
  required bool allowUseDefault,
  required _TimeoutChoice initialChoice,
  required int initialMinutes,
}) {
  return showPregoBottomSheet<_TimeoutResult>(
    context: context,
    title: title,
    builder: (_) => _TimeoutSheet(
      allowUseDefault: allowUseDefault,
      initialChoice: initialChoice,
      initialMinutes: initialMinutes,
    ),
  );
}

enum _TimeoutChoice() { useDefault, noTimeout, custom }

sealed class const _TimeoutResult();

final class const _UseDefaultTimeoutResult() extends _TimeoutResult;

final class const _ApplyTimeoutResult({required final PluginManagementIdleTimeoutInput input}) extends _TimeoutResult;

class const _TimeoutSheet({
    required final bool allowUseDefault,
    required final _TimeoutChoice initialChoice,
    required final int initialMinutes,
  }) extends StatefulWidget {
  @override
  State<_TimeoutSheet> createState() => _TimeoutSheetState();
}

class _TimeoutSheetState() extends State<_TimeoutSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialMinutes > 0 ? widget.initialMinutes.toString() : "",
  );
  late _TimeoutChoice _choice = widget.initialChoice;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(_TimeoutChoice? choice) {
    if (choice == null || choice == _choice) return;
    setState(() => _choice = choice);
  }

  void _submit() {
    final result = switch (_choice) {
      _TimeoutChoice.useDefault => const _UseDefaultTimeoutResult(),
      _TimeoutChoice.noTimeout => const _ApplyTimeoutResult(
        input: PluginManagementIdleTimeoutInput.noTimeout(),
      ),
      _TimeoutChoice.custom => _customResult(),
    };
    if (result == null) return;
    context.pop(result);
  }

  _TimeoutResult? _customResult() {
    if (!(_formKey.currentState?.validate() ?? false)) return null;
    return _ApplyTimeoutResult(
      input: PluginManagementIdleTimeoutInput.custom(input: _controller.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RadioGroup<_TimeoutChoice>(
            groupValue: _choice,
            onChanged: _select,
            child: PregoGroupedRows(
              children: [
                if (widget.allowUseDefault)
                  MergeSemantics(
                    child: PregoGroupedRow(
                      key: const Key("harness_management_timeout_use_default"),
                      title: Text(loc.harnessManagementTimeoutUseDefault),
                      trailing: Radio<_TimeoutChoice>(
                        value: _TimeoutChoice.useDefault,
                        activeColor: context.prego.colors.fgBrandPrimary,
                      ),
                      onTap: () => _select(_TimeoutChoice.useDefault),
                    ),
                  ),
                MergeSemantics(
                  child: PregoGroupedRow(
                    key: const Key("harness_management_timeout_no_timeout"),
                    title: Text(loc.harnessManagementTimeoutNoTimeout),
                    trailing: Radio<_TimeoutChoice>(
                      value: _TimeoutChoice.noTimeout,
                      activeColor: context.prego.colors.fgBrandPrimary,
                    ),
                    onTap: () => _select(_TimeoutChoice.noTimeout),
                  ),
                ),
                MergeSemantics(
                  child: PregoGroupedRow(
                    key: const Key("harness_management_timeout_custom"),
                    title: Text(loc.harnessManagementTimeoutCustom),
                    trailing: Radio<_TimeoutChoice>(
                      value: _TimeoutChoice.custom,
                      activeColor: context.prego.colors.fgBrandPrimary,
                    ),
                    onTap: () => _select(_TimeoutChoice.custom),
                    isLast: true,
                  ),
                ),
              ],
            ),
          ),
          if (_choice == _TimeoutChoice.custom) ...[
            const SizedBox(height: PregoSpacing.xl),
            Form(
              key: _formKey,
              child: PregoInputField(
                key: const Key("harness_management_timeout_input"),
                controller: _controller,
                label: loc.harnessManagementTimeoutMinutesLabel,
                isRequired: true,
                autofocus: true,
                autocorrect: false,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  final minutes = int.tryParse(value?.trim() ?? "");
                  return minutes != null && minutes > 0 ? null : loc.harnessManagementInvalidTimeout;
                },
                onSubmitted: (_) => _submit(),
              ),
            ),
            const SizedBox(height: PregoSpacing.sm),
            Text(
              loc.harnessManagementTimeoutHelp,
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ],
          const SizedBox(height: PregoSpacing.x2l),
          Row(
            children: [
              Expanded(
                child: PregoButtonsSolid(
                  key: const Key("harness_management_timeout_cancel"),
                  label: loc.harnessManagementCancel,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  fullWidth: true,
                  onPressed: () => context.pop(),
                ),
              ),
              const SizedBox(width: PregoSpacing.md),
              Expanded(
                child: PregoButtonsSolid(
                  key: const Key("harness_management_timeout_save"),
                  label: loc.harnessManagementSave,
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

Future<void> _showForceConfirmation({
  required BuildContext context,
  required PluginManagementCubit cubit,
  required PluginManagementActionForceConfirmationRequired confirmation,
}) async {
  final confirmed = await showPregoBottomSheet<bool>(
    context: context,
    title: confirmation.action == PluginManagementForceAction.disable
        ? context.loc.harnessManagementForceDisableTitle
        : context.loc.harnessManagementForceRestartTitle,
    isDismissible: false,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.harnessManagementForceDescription,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          Row(
            children: [
              Expanded(
                child: PregoButtonsSolid(
                  key: const Key("harness_management_force_cancel"),
                  label: context.loc.harnessManagementCancel,
                  hierarchy: PregoButtonsSolidHierarchy.secondary,
                  size: PregoButtonsSolidSize.lg,
                  fullWidth: true,
                  onPressed: () => sheetContext.pop(false),
                ),
              ),
              const SizedBox(width: PregoSpacing.md),
              Expanded(
                child: PregoButtonsSolid(
                  key: const Key("harness_management_force_confirm"),
                  label: context.loc.harnessManagementForceAction,
                  hierarchy: PregoButtonsSolidHierarchy.primary,
                  size: PregoButtonsSolidSize.lg,
                  type: PregoButtonsSolidType.destructive,
                  fullWidth: true,
                  onPressed: () => sheetContext.pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  if (confirmed ?? false) {
    await cubit.confirmForce();
  } else {
    cubit.dismissForceConfirmation();
  }
}

Future<void> _showAuthenticationSheet({
  required BuildContext context,
  required PluginManagementCubit cubit,
}) async {
  await showPregoBottomSheet<void>(
    context: context,
    title: context.loc.harnessAuthenticationSheetTitle,
    builder: (_) => BlocProvider<PluginManagementCubit>.value(
      value: cubit,
      child: const _AuthenticationSheet(),
    ),
  );
  final authentication = switch (cubit.state) {
    PluginManagementReady(:final authentication) => authentication,
    PluginManagementLoading() || PluginManagementUnsupported() || PluginManagementFailure() => null,
  };
  if (!cubit.isClosed &&
      _authenticationChallenge(state: cubit.state) != null &&
      authentication is! PluginAuthenticationPresentationCancelling &&
      authentication is! PluginAuthenticationPresentationCancellingUncertain) {
    cubit.dismissAuthentication();
  }
}

class const _AuthenticationSheet() extends StatelessWidget {
  Future<void> _copyCode({required BuildContext context, required String code}) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.harnessAuthenticationCodeCopied)),
      );
    } on Object catch (error, stackTrace) {
      logw("Failed to copy authentication code", error, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_authenticationChallenge(state: context.read<PluginManagementCubit>().state) == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) context.pop();
      });
    }
    return BlocListener<PluginManagementCubit, PluginManagementState>(
      listenWhen: (previous, current) =>
          _authenticationChallenge(state: previous) != null && _authenticationChallenge(state: current) == null,
      listener: (context, _) {
        if (ModalRoute.of(context)?.isCurrent ?? false) context.pop();
      },
      child: _buildContent(context: context),
    );
  }

  Widget _buildContent({required BuildContext context}) {
    final loc = context.loc;
    final state = context.watch<PluginManagementCubit>().state;
    final challenge = _authenticationChallenge(state: state);
    if (challenge == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: Center(child: PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)),
      );
    }

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: loc.harnessAuthenticationSecuritySemantics,
            child: Text(
              loc.harnessAuthenticationSecurityDescription,
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ),
          const SizedBox(height: PregoSpacing.xl),
          PregoGroupedRows(
            children: [
              PregoGroupedRow(
                key: const Key("harness_authentication_code"),
                icon: TablerRegular.key,
                title: Text(loc.harnessAuthenticationCodeLabel),
                subtitle: SelectableText(challenge.userCode),
                trailing: IconButton(
                  key: const Key("harness_authentication_copy"),
                  tooltip: loc.harnessAuthenticationCopyCode,
                  onPressed: () => _copyCode(context: context, code: challenge.userCode),
                  icon: const Icon(TablerRegular.copy),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: PregoSpacing.xl),
          if (challenge.browserFailed) ...[
            Text(
              loc.harnessAuthenticationBrowserFailed,
              textAlign: TextAlign.center,
              style: context.prego.textTheme.textSm.medium.copyWith(color: context.prego.colors.textErrorPrimary),
            ),
            const SizedBox(height: PregoSpacing.md),
          ],
          Text(
            challenge.uncertain
                ? loc.harnessAuthenticationCancellingUncertain
                : challenge.cancelling
                ? loc.harnessAuthenticationCancelling
                : loc.harnessAuthenticationWaiting,
            textAlign: TextAlign.center,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: const Key("harness_authentication_open_browser"),
            label: loc.harnessAuthenticationOpenBrowser,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: challenge.cancelling ? null : context.read<PluginManagementCubit>().launchAuthenticationBrowser,
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            key: const Key("harness_authentication_cancel"),
            label: challenge.cancelling && !challenge.uncertain
                ? loc.harnessAuthenticationCancelling
                : loc.harnessAuthenticationCancel,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            type: PregoButtonsSolidType.destructive,
            fullWidth: true,
            isLoading: challenge.cancelling && !challenge.uncertain,
            onPressed: challenge.cancelling && !challenge.uncertain
                ? null
                : context.read<PluginManagementCubit>().cancelAuthentication,
          ),
        ],
      ),
    );
  }
}

String _authenticationErrorDescription({
  required BuildContext context,
  required PluginAuthenticationPresentationError error,
}) => switch (error) {
  PluginAuthenticationPresentationNotFound() => context.loc.harnessAuthenticationNotFound,
  PluginAuthenticationPresentationUnsupported() => context.loc.harnessAuthenticationUnsupported,
  PluginAuthenticationPresentationConflict() => context.loc.harnessAuthenticationConflict,
  PluginAuthenticationPresentationUncertain() => context.loc.harnessAuthenticationUncertain,
  PluginAuthenticationPresentationInvalidChallenge() => context.loc.harnessAuthenticationInvalidChallenge,
  PluginAuthenticationPresentationRemoteError(:final message) => message,
  PluginAuthenticationPresentationRequestError() => context.loc.harnessAuthenticationRequestFailed,
};

String _actionErrorDescription({required BuildContext context, required PluginManagementActionError error}) =>
    switch (error) {
      PluginManagementInvalidIdleTimeout() => context.loc.harnessManagementInvalidTimeout,
      PluginManagementActionNotFound() => context.loc.harnessManagementNotFound,
      PluginManagementActionConflict() => context.loc.harnessManagementConflict,
      PluginManagementActionUncertain() => context.loc.harnessManagementUncertain,
      PluginManagementActionRequestError() => context.loc.harnessManagementRequestFailed,
    };

String _timeoutLabel({required BuildContext context, required int minutes}) {
  return minutes <= 0 ? context.loc.harnessesNoIdleTimeout : context.loc.harnessesIdleTimeoutMinutes(minutes);
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
