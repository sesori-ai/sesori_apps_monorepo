part of "harness_settings_flow_view.dart";

const double _contentTopPadding = 10;

class const HarnessesSettingsView({
  super.key,

  /// How the page was raised, which decides how the user leaves it: a pushed
  /// page goes back, a modal one closes.
  required final HarnessSettingsPresentation presentation,
  required final Widget? connectionBanner,
  required final VoidCallback onClose,
  required final VoidCallback? onBack,
  required final void Function({required String pluginId}) onOpenHarness,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final isModal = switch (presentation) {
      HarnessSettingsPresentation.modal => true,
      HarnessSettingsPresentation.pushed => false,
    };
    final cubit = context.read<PluginManagementCubit>();
    final state = context.watch<PluginManagementCubit>().state;

    return PregoGlassScaffold(
      title: loc.settingsHarnessesTitle,
      titleMode: PregoTopNavigationTitleMode.inline,
      banner: connectionBanner,
      // Back leaves one level; X closes all settings in either presentation.
      automaticallyImplyLeading: false,
      onBack: isModal ? null : onBack,
      actions: [
        PregoButtonsIconGlass(
          icon: TablerRegular.x,
          semanticLabel: loc.settingsClose,
          // The shell decides whether this pops the opener or falls back
          // to its signed-in home route.
          onPressed: onClose,
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
              PluginManagementReady() => _ReadyView(state: state, onOpenHarness: onOpenHarness),
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

class const _LoadingView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.loc.harnessesLoading,
      child: const Padding(
        padding: EdgeInsetsDirectional.only(top: PregoSpacing.x4l),
        child: Center(child: PregoActivityIndicator(color: null)),
      ),
    );
  }
}

class const _UnsupportedView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedNoticeRow(
      icon: TablerRegular.info_circle,
      title: Text(context.loc.harnessesUnsupportedTitle),
      subtitle: Text(context.loc.harnessesUnsupportedDescription),
    );
  }
}

class const _FailureView() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoGroupedNoticeRow(
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
    );
  }
}

class const _ReadyView({
  required final PluginManagementReady state,
  required final void Function({required String pluginId}) onOpenHarness,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    final response = state.response;
    final timeoutBusy = switch (state.action) {
      PluginManagementActionInProgress(target: PluginManagementActionTargetAllHarnesses()) => true,
      PluginManagementActionIdle() ||
      PluginManagementActionInProgress() ||
      PluginManagementActionFailed() ||
      PluginManagementActionForceConfirmationRequired() => false,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HarnessErrors(state: state),
        if (response.plugins.isEmpty)
          PregoGroupedNoticeRow(
            icon: TablerRegular.info_circle,
            title: Text(loc.harnessesEmptyTitle),
            subtitle: Text(loc.harnessesEmptyDescription),
          ),
        for (final group in _HarnessGroup.values)
          if (response.plugins.any(
            (plugin) => _group(plugin: plugin, install: state.installs[plugin.setup.id]) == group,
          )) ...[
            SettingsSection(
              title: _groupTitle(context: context, group: group),
              child: PregoGroupedRows(
                color: context.prego.colors.bgSurface2,
                showDividers: false,
                children: [
                  for (final plugin in response.plugins)
                    if (_group(plugin: plugin, install: state.installs[plugin.setup.id]) == group)
                      _HarnessOverviewRow(
                        plugin: plugin,
                        state: state,
                        onOpen: () => onOpenHarness(pluginId: plugin.setup.id),
                      ),
                ],
              ),
            ),
            const SizedBox(height: PregoSpacing.xl),
          ],
        if (response.plugins.any(_supportsOperationalTimeout))
          SettingsSection(
            title: loc.harnessManagementDefaultsSection,
            child: PregoGroupedRows(
              color: context.prego.colors.bgSurface2,
              children: [
                PregoGroupedRow(
                  key: const Key("harness_management_default_timeout"),
                  icon: TablerRegular.clock,
                  title: Text(loc.harnessManagementDefaultTimeout),
                  subtitle: Text(loc.harnessManagementDefaultTimeoutDescription),
                  trailing: timeoutBusy
                      ? const PregoActivityIndicator(color: null)
                      : Text(
                          _timeoutLabel(context: context, minutes: response.defaultIdleTimeoutMins),
                          style: context.prego.textTheme.textSm.regular.copyWith(
                            color: context.prego.colors.textTertiary,
                          ),
                        ),
                  onTap: _controlsBlocked(state.action)
                      ? null
                      : () => _editDefaultTimeout(context: context, state: state),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class const _HarnessOverviewRow({
  required final PluginManagementMetadata plugin,
  required final PluginManagementReady state,
  required final VoidCallback onOpen,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final install = state.installs[plugin.setup.id];
    return PregoGroupedRow(
      key: Key("harnesses_card_${plugin.setup.id}"),
      minHeight: 68,
      leading: PregoBrandLogo(pluginId: plugin.setup.id, color: context.prego.colors.textTertiary),
      title: Text(plugin.setup.displayName),
      subtitle: _group(plugin: plugin, install: install) == _HarnessGroup.disabled
          ? null
          : _HarnessStatus(plugin: plugin, install: install, overview: true),
      onTap: onOpen,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HarnessSwitch(plugin: plugin, action: state.action, install: install),
          if (install case PluginInstallInProgress(:final progress))
            SizedBox(
              width: 44,
              height: 44,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _downloadFraction(progress: progress) == null
                    ? PregoActivityIndicator(color: context.prego.colors.fgBrandPrimary)
                    :
                      // ignore: no_slop_linter/avoid_flutter_spinners, determinate download progress is not a busy spinner
                      CircularProgressIndicator(
                        value: _downloadFraction(progress: progress),
                        color: context.prego.colors.fgBrandPrimary,
                        strokeWidth: 10,
                        semanticsLabel: _installPhase(context: context, progress: progress),
                      ),
              ),
            )
          else if (_canInstall(plugin: plugin))
            IconButton(
              key: Key("harness_management_install_${plugin.setup.id}"),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              tooltip: context.loc.harnessesInstallTitle(plugin.setup.displayName),
              icon: const Icon(TablerRegular.download),
              onPressed: _controlsBlocked(state.action)
                  ? null
                  : () => context.read<PluginManagementCubit>().install(pluginId: plugin.setup.id),
            )
          else
            const SizedBox(width: 44, height: 44, child: Icon(TablerRegular.chevron_right)),
        ],
      ),
    );
  }
}

class const _HarnessErrors({required final PluginManagementReady state}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
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
        ),
      ],
    );
  }
}
