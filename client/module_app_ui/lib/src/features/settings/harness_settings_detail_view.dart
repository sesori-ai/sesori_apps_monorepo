part of "harness_settings_flow_view.dart";

/// A URL-selected harness; never substitutes another registered identity.
class const HarnessSettingsDetailView({
  super.key,
  required final String pluginId,
  required final HarnessSettingsPresentation presentation,
  required final VoidCallback onBack,
  required final VoidCallback onClose,
  required final Widget? connectionBanner,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PluginManagementCubit>();
    final state = cubit.state;
    final plugin = state is PluginManagementReady
        ? state.response.plugins.where((plugin) => plugin.setup.id == pluginId).firstOrNull
        : null;
    return PregoGlassScaffold(
      title: plugin?.setup.displayName ?? context.loc.settingsHarnessesTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      onBack: onBack,
      onRefresh: cubit.refresh,
      banner: connectionBanner,
      actions: [
        if (presentation == HarnessSettingsPresentation.modal)
          PregoButtonsIconGlass(icon: TablerRegular.x, semanticLabel: context.loc.settingsClose, onPressed: onClose),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              PregoSpacing.xl,
              _contentTopPadding,
              PregoSpacing.xl,
              PregoSpacing.xl + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state is PluginManagementReady) _HarnessErrors(state: state),
                if (plugin != null && state is PluginManagementReady)
                  _HarnessActionFeedback(
                    state: state,
                    target: PluginManagementActionTarget.harness(pluginId: pluginId),
                  ),
                if (plugin != null && state is PluginManagementReady)
                  _HarnessControlCard(
                    plugin: plugin,
                    action: state.harnessActions[pluginId] ?? const PluginManagementActionState.idle(),
                    blocked: state.harnessControlsBlocked(pluginId: pluginId),
                    authentication: state.authentication,
                    install: state.installs[pluginId],
                    scanning: state.scanningPluginIds.contains(pluginId),
                    scanRejection: state.scanRejections[pluginId],
                  )
                else
                  switch (state) {
                    PluginManagementLoading() => const _LoadingView(),
                    PluginManagementUnsupported() => const _UnsupportedView(),
                    PluginManagementFailure() => const _FailureView(),
                    PluginManagementReady() => Text(context.loc.harnessManagementNotFound),
                  },
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class const _HarnessControlCard({
  required final PluginManagementMetadata plugin,
  required final PluginManagementActionState action,
  required final bool blocked,
  required final PluginAuthenticationPresentationState authentication,

  /// This harness' in-flight installation or retained failure.
  required final PluginInstallState? install,

  /// Whether a catalog scan covering this harness is running, started here
  /// or from a list's pull.
  required final bool scanning,

  /// Why this harness' last targeted scan was turned down, if it was. Never
  /// carries an accepted start.
  required final CatalogRescanStartResult? scanRejection,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final pluginId = plugin.setup.id;
    final capabilities = plugin.managementCapabilities;
    final supportsLifecycle = capabilities.contains(PluginManagementCapability.lifecycle);
    final showSetupRefresh =
        capabilities.contains(PluginManagementCapability.setupRefresh) &&
        plugin.setup.state != PluginSetupState.runtimeMissing;
    final supportsIdleTimeout = capabilities.contains(PluginManagementCapability.idleTimeout);
    final showExternal = !supportsLifecycle && !capabilities.contains(PluginManagementCapability.unknown);
    final setupReady = plugin.setup.state == PluginSetupState.ready;
    final runtimeVersion = plugin.setup.runtimeVersion;
    final enabled = plugin.runtimeState.isEnabled;
    final showOperational = setupReady && enabled;
    final showWork = showOperational && plugin.workState != PluginManagementWorkState.unknown;
    // The advertised capability is authoritative; unavailable does not imply an update.
    final showInstall = _canInstall(plugin: plugin);
    final showRestart = showOperational && supportsLifecycle;
    final showScan = plugin.runtimeState.isRoutable;
    // A rejection replaces the row's description until the user starts another
    // scan, so the answer to "why did nothing happen" stays on the card that
    // was tapped. The bridge's own error text is never among these.
    final scanRejectionText = switch (scanRejection) {
      null || CatalogRescanStartAccepted() => null,
      CatalogRescanStartNotImportable() => loc.harnessManagementScanNotReady,
      CatalogRescanStartUnsupported() => loc.harnessManagementScanUnsupported,
      CatalogRescanStartFailed() => loc.harnessManagementScanFailed,
    };
    final showTimeout = showOperational && supportsIdleTimeout;
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
    final authenticationActive = switch (authentication) {
      PluginAuthenticationPresentationIdle() || PluginAuthenticationPresentationFailed() => false,
      PluginAuthenticationPresentationStarting() ||
      PluginAuthenticationPresentationChallenge() ||
      PluginAuthenticationPresentationBrowserLaunchFailedState() ||
      PluginAuthenticationPresentationCancelling() ||
      PluginAuthenticationPresentationCancellingUncertain() => true,
    };
    final actionHint = plugin.actionHint ?? plugin.setup.actionHint;
    // The service reports an install as in-flight from the moment its command
    // is issued until the bridge's terminal event, so this covers the window
    // before the first progress event without borrowing the generic action
    // spinner (which any harness action would trigger).

    return KeyedSubtree(
      key: Key("harness_management_card_$pluginId"),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsSection(
            title: loc.harnessesStatusSetupSection,
            child: PregoGroupedRows(
              color: context.prego.colors.bgSurface2,
              key: Key("harnesses_detail_card_$pluginId"),
              children: [
                PregoGroupedRow(
                  key: Key("harness_management_identity_$pluginId"),
                  minHeight: 52,
                  verticalPadding: PregoSpacing.xs,
                  title: Row(
                    children: [
                      PregoBrandLogo(pluginId: pluginId, color: context.prego.colors.textTertiary),
                      const SizedBox(width: PregoSpacing.md),
                      Expanded(child: Text(plugin.setup.displayName)),
                    ],
                  ),
                  trailing: _HarnessSwitch(plugin: plugin, action: action, install: install, blocked: blocked),
                ),
                _FactRow(
                  title: loc.harnessesStatusLabel,
                  value: _HarnessStatus(plugin: plugin, install: install, overview: false),
                ),
                if (runtimeVersion != null) _FactRow(title: loc.harnessesVersionLabel, value: Text(runtimeVersion)),
                if (showWork)
                  _FactRow(
                    title: loc.harnessesActivityLabel,
                    value: Text(_workStatus(context: context, state: plugin.workState)),
                  ),
                if (actionHint != null && !(showInstall && plugin.setup.state == PluginSetupState.runtimeMissing))
                  PregoGroupedRow(title: Text(actionHint)),
                if (showExternal)
                  PregoGroupedRow(
                    key: Key("harness_management_external_$pluginId"),
                    icon: TablerRegular.info_circle,
                    title: Text(loc.harnessManagementExternalTitle),
                    subtitle: Text(loc.harnessManagementExternalDescription),
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
                    trailing: authenticationStarting ? const PregoActivityIndicator(color: null) : null,
                    // Only one authentication flow can exist. Its own row can reopen
                    // a retained challenge after uncertain cancellation; every other
                    // row stays disabled until that flow settles.
                    onTap:
                        (blocked && !authenticationForThisHarness) ||
                            authenticationStarting ||
                            (authenticationActive && !authenticationForThisHarness)
                        ? null
                        : authenticationForThisHarness
                        ? () => unawaited(
                            _showAuthenticationSheet(
                              context: context,
                              cubit: context.read<PluginManagementCubit>(),
                            ),
                          )
                        : () => context.read<PluginManagementCubit>().startAuthentication(pluginId: pluginId),
                  ),

                if (showInstall || install != null)
                  _HarnessInstallation(plugin: plugin, install: install, blocked: blocked),
              ],
            ),
          ),
          if (showSetupRefresh || showRestart || showScan) ...[
            const SizedBox(height: PregoSpacing.xl),
            SettingsSection(
              title: loc.harnessesActionsSection,
              child: PregoGroupedRows(
                color: context.prego.colors.bgSurface2,
                children: [
                  if (showSetupRefresh)
                    PregoGroupedRow(
                      key: Key("harness_management_refresh_$pluginId"),
                      icon: TablerRegular.refresh,
                      minHeight: 68,
                      verticalPadding: PregoSpacing.lg,
                      title: Text(loc.harnessManagementRefreshSetup),
                      subtitle: Text(loc.harnessManagementRefreshSetupDescription),
                      onTap: blocked
                          ? null
                          : () => context.read<PluginManagementCubit>().refreshSetup(pluginId: pluginId),
                    ),
                  if (showRestart)
                    PregoGroupedRow(
                      key: Key("harness_management_restart_$pluginId"),
                      icon: TablerRegular.rotate,
                      minHeight: 68,
                      verticalPadding: PregoSpacing.lg,
                      title: Text(loc.harnessManagementRestart),
                      subtitle: Text(loc.harnessManagementRestartDescription(plugin.setup.displayName)),
                      onTap: blocked ? null : () => context.read<PluginManagementCubit>().restart(pluginId: pluginId),
                    ),
                  // The keyboard-and-pointer twin of the lists' deep pull, which is
                  // invisible to a screen reader and awkward with a mouse. Offered only
                  // for a routable harness: `isEnabled` is also true for blocked and
                  // failed, which the bridge answers with a 503.
                  if (showScan)
                    PregoGroupedRow(
                      key: Key("harness_management_scan_$pluginId"),
                      icon: TablerRegular.refresh_dot,
                      verticalPadding: PregoSpacing.lg,
                      title: Text(loc.harnessManagementScan),
                      subtitle: Text(scanRejectionText ?? loc.harnessManagementScanDescription),
                      trailing: scanning ? const PregoActivityIndicator(color: null) : null,
                      onTap: blocked || scanning
                          ? null
                          : () => context.read<PluginManagementCubit>().startCatalogScanFor(pluginId: pluginId),
                    ),
                ],
              ),
            ),
          ],
          if (showTimeout) ...[
            const SizedBox(height: PregoSpacing.xl),
            SettingsSection(
              title: loc.harnessesAutomationSection,
              child: PregoGroupedRows(
                color: context.prego.colors.bgSurface2,
                children: [
                  if (showTimeout)
                    PregoGroupedRow(
                      key: Key("harness_management_timeout_$pluginId"),
                      icon: TablerRegular.clock,
                      verticalPadding: PregoSpacing.lg,
                      title: Text(loc.harnessManagementIdleTimeout),
                      subtitle: Text(loc.harnessManagementIdleTimeoutDescription),
                      trailing: Text(
                        _timeoutLabel(context: context, minutes: plugin.idleTimeoutMins),
                        style: context.prego.textTheme.textSm.regular.copyWith(
                          color: context.prego.colors.textTertiary,
                        ),
                      ),
                      onTap: blocked ? null : () => _editHarnessTimeout(context: context, plugin: plugin),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class const _HarnessInstallation({
  required final PluginManagementMetadata plugin,
  required final PluginInstallState? install,
  required final bool blocked,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final install = this.install;
    return Padding(
      padding: const EdgeInsets.all(PregoSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (install) {
            PluginInstallInProgress() => loc.harnessesInstallingTitle(plugin.setup.displayName),
            PluginInstallFailed() => loc.harnessesInstallationFailed,
            null => loc.harnessesInstallTitle(plugin.setup.displayName),
          }, style: context.prego.textTheme.textMd.medium.copyWith(color: context.prego.colors.textPrimary)),
          const SizedBox(height: PregoSpacing.md),
          if (install case PluginInstallInProgress(:final progress)) ...[
            Text(
              _installPhase(context: context, progress: progress),
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
            const SizedBox(height: PregoSpacing.md),
            LinearProgressIndicator(
              value: _downloadFraction(progress: progress),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
              color: context.prego.colors.fgBrandPrimary,
              backgroundColor: context.prego.colors.bgSurface1,
            ),
          ] else ...[
            Text(
              install is PluginInstallFailed
                  ? loc.harnessesInstallationFailedDescription
                  : loc.harnessesInstallDescription,
              style: context.prego.textTheme.textXs.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
            if (_canInstall(plugin: plugin)) ...[
              const SizedBox(height: PregoSpacing.xl),
              PregoButtonsSolid(
                key: Key("harness_management_install_${plugin.setup.id}"),
                label: install is PluginInstallFailed
                    ? loc.harnessesRestartInstallation
                    : loc.harnessesStartInstallation,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: blocked
                    ? null
                    : () => context.read<PluginManagementCubit>().install(pluginId: plugin.setup.id),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class const _FactRow({required final String title, required final Widget value}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => PregoGroupedRow(
      minHeight: 52,
      title: Text(title),
      trailing: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: constraints.maxWidth * .55),
        child: DefaultTextStyle(
          textAlign: TextAlign.end,
          style: context.prego.textTheme.textMd.regular.copyWith(color: context.prego.colors.textSecondary),
          child: value,
        ),
      ),
    ),
  );
}

bool _supportsOperationalTimeout(PluginManagementMetadata plugin) {
  return plugin.setup.state == PluginSetupState.ready &&
      plugin.runtimeState.isEnabled &&
      plugin.managementCapabilities.contains(PluginManagementCapability.idleTimeout);
}
