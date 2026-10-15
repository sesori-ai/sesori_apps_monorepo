import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../extensions/build_context_x.dart";
import "../../l10n/app_localizations.dart";

/// A separate layer leaves the underlying inventory and details scroll intact.
Future<void> showMcpServerControls({required BuildContext context, required McpServerTarget target}) async {
  final inventory = context.read<McpCubit>();
  if (!inventory.mutationsAllowed) return;
  final actions = context.read<McpActionCubit>();
  final authentication = context.read<McpAuthenticationCubit>();
  await showPregoModal<void>(
    context: context,
    title: context.loc.mcpManageConnection,
    width: PregoModalWidth.browser,
    bodySize: PregoBottomSheetBodySize.seventyPercent,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: inventory),
        BlocProvider.value(value: actions),
        BlocProvider.value(value: authentication),
      ],
      child: McpServerControlsView(target: target),
    ),
  );
}

class const McpServerControlsView({required final McpServerTarget target, super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<McpCubit>();
    final state = inventory.state;
    final snapshot = switch (state) {
      McpInventoryReady(:final McpInventorySnapshot inventory) => inventory,
      McpInventoryReady() ||
      McpInventoryInitial() ||
      McpInventoryLoading() ||
      McpInventoryWaitingForConnection() ||
      McpInventoryNotFound() ||
      McpInventoryUnrecognized() ||
      McpInventoryReadFailed() ||
      McpInventoryFailed() => null,
    };
    final server = snapshot?.entries.whereType<McpServerSnapshot>().where((s) => s.serverTarget == target).firstOrNull;
    final actionState = context.watch<McpActionCubit>().state;
    final status = switch (actionState) {
      McpActionReceivedState(:final request) ||
      McpActionUncertain(:final request) when request.action.target != target => const McpActionIdle(),
      McpActionsReadOnly() ||
      McpActionIdle() ||
      McpActionOffline() ||
      McpActionPending() ||
      McpActionReceivedState() ||
      McpActionUncertain() => actionState,
    };
    final auth = context.watch<McpAuthenticationCubit>().state;
    final loc = context.loc;
    final offline = state is! McpInventoryReady || state.refresh is McpInventoryRefreshOffline;
    final blocked = !inventory.mutationsAllowed || offline || actionState is McpActionPending;
    final observation = auth.observation;
    final native = observation is McpAuthenticationObserved ? observation.state : null;
    final authBusy =
        auth.request is McpAuthenticationRequestPending ||
        native is McpAuthenticationStarting ||
        native is McpAuthenticationCallbackChallenge ||
        native is McpAuthenticationSettling ||
        switch (observation) {
          McpAuthenticationReadFailure(response: McpAuthenticationReceived(result: McpAuthenticationBusy())) ||
          McpAuthenticationObserved(refreshFailure: McpAuthenticationReceived(result: McpAuthenticationBusy())) => true,
          McpAuthenticationOffline() ||
          McpAuthenticationLoading() ||
          McpAuthenticationIdentityUnavailable() ||
          McpAuthenticationReadFailure() ||
          McpAuthenticationObserved() => false,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: MediaQuery.textScalerOf(context).scale(64),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _actionStatus(state: status, loc: loc),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
            children: [
              _AuthenticationStatus(target: target, pluginId: inventory.request.pluginId),
              if (server == null)
                Text(loc.mcpServerNotFound)
              else ...[
                Text(server.name, style: context.prego.textTheme.textLg.medium),
                const SizedBox(height: PregoSpacing.md),
                _CapabilityControl(
                  capability: server.authentication,
                  label: loc.mcpSignIn,
                  onPressed: blocked || authBusy
                      ? null
                      : () => context.read<McpAuthenticationCubit>().start(
                          request: McpAuthenticationStartRequest(pluginId: inventory.request.pluginId, target: target),
                        ),
                ),
                for (final capability in server.actions)
                  if (capability.action != McpServerAction.unknown &&
                      capability.effectScope != McpActionEffectScope.unknown)
                    _Control(
                      label: switch (capability.action) {
                        McpServerAction.reconnect => loc.mcpReconnect,
                        McpServerAction.enable => loc.mcpEnable,
                        McpServerAction.disable => loc.mcpDisable,
                        McpServerAction.unknown => loc.mcpUnknown,
                      },
                      effectScope: capability.effectScope,
                      onPressed: blocked
                          ? null
                          : () => context.read<McpActionCubit>().execute(
                              action: McpServerEntryAction(target: target, action: capability.action),
                            ),
                    ),
                _CapabilityControl(
                  capability: server.credentialForgetting,
                  label: loc.mcpForgetCredentials,
                  onPressed: blocked || authBusy
                      ? null
                      : () => _confirmForgetting(
                          context: context,
                          target: target,
                          capability: server.credentialForgetting,
                        ),
                ),
                if (offline) Text(loc.mcpOffline),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class const _LiveStatus({required final String message}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
        layoutBuilder: (current, previous) =>
            Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
        child: Text(message, key: ValueKey(message), maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ),
  );
}

class const _Control({
  required final String label,
  required final McpActionEffectScope effectScope,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PregoButtonsSolid(
          label: label,
          hierarchy: PregoButtonsSolidHierarchy.secondary,
          size: PregoButtonsSolidSize.md,
          fullWidth: true,
          onPressed: onPressed,
        ),
        const SizedBox(height: PregoSpacing.xs),
        Text(_effectScope(scope: effectScope, loc: context.loc)),
      ],
    ),
  );
}

class const _CapabilityControl({
  required final McpAuthenticationCapability capability,
  required final String label,
  required final VoidCallback? onPressed,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return switch (capability) {
      McpAuthenticationCapabilityAvailable(:final effectScope) when effectScope != McpActionEffectScope.unknown =>
        _Control(label: label, effectScope: effectScope, onPressed: onPressed),
      McpAuthenticationCapabilityAvailable() ||
      McpAuthenticationCapabilityUnknown() ||
      McpAuthenticationCapabilityUnavailable() => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label),
            Text(switch (capability) {
              McpAuthenticationCapabilityUnavailable(:final reason) => switch (reason) {
                McpAuthenticationCapabilityUnavailableReason.notSupported => loc.mcpActionNotSupported,
                McpAuthenticationCapabilityUnavailableReason.notImplemented => loc.mcpActionNotImplemented,
                McpAuthenticationCapabilityUnavailableReason.nativeConfigurationRequired =>
                  loc.mcpNativeConfigurationRequired,
                McpAuthenticationCapabilityUnavailableReason.unknown => loc.mcpCapabilityUnknown,
              },
              McpAuthenticationCapabilityAvailable() ||
              McpAuthenticationCapabilityUnknown() => loc.mcpCapabilityUnknown,
            }),
          ],
        ),
      ),
    };
  }
}

class const _AuthenticationStatus({required final McpServerTarget target, required final String pluginId})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<McpAuthenticationCubit>();
    final state = cubit.state;
    final loc = context.loc;
    final observation = state.observation;
    final native = observation is McpAuthenticationObserved ? observation.state : null;
    final attempt = native == null ? null : mcpAuthenticationAttempt(state: native);
    final matches = attempt?.pluginId == pluginId && attempt?.target == target;
    final active =
        native is McpAuthenticationStarting ||
        native is McpAuthenticationCallbackChallenge ||
        native is McpAuthenticationSettling;
    final pending = state.request is McpAuthenticationRequestPending;
    final challenge = matches && native is McpAuthenticationCallbackChallenge;
    final message = !matches && active
        ? loc.mcpAuthOtherServer
        : switch (observation) {
            McpAuthenticationOffline() => loc.mcpOffline,
            McpAuthenticationLoading() => loc.mcpLoading,
            McpAuthenticationIdentityUnavailable() => loc.mcpAuthIdentityUnavailable,
            McpAuthenticationReadFailure(:final response) => _authResponse(response: response, loc: loc),
            McpAuthenticationObserved(state: McpAuthenticationUnknown()) => loc.mcpUnknownResponse,
            McpAuthenticationObserved() when !matches => pending ? loc.mcpAuthStarting : loc.mcpAuthIdle,
            McpAuthenticationObserved(:final state) => switch (state) {
              McpAuthenticationUnknown() => loc.mcpUnknownResponse,
              McpAuthenticationIdle() => loc.mcpAuthIdle,
              McpAuthenticationStarting() => loc.mcpAuthStarting,
              McpAuthenticationCallbackChallenge() => switch (cubit.state.browser) {
                McpAuthenticationBrowserBlocked() => loc.mcpAuthBrowserBusy,
                McpAuthenticationBrowserFailed() => loc.mcpAuthBrowserFailed,
                McpAuthenticationBrowserOpening() => loc.mcpAuthBrowserOpening,
                McpAuthenticationBrowserWaiting() => loc.mcpAuthBrowserWaiting,
                McpAuthenticationBrowserIdle() => loc.mcpAuthChallengeReady,
              },
              McpAuthenticationSettling() => loc.mcpAuthSettling,
              McpAuthenticationCompleted() => loc.mcpAuthCompleted,
              McpAuthenticationCancelled() => loc.mcpAuthCancelled,
              McpAuthenticationFailed(:final reason) => switch (reason) {
                McpAuthenticationFailureReason.declined => loc.mcpAuthDeclined,
                McpAuthenticationFailureReason.expired => loc.mcpAuthExpired,
                McpAuthenticationFailureReason.nativeTrustRequired => loc.mcpNativeConfigurationRequired,
                McpAuthenticationFailureReason.unknown ||
                McpAuthenticationFailureReason.nativeFailure ||
                McpAuthenticationFailureReason.interrupted => loc.mcpAuthFailed,
              },
            },
          };
    final note = switch (state.request) {
      McpAuthenticationRequestUncertain() => loc.mcpAuthUncertain,
      McpAuthenticationRequestRejected(:final response) => _authResponse(response: response, loc: loc),
      McpAuthenticationRequestIdle() || McpAuthenticationRequestPending() => switch (observation) {
        McpAuthenticationObserved(:final refreshFailure?) => _authResponse(response: refreshFailure, loc: loc),
        McpAuthenticationOffline() ||
        McpAuthenticationLoading() ||
        McpAuthenticationIdentityUnavailable() ||
        McpAuthenticationReadFailure() ||
        McpAuthenticationObserved() => null,
      },
    };
    final requestState = state.request;
    final cancelling =
        requestState is McpAuthenticationRequestPending &&
        requestState.kind == McpAuthenticationRequestKind.cancellation;
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(196),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(48),
            child: _LiveStatus(message: message),
          ),
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(40),
            child: note != null && note != message ? _LiveStatus(message: note) : const SizedBox.shrink(),
          ),
          const SizedBox(height: PregoSpacing.sm),
          Wrap(
            spacing: PregoSpacing.sm,
            runSpacing: PregoSpacing.sm,
            children: [
              PregoButtonsSolid(
                label: loc.mcpOpenBrowser,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                onPressed:
                    !challenge ||
                        pending ||
                        state.browser is McpAuthenticationBrowserOpening ||
                        state.browser is McpAuthenticationBrowserWaiting
                    ? null
                    : cubit.openBrowser,
              ),
              PregoButtonsSolid(
                label: loc.mcpCancelSignIn,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                onPressed:
                    matches &&
                        active &&
                        attempt?.cancellation != McpAuthenticationCancellation.nativeSettlement &&
                        !cancelling
                    ? cubit.cancel
                    : null,
              ),
              PregoButtonsSolid(
                label: loc.mcpCheckSignIn,
                hierarchy: PregoButtonsSolidHierarchy.secondary,
                size: PregoButtonsSolidSize.sm,
                onPressed: state.observation is McpAuthenticationOffline ? null : cubit.refresh,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmForgetting({
  required BuildContext context,
  required McpServerTarget target,
  required McpAuthenticationCapability capability,
}) async {
  if (capability is! McpAuthenticationCapabilityAvailable) return;
  final actions = context.read<McpActionCubit>();
  final accepted = await showPregoModal<bool>(
    context: context,
    title: context.loc.mcpForgetCredentials,
    width: PregoModalWidth.regular,
    bodySize: PregoBottomSheetBodySize.natural,
    builder: (context) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.loc.mcpForgetMessage),
        const SizedBox(height: PregoSpacing.sm),
        Text(_effectScope(scope: capability.effectScope, loc: context.loc)),
        const SizedBox(height: PregoSpacing.lg),
        PregoSheetActions(
          secondary: PregoButtonsSolid(
            label: context.loc.mcpCancel,
            hierarchy: PregoButtonsSolidHierarchy.secondary,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => context.pop(false),
          ),
          primary: PregoButtonsSolid(
            label: context.loc.mcpForgetCredentials,
            hierarchy: PregoButtonsSolidHierarchy.primary,
            type: PregoButtonsSolidType.destructive,
            size: PregoButtonsSolidSize.lg,
            fullWidth: true,
            onPressed: () => context.pop(true),
          ),
        ),
      ],
    ),
  );
  if ((accepted ?? false) && !actions.isClosed) {
    await actions.execute(action: McpForgetAuthenticationEntryAction(target: target));
  }
}

String _effectScope({required McpActionEffectScope scope, required AppLocalizations loc}) => switch (scope) {
  McpActionEffectScope.harness => loc.mcpEffectHarness,
  McpActionEffectScope.project => loc.mcpEffectProject,
  McpActionEffectScope.session => loc.mcpEffectSession,
  McpActionEffectScope.unknown => loc.mcpCapabilityUnknown,
};

String _actionStatus({required McpActionClientState state, required AppLocalizations loc}) => switch (state) {
  McpActionsReadOnly() => loc.mcpReadOnly,
  McpActionIdle() => loc.mcpActionReady,
  McpActionOffline() => loc.mcpOffline,
  McpActionPending() => loc.mcpActionPending,
  McpActionUncertain() => loc.mcpActionUncertain,
  McpActionReceivedState(:final result) => switch (result) {
    McpActionCompleted() => loc.mcpActionCompleted,
    McpActionFailed() => loc.mcpActionFailed,
    McpActionUnknown() => loc.mcpUnknownResponse,
    McpActionUnavailable(:final reason) => switch (reason) {
      McpActionUnavailableReason.busy => loc.mcpAuthBusy,
      McpActionUnavailableReason.notSupported => loc.mcpActionNotSupported,
      McpActionUnavailableReason.notImplemented => loc.mcpActionNotImplemented,
      McpActionUnavailableReason.nativeConfigurationRequired => loc.mcpNativeConfigurationRequired,
      McpActionUnavailableReason.liveSessionRequired => loc.mcpLiveSessionRequired,
      McpActionUnavailableReason.pluginInactive => loc.mcpPluginInactive,
      McpActionUnavailableReason.targetNotFound => loc.mcpServerNotFound,
      McpActionUnavailableReason.unsupportedScope => loc.mcpUnsupportedScope,
      McpActionUnavailableReason.unsupportedHarness => loc.mcpUnsupportedHarness,
      McpActionUnavailableReason.unknown => loc.mcpUnknownResponse,
    },
  },
};

String _authResponse({required McpAuthenticationResponse response, required AppLocalizations loc}) =>
    switch (response) {
      McpAuthenticationRouteMissing() => loc.mcpAuthUpgradeBridge,
      McpAuthenticationRequestFailed() => loc.mcpAuthReadFailed,
      McpAuthenticationReceived(:final result) => switch (result) {
        McpAuthenticationBusy() => loc.mcpAuthBusy,
        McpAuthenticationResultUnknown() => loc.mcpUnknownResponse,
        McpAuthenticationStateResult() => loc.mcpAuthReadFailed,
        McpAuthenticationUnavailable(:final reason) => switch (reason) {
          McpAuthenticationUnavailableReason.nativeConfigurationRequired => loc.mcpNativeConfigurationRequired,
          McpAuthenticationUnavailableReason.notSupported => loc.mcpActionNotSupported,
          McpAuthenticationUnavailableReason.notImplemented => loc.mcpActionNotImplemented,
          McpAuthenticationUnavailableReason.pluginInactive => loc.mcpPluginInactive,
          McpAuthenticationUnavailableReason.liveSessionRequired => loc.mcpLiveSessionRequired,
          McpAuthenticationUnavailableReason.targetNotFound => loc.mcpServerNotFound,
          McpAuthenticationUnavailableReason.unsupportedScope => loc.mcpUnsupportedScope,
          McpAuthenticationUnavailableReason.unsupportedHarness => loc.mcpUnsupportedHarness,
          McpAuthenticationUnavailableReason.nativeCancellationUnavailable => loc.mcpAuthNativeSettlement,
          McpAuthenticationUnavailableReason.unknown ||
          McpAuthenticationUnavailableReason.attemptNotFound ||
          McpAuthenticationUnavailableReason.callbackRejected => loc.mcpAuthUnavailable,
        },
      },
    };
