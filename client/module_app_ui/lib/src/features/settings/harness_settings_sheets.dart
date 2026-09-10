part of "harness_settings_flow_view.dart";

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
    context: _flowPresentationContext(context: context),
    title: title,
    builder: (_) => _TimeoutSheet(
      allowUseDefault: allowUseDefault,
      initialChoice: initialChoice,
      initialMinutes: initialMinutes,
    ),
  );
}

enum _TimeoutChoice() {
  useDefault,
  noTimeout,
  custom,
}

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
          PregoSheetActions(
            secondary: PregoButtonsSolid(
              key: const Key("harness_management_timeout_cancel"),
              label: loc.harnessManagementCancel,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: () => context.pop(),
            ),
            primary: PregoButtonsSolid(
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
    );
  }
}

Future<void> _showForceConfirmation({
  required BuildContext context,
  required PluginManagementCubit cubit,
  required PluginManagementActionForceConfirmationRequired confirmation,
}) async {
  final owner = _flowPresentationContext(context: context);
  final current = cubit.state;
  if (!(ModalRoute.of(owner)?.isCurrent ?? false) ||
      current is! PluginManagementReady ||
      !identical(current.harnessActions[confirmation.pluginId], confirmation)) {
    return;
  }
  final confirmed = await showPregoBottomSheet<bool>(
    context: _flowPresentationContext(context: context),
    title: confirmation.action == PluginManagementForceAction.disable
        ? context.loc.harnessManagementForceDisableTitle(confirmation.conflict.current.setup.displayName)
        : context.loc.harnessesForceRestartTitle(confirmation.conflict.current.setup.displayName),
    isDismissible: false,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            confirmation.action == PluginManagementForceAction.restart
                ? context.loc.harnessesForceRestartDescription(confirmation.conflict.current.setup.displayName)
                : context.loc.harnessManagementForceDescription,
            style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
          ),
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: const Key("harness_management_force_confirm"),
            label: confirmation.action == PluginManagementForceAction.restart
                ? context.loc.harnessesForceRestartAction
                : context.loc.harnessManagementForceAction,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            size: PregoButtonsSolidSize.lg,
            type: PregoButtonsSolidType.destructive,
            fullWidth: true,
            onPressed: () => sheetContext.pop(true),
          ),
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            key: const Key("harness_management_force_cancel"),
            label: context.loc.harnessManagementCancel,
            hierarchy: PregoButtonsSolidHierarchy.tertiary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => sheetContext.pop(false),
          ),
        ],
      ),
    ),
  );
  if (confirmed ?? false) {
    await cubit.confirmForce(confirmation: confirmation);
  } else {
    cubit.dismissForceConfirmation(confirmation: confirmation);
  }
}

Future<void> _showAuthenticationSheet({
  required BuildContext context,
  required PluginManagementCubit cubit,
}) async {
  await showPregoBottomSheet<void>(
    context: _flowPresentationContext(context: context),
    title: context.loc.harnessAuthenticationSheetTitle,
    builder: (_) => BlocProvider<PluginManagementCubit>.value(
      value: cubit,
      child: const _AuthenticationSheet(),
    ),
  );
  // Dismissing presentation is not cancellation. Retain the cubit's challenge
  // until terminal progress settles the upstream operation so peer harnesses
  // remain gated and the owning row can reopen this same sheet.
}

class const _AuthenticationSheet() extends StatefulWidget {
  @override
  State<_AuthenticationSheet> createState() => _AuthenticationSheetState();
}

class _AuthenticationSheetState() extends State<_AuthenticationSheet> {
  Future<void> _copyCode({required BuildContext context, required String code}) async {
    if (!await copyTextToClipboard(text: code, operation: "authentication code") || !context.mounted) return;
    PregoPopupAlertPresenter.of(context).show(
      title: context.loc.harnessAuthenticationCodeCopied,
      variant: PregoPopupAlertsNotificationsVariant.success,
    );
  }

  void _close() {
    context.read<PluginManagementCubit>().dismissAuthentication();
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
    final presentation = _authenticationChallenge(state: context.watch<PluginManagementCubit>().state);
    if (presentation == null) return const Center(child: PregoActivityIndicator(color: null));

    switch (presentation) {
      case PluginAuthenticationPresentationStarting():
        return _messageContent(
          context: context,
          description: loc.harnessAuthenticationPreparingDescription,
          message: loc.harnessAuthenticationPreparing,
          loading: true,
          action: null,
        );
      case PluginAuthenticationPresentationSucceeded():
        return _messageContent(
          context: context,
          description: loc.harnessAuthenticationSucceeded,
          message: null,
          loading: false,
          action: (key: const Key("harness_authentication_done"), label: loc.harnessAuthenticationDone),
        );
      case PluginAuthenticationPresentationCancelled():
        return _messageContent(
          context: context,
          description: loc.harnessAuthenticationCancelled,
          message: null,
          loading: false,
          action: (key: const Key("harness_authentication_close"), label: loc.harnessAuthenticationClose),
        );
      case PluginAuthenticationPresentationFailed(:final pluginId, :final error):
        return _failureContent(
          context: context,
          pluginId: pluginId,
          message: _authenticationErrorDescription(context: context, error: error),
        );
      case PluginAuthenticationPresentationIdle():
        return const Center(child: PregoActivityIndicator(color: null));
      case PluginAuthenticationPresentationChallenge() ||
          PluginAuthenticationPresentationBrowserOpening() ||
          PluginAuthenticationPresentationBrowserWaiting() ||
          PluginAuthenticationPresentationBrowserFinalizing() ||
          PluginAuthenticationPresentationBrowserLaunchFailedState() ||
          PluginAuthenticationPresentationCancelling() ||
          PluginAuthenticationPresentationCancellingUncertain():
        return _activeContent(context: context, presentation: presentation);
    }
  }

  Widget _activeContent({required BuildContext context, required PluginAuthenticationPresentationState presentation}) {
    final loc = context.loc;
    final challenge = switch (presentation) {
      PluginAuthenticationPresentationChallenge(:final challenge) => challenge.challenge,
      PluginAuthenticationPresentationBrowserOpening(:final challenge) ||
      PluginAuthenticationPresentationBrowserWaiting(:final challenge) ||
      PluginAuthenticationPresentationBrowserFinalizing(:final challenge) => challenge,
      PluginAuthenticationPresentationBrowserLaunchFailedState(:final challenge) ||
      PluginAuthenticationPresentationCancelling(:final challenge) ||
      PluginAuthenticationPresentationCancellingUncertain(:final challenge) => challenge,
      PluginAuthenticationPresentationIdle() ||
      PluginAuthenticationPresentationStarting() ||
      PluginAuthenticationPresentationSucceeded() ||
      PluginAuthenticationPresentationCancelled() ||
      PluginAuthenticationPresentationFailed() => throw StateError("Expected active authentication"),
    };
    final status = switch (presentation) {
      PluginAuthenticationPresentationBrowserOpening() => loc.harnessAuthenticationOpening,
      PluginAuthenticationPresentationBrowserWaiting() => loc.harnessAuthenticationWaitingForBrowser,
      PluginAuthenticationPresentationBrowserFinalizing() => loc.harnessAuthenticationFinalizing,
      PluginAuthenticationPresentationBrowserLaunchFailedState() => loc.harnessAuthenticationBrowserFailed,
      PluginAuthenticationPresentationCancellingUncertain() => loc.harnessAuthenticationCancellingUncertain,
      PluginAuthenticationPresentationCancelling() => loc.harnessAuthenticationCancelling,
      PluginAuthenticationPresentationChallenge() => loc.harnessAuthenticationWaiting,
      PluginAuthenticationPresentationIdle() ||
      PluginAuthenticationPresentationStarting() ||
      PluginAuthenticationPresentationSucceeded() ||
      PluginAuthenticationPresentationCancelled() ||
      PluginAuthenticationPresentationFailed() => throw StateError("Expected active authentication"),
    };
    final deviceCode = challenge is PluginAuthenticationDeviceCodeChallenge;
    final retry = presentation is PluginAuthenticationPresentationBrowserLaunchFailedState;
    final ongoingBrowser =
        presentation is PluginAuthenticationPresentationBrowserOpening ||
        presentation is PluginAuthenticationPresentationBrowserWaiting ||
        presentation is PluginAuthenticationPresentationBrowserFinalizing;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: deviceCode
                ? loc.harnessAuthenticationSecuritySemantics
                : loc.harnessAuthenticationBrowserInstructions,
            child: Text(
              deviceCode ? loc.harnessAuthenticationSecurityDescription : loc.harnessAuthenticationBrowserInstructions,
              style: context.prego.textTheme.textSm.regular.copyWith(color: context.prego.colors.textSecondary),
            ),
          ),
          if (challenge case PluginAuthenticationDeviceCodeChallenge(:final userCode)) ...[
            const SizedBox(height: PregoSpacing.xl),
            PregoGroupedRows(
              children: [
                PregoGroupedRow(
                  key: const Key("harness_authentication_code"),
                  icon: TablerRegular.key,
                  title: Text(loc.harnessAuthenticationCodeLabel),
                  subtitle: SelectableText(userCode),
                  trailing: IconButton(
                    key: const Key("harness_authentication_copy"),
                    tooltip: loc.harnessAuthenticationCopyCode,
                    onPressed: () => _copyCode(context: context, code: userCode),
                    icon: const Icon(TablerRegular.copy),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: PregoSpacing.xl),
          if (ongoingBrowser) ...[
            const RepaintBoundary(
              key: Key("harness_authentication_activity"),
              child: Center(child: PregoActivityIndicator(color: null)),
            ),
            const SizedBox(height: PregoSpacing.md),
          ],
          Text(
            status,
            textAlign: TextAlign.center,
            style: context.prego.textTheme.textSm.regular.copyWith(
              color: retry ? context.prego.colors.textErrorPrimary : context.prego.colors.textSecondary,
            ),
          ),
          if (deviceCode || retry) ...[
            const SizedBox(height: PregoSpacing.x2l),
            PregoButtonsSolid(
              key: const Key("harness_authentication_open_browser"),
              label: retry ? loc.harnessAuthenticationRetry : loc.harnessAuthenticationOpenBrowser,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed:
                  presentation is PluginAuthenticationPresentationCancelling ||
                      presentation is PluginAuthenticationPresentationCancellingUncertain
                  ? null
                  : context.read<PluginManagementCubit>().launchAuthenticationBrowser,
            ),
          ],
          const SizedBox(height: PregoSpacing.md),
          PregoButtonsSolid(
            key: const Key("harness_authentication_cancel"),
            label: presentation is PluginAuthenticationPresentationCancelling
                ? loc.harnessAuthenticationCancelling
                : loc.harnessAuthenticationCancel,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            type: PregoButtonsSolidType.destructive,
            fullWidth: true,
            isLoading: presentation is PluginAuthenticationPresentationCancelling,
            onPressed: presentation is PluginAuthenticationPresentationCancelling
                ? null
                : context.read<PluginManagementCubit>().cancelAuthentication,
          ),
        ],
      ),
    );
  }

  Widget _messageContent({
    required BuildContext context,
    required String description,
    required String? message,
    required bool loading,
    required ({Key key, String label})? action,
  }) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(description, textAlign: TextAlign.center),
        if (loading) ...[
          const SizedBox(height: PregoSpacing.xl),
          const Center(child: PregoActivityIndicator(color: null)),
        ],
        if (message != null) ...[
          const SizedBox(height: PregoSpacing.md),
          Text(message, textAlign: TextAlign.center),
        ],
        if (action != null) ...[
          const SizedBox(height: PregoSpacing.x2l),
          PregoButtonsSolid(
            key: action.key,
            label: action.label,
            hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: _close,
          ),
        ],
      ],
    ),
  );

  Widget _failureContent({required BuildContext context, required String? pluginId, required String message}) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.prego.textTheme.textSm.medium.copyWith(color: context.prego.colors.textErrorPrimary),
            ),
            if (pluginId != null) ...[
              const SizedBox(height: PregoSpacing.x2l),
              PregoButtonsSolid(
                key: const Key("harness_authentication_retry"),
                label: context.loc.harnessAuthenticationRetry,
                hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
                size: PregoButtonsSolidSize.lg,
                fullWidth: true,
                onPressed: () => context.read<PluginManagementCubit>().startAuthentication(pluginId: pluginId),
              ),
            ],
            const SizedBox(height: PregoSpacing.md),
            PregoButtonsSolid(
              key: const Key("harness_authentication_close"),
              label: context.loc.harnessAuthenticationClose,
              hierarchy: PregoButtonsSolidHierarchy.secondary,
              size: PregoButtonsSolidSize.lg,
              fullWidth: true,
              onPressed: _close,
            ),
          ],
        ),
      );
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
