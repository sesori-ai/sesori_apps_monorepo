part of "harness_settings_flow_view.dart";

enum _HarnessGroup() {
  needsAttention,
  enabled,
  notInstalled,
  disabled,
}

_HarnessGroup _group({required PluginManagementMetadata plugin, required PluginInstallState? install}) {
  if (install is PluginInstallInProgress) return _HarnessGroup.notInstalled;
  // A stopping harness is winding down, not asking for attention. Group it with
  // disabled harnesses so a toggled-off harness lands where it will settle.
  if (plugin.runtimeState == PluginRuntimeState.disabled || plugin.runtimeState == PluginRuntimeState.stopping) {
    return _HarnessGroup.disabled;
  }
  if (plugin.setup.state == PluginSetupState.runtimeMissing) return _HarnessGroup.notInstalled;
  if (plugin.setup.state == PluginSetupState.ready &&
      (plugin.runtimeState == PluginRuntimeState.dormant ||
          plugin.runtimeState == PluginRuntimeState.starting ||
          plugin.runtimeState == PluginRuntimeState.active)) {
    return _HarnessGroup.enabled;
  }
  return _HarnessGroup.needsAttention;
}

String _groupTitle({required BuildContext context, required _HarnessGroup group}) => switch (group) {
  _HarnessGroup.needsAttention => context.loc.harnessesNeedsAttention,
  _HarnessGroup.enabled => context.loc.harnessManagementEnabled,
  _HarnessGroup.notInstalled => context.loc.harnessesNotInstalled,
  _HarnessGroup.disabled => context.loc.harnessesStatusDisabled,
};

bool _canInstall({required PluginManagementMetadata plugin}) =>
    plugin.managementCapabilities.contains(PluginManagementCapability.install) &&
    (plugin.setup.state == PluginSetupState.runtimeMissing || plugin.setup.state == PluginSetupState.unavailable);

bool _showOverviewStatus({required PluginManagementMetadata plugin, required PluginInstallState? install}) {
  if (_group(plugin: plugin, install: install) == _HarnessGroup.disabled) {
    // A disabled harness that isn't installed says so, explaining its
    // unavailable switch.
    return plugin.runtimeState == PluginRuntimeState.stopping || plugin.setup.state == PluginSetupState.runtimeMissing;
  }
  if (install != null || plugin.setup.state != PluginSetupState.ready) return true;
  return plugin.runtimeState != PluginRuntimeState.dormant &&
      (plugin.runtimeState != PluginRuntimeState.active || plugin.workState != PluginManagementWorkState.idle);
}

String _status({
  required BuildContext context,
  required PluginManagementMetadata plugin,
  required PluginInstallState? install,
}) {
  if (install is PluginInstallInProgress) return context.loc.harnessesInstallingStatus;
  if (plugin.setup.state == PluginSetupState.runtimeMissing) return context.loc.harnessesNotInstalled;
  if (plugin.setup.state != PluginSetupState.ready) return _setupStatus(context: context, state: plugin.setup.state);
  if (plugin.runtimeState == PluginRuntimeState.disabled) return context.loc.harnessesStatusDisabled;
  return switch (plugin.runtimeState) {
    PluginRuntimeState.active => switch (plugin.workState) {
      PluginManagementWorkState.busy => context.loc.harnessesStatusRunning,
      PluginManagementWorkState.idle => context.loc.harnessesStatusIdle,
      PluginManagementWorkState.unknown => context.loc.harnessesStatusUnknown,
    },
    PluginRuntimeState.disabled ||
    PluginRuntimeState.blocked ||
    PluginRuntimeState.dormant ||
    PluginRuntimeState.starting ||
    PluginRuntimeState.degraded ||
    PluginRuntimeState.stopping ||
    PluginRuntimeState.failed ||
    PluginRuntimeState.unknown => _runtimeStatus(context: context, state: plugin.runtimeState),
  };
}

/// Why a failed harness could not start, when its plugin gave a reason. Null
/// whenever the status line says something other than Failed.
String? _failureReason({required PluginManagementMetadata plugin, required PluginInstallState? install}) =>
    install == null && plugin.setup.state == PluginSetupState.ready && plugin.runtimeState == PluginRuntimeState.failed
    ? plugin.failureReason
    : null;

class const _HarnessStatus({
  required final PluginManagementMetadata plugin,
  required final PluginInstallState? install,
  required final bool overview,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final group = _group(plugin: plugin, install: install);
    final color = install is PluginInstallInProgress
        ? context.prego.colors.fgBrandPrimary
        : plugin.setup.state == PluginSetupState.runtimeMissing || install is PluginInstallFailed
        ? context.prego.colors.fgErrorPrimary
        : group == _HarnessGroup.enabled && plugin.workState == PluginManagementWorkState.busy
        ? context.prego.colors.fgSuccessPrimary
        : context.prego.colors.textTertiary;
    final status = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: PregoSpacing.md),
        Flexible(
          child: Text(
            overview && install is PluginInstallFailed
                ? context.loc.harnessesInstallationFailed
                : _status(context: context, plugin: plugin, install: install),
          ),
        ),
      ],
    );
    // The detail page gives the reason a row of its own.
    if (!overview) return status;
    // The reason fades in under Failed as a second line, and the row eases to
    // its new height so the harnesses below glide rather than jump. The whole
    // reason is on the detail page the row opens.
    final reason = _failureReason(plugin: plugin, install: install);
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        status,
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: reason == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(reason),
                  padding: const EdgeInsetsDirectional.only(start: 6 + PregoSpacing.md, top: PregoSpacing.xxs),
                  child: Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
        ),
      ],
    );
    if (context.isReducedMotion) return column;
    return AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: column,
    );
  }
}

class const _HarnessSwitch({
  required final PluginManagementMetadata plugin,
  required final PluginManagementActionState action,
  required final bool blocked,
  required final PluginInstallState? install,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (plugin.runtimeState == PluginRuntimeState.unknown ||
        !plugin.managementCapabilities.contains(PluginManagementCapability.lifecycle)) {
      return const SizedBox.shrink();
    }
    if (action
        case PluginManagementActionInProgress(
          target: PluginManagementActionTargetHarness(:final pluginId),
        )
        when pluginId == plugin.setup.id && install is! PluginInstallInProgress) {
      return Semantics(
        label: context.loc.harnessesUpdatingLabel(plugin.setup.displayName),
        liveRegion: true,
        child: SizedBox(
          key: Key("harness_management_enabled_target_${plugin.setup.id}"),
          width: 64,
          height: 44,
          child: Center(
            child: PregoActivityIndicator(
              key: Key("harness_management_enabled_progress_${plugin.setup.id}"),
              color: null,
            ),
          ),
        ),
      );
    }
    Future<void> setEnabled({required bool enabled}) => enabled
        ? context.read<PluginManagementCubit>().enable(pluginId: plugin.setup.id)
        : context.read<PluginManagementCubit>().disable(pluginId: plugin.setup.id);
    // A harness that isn't installed cannot run, so its switch reads off and
    // waits for the install. The stored setting stays untouched and shows
    // again once the runtime is installed.
    final installed = plugin.setup.state != PluginSetupState.runtimeMissing;
    final interactive = installed && !blocked;

    return Semantics(
      label: context.loc.harnessesEnabledLabel(plugin.setup.displayName),
      child: MouseRegion(
        cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          key: Key("harness_management_enabled_target_${plugin.setup.id}"),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: interactive ? () => unawaited(setEnabled(enabled: !plugin.runtimeState.isEnabled)) : null,
          child: SizedBox(
            height: 44,
            // Expand the hit target without stretching the 64×28 design-system track.
            child: Center(
              widthFactor: 1,
              child: PregoSwitch(
                key: Key("harness_management_enabled_${plugin.setup.id}"),
                value: installed && plugin.runtimeState.isEnabled,
                onChanged: interactive ? (value) => unawaited(setEnabled(enabled: value)) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _installPhase({required BuildContext context, required PluginInstallProgress progress}) => switch (progress) {
  PluginInstallProgress(phase: PluginInstallPhase.downloading, :final percent?) =>
    context.loc.harnessManagementInstallDownloadingPercent(percent),
  PluginInstallProgress(phase: PluginInstallPhase.downloading) => context.loc.harnessManagementInstallDownloading,
  PluginInstallProgress(phase: PluginInstallPhase.verifying) => context.loc.harnessManagementInstallVerifying,
  PluginInstallProgress(phase: PluginInstallPhase.extracting) => context.loc.harnessManagementInstallExtracting,
  PluginInstallProgress(phase: PluginInstallPhase.finalizing) => context.loc.harnessManagementInstallFinishing,
  PluginInstallProgress() => context.loc.harnessManagementInstallInProgress,
};

double? _downloadFraction({required PluginInstallProgress progress}) => switch (progress) {
  PluginInstallProgress(phase: PluginInstallPhase.downloading, :final percent?) => percent / 100,
  PluginInstallProgress() => null,
};
