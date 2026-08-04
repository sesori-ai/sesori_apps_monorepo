import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
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

    return BlocListener<PluginManagementCubit, PluginManagementState>(
      listenWhen: (previous, current) => _forceConfirmation(previous) != _forceConfirmation(current),
      listener: (context, state) {
        final confirmation = _forceConfirmation(state);
        if (confirmation == null) return;
        unawaited(_showForceConfirmation(context: context, cubit: cubit, confirmation: confirmation));
      },
      child: PregoGlassScaffold(
        title: loc.settingsHarnessesTitle,
        titleMode: PregoTopNavigationTitleMode.inline,
        banner: ConnectionBanner.maybeFor(context),
        actions: [
          PregoButtonsIconGlass(
            icon: TablerRegular.x,
            semanticLabel: loc.settingsClose,
            // This page is raised as a modal from more than one place, so
            // closing it means going back to whatever raised it. Only a
            // deep link arrives with nothing underneath, and that falls back
            // to the app's home.
            onPressed: () =>
                context.canPop() ? context.pop() : context.goRoute(const AppRoute.projects()),
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

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state});

  final PluginManagementReady state;

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
  const _HarnessControlCard({required this.plugin, required this.isDefault, required this.action});

  final PluginManagementMetadata plugin;
  final bool isDefault;
  final PluginManagementActionState action;

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
    final showRestart = showOperational && supportsLifecycle;
    final showTimeout = showOperational && supportsIdleTimeout;
    final showClearTimeout = showTimeout && plugin.hasIdleTimeoutOverride;
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

class _FactRow extends StatelessWidget {
  const _FactRow({required this.title, required this.value, required this.isLast});

  final String title;
  final String value;
  final bool isLast;

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

enum _TimeoutChoice { useDefault, noTimeout, custom }

sealed class _TimeoutResult {
  const _TimeoutResult();
}

final class _UseDefaultTimeoutResult extends _TimeoutResult {
  const _UseDefaultTimeoutResult();
}

final class _ApplyTimeoutResult extends _TimeoutResult {
  const _ApplyTimeoutResult({required this.input});

  final PluginManagementIdleTimeoutInput input;
}

class _TimeoutSheet extends StatefulWidget {
  const _TimeoutSheet({
    required this.allowUseDefault,
    required this.initialChoice,
    required this.initialMinutes,
  });

  final bool allowUseDefault;
  final _TimeoutChoice initialChoice;
  final int initialMinutes;

  @override
  State<_TimeoutSheet> createState() => _TimeoutSheetState();
}

class _TimeoutSheetState extends State<_TimeoutSheet> {
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
