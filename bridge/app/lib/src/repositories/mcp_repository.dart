import "dart:async";

import "package:rxdart/rxdart.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/database/daos/projects_dao.dart";
import "../api/database/daos/session_dao.dart";
import "../foundation/session_archived_read_only_exception.dart";
import "../runtime/plugin_runtime.dart";
import "mappers/mcp_mapper.dart";
import "models/mcp_authentication_update.dart";
import "models/mcp_control_result.dart";
import "models/mcp_operation.dart";
import "models/project_not_found_exception.dart";

/// Resolves bridge-owned scopes without activating a backend or agent session.
class McpRepository({
  required final PluginRuntime _runtime,
  required final SessionDao _sessionDao,
  required final ProjectsDao _projectsDao,
}) {
  Future<void> validateAuthenticationTarget({required McpAuthenticationAttempt attempt}) async {
    await _resolveScope(pluginId: attempt.pluginId, scope: attempt.target.scope, operation: McpOperation.authenticate);
  }

  /// Keeps the active runtime generation leased through native settlement.
  Stream<McpAuthenticationUpdate> authenticate({required McpAuthenticationStartRequest request}) async* {
    final scope = await _resolveScope(
      pluginId: request.pluginId,
      scope: request.target.scope,
      operation: McpOperation.authenticate,
    );
    yield* _runtime.useStreamIfActive(
      pluginId: request.pluginId,
      operation: McpOperation.authenticate,
      body: (plugin, _) => _authenticate(
        plugin: plugin,
        target: PluginMcpServerTarget(scope: scope, serverKey: request.target.serverKey),
      ),
    );
  }

  Stream<McpAuthenticationUpdate> _authenticate({
    required BridgePluginApi plugin,
    required PluginMcpServerTarget target,
  }) {
    late final StreamController<McpAuthenticationUpdate> controller;
    _PreparedMcpAuthentication? prepared;
    var cancelled = false;
    Future<void>? termination;
    McpAuthenticationDestinationException? invalidDestination;

    Future<void> finish({required bool cancelNative, required Object? error, required StackTrace? stackTrace}) {
      return termination ??= () async {
        // A synchronous native stream can finish before its subscription is added.
        await Future<void>.value();
        final native = prepared;
        ({Object error, StackTrace stackTrace})? cleanup;
        try {
          if (cancelNative && native != null) await native.cancel();
        } on Object catch (failure, failureStack) {
          cleanup = (error: failure, stackTrace: failureStack);
        }
        try {
          await native?.cancelSubscription();
        } on Object catch (failure, failureStack) {
          cleanup = (
            error: cleanup == null
                ? failure
                : McpAuthenticationCleanupException(
                    innerError: cleanup.error,
                    innerStackTrace: cleanup.stackTrace,
                    cleanupError: failure,
                    cleanupStackTrace: failureStack,
                  ),
            stackTrace: cleanup?.stackTrace ?? failureStack,
          );
        }
        if (cleanup case (error: final cleanupError, stackTrace: final cleanupStack)) {
          final failure = error == null
              ? cleanupError
              : McpAuthenticationCleanupException(
                  innerError: error,
                  innerStackTrace: stackTrace!,
                  cleanupError: cleanupError,
                  cleanupStackTrace: cleanupStack,
                );
          final failureStack = stackTrace ?? cleanupStack;
          if (cancelled) Error.throwWithStackTrace(failure, failureStack);
          controller.addError(failure, failureStack);
          unawaited(controller.close());
          return;
        }
        if (error != null && !cancelled) controller.addError(error, stackTrace);
        if (!cancelled) unawaited(controller.close());
      }();
    }

    Future<void> prepare() async {
      try {
        if (plugin is! McpAuthenticationPluginApi) {
          throw const McpAuthenticationUnavailableException(
            reason: McpAuthenticationUnavailableReason.unsupportedHarness,
          );
        }
        final operation = await (plugin as McpAuthenticationPluginApi).beginMcpAuthentication(target: target);
        final native = _PreparedMcpAuthentication(operation: operation);
        if (cancelled) {
          // Preparation is read-only. A discarded operation is never subscribed.
          await native.cancel();
          return;
        }
        prepared = native;
        void activate() {
          if (cancelled) return;
          try {
            operation.events
                .listen(
                  (event) {
                    if (event case PluginMcpAuthenticationChallenge(:final authorizationUri)) {
                      if (authorizationUri.scheme != "https" ||
                          authorizationUri.host.isEmpty ||
                          authorizationUri.userInfo.isNotEmpty) {
                        invalidDestination = const McpAuthenticationDestinationException();
                        if (operation is PluginMcpCancelableAuthentication) {
                          unawaited(
                            finish(cancelNative: true, error: invalidDestination, stackTrace: StackTrace.current),
                          );
                        }
                        return;
                      }
                    }
                    if (invalidDestination == null && termination == null) {
                      controller.add(McpAuthenticationNativeEvent(event: event));
                    }
                  },
                  onError: (Object error, StackTrace stackTrace) =>
                      unawaited(finish(cancelNative: true, error: error, stackTrace: stackTrace)),
                  onDone: () => unawaited(
                    finish(
                      cancelNative: false,
                      error: invalidDestination,
                      stackTrace: invalidDestination == null ? null : StackTrace.current,
                    ),
                  ),
                )
                .addTo(native.subscriptions);
          } on Object catch (error, stackTrace) {
            unawaited(finish(cancelNative: true, error: error, stackTrace: stackTrace));
          }
        }

        controller.add(McpAuthenticationStarted(operation: native.ownedOperation, activate: activate));
      } on Object catch (error, stackTrace) {
        if (cancelled) {
          Log.w(
            "MCP authentication preparation/cleanup failed after cancellation for ${plugin.id} on $target",
            error,
            stackTrace,
          );
        } else {
          await finish(cancelNative: true, error: error, stackTrace: stackTrace);
        }
      }
    }

    controller = StreamController<McpAuthenticationUpdate>(
      onListen: () => unawaited(prepare()),
      onCancel: () {
        cancelled = true;
        // Do not wait for a read-only native status request that cannot be aborted.
        return prepared == null ? Future<void>.value() : finish(cancelNative: true, error: null, stackTrace: null);
      },
    );
    return controller.stream;
  }

  Future<McpInventoryResult> getInventory({required String pluginId, required McpScope scope}) async {
    final nativeScope = await _resolveScope(pluginId: pluginId, scope: scope, operation: McpOperation.getInventory);
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.getInventory,
      body: (plugin, _) async {
        if (plugin is! McpManagementPluginApi) {
          return McpInventoryUnavailable(
            scope: scope,
            reason: McpInventoryUnavailableReason.unsupportedHarness,
            message: "This integration does not yet expose MCP inventory.",
          );
        }
        final native = await (plugin as McpManagementPluginApi).getMcpInventory(scope: nativeScope);
        if (native case PluginMcpInventoryReadFailed(:final cause, :final causeStackTrace)) {
          Log.w("MCP inventory read failed for $pluginId in $scope", cause, causeStackTrace);
        }
        return const McpMapper().map(scope: scope, result: native);
      },
    );
    return result ??
        McpInventoryUnavailable(
          scope: scope,
          reason: McpInventoryUnavailableReason.pluginInactive,
          message: "Start the integration before reading MCP inventory.",
        );
  }

  Future<McpControlResult> executeServerAction({
    required String pluginId,
    required McpServerTarget target,
    required McpServerAction action,
  }) async {
    final nativeScope = await _resolveScope(
      pluginId: pluginId,
      scope: target.scope,
      operation: McpOperation.executeAction,
    );
    final nativeAction = switch (action) {
      McpServerAction.reconnect => PluginMcpServerAction.reconnect,
      McpServerAction.enable => PluginMcpServerAction.enable,
      McpServerAction.disable => PluginMcpServerAction.disable,
      McpServerAction.unknown => throw PluginOperationException(
        McpOperation.executeAction.name,
        message: "Unsupported MCP action.",
        statusCode: 400,
      ),
    };
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.executeAction,
      body: (plugin, _) async {
        if (plugin is! McpManagementPluginApi) {
          return const McpControlUnavailable(reason: McpActionUnavailableReason.unsupportedHarness);
        }
        final native = await (plugin as McpManagementPluginApi).executeMcpServerAction(
          target: PluginMcpServerTarget(scope: nativeScope, serverKey: target.serverKey),
          action: nativeAction,
        );
        return switch (native) {
          PluginMcpActionCompleted(:final effectScope) => McpControlCompleted(
            effectScope: switch (effectScope) {
              PluginMcpActionEffectScope.harness => McpActionEffectScope.harness,
              PluginMcpActionEffectScope.project => McpActionEffectScope.project,
              PluginMcpActionEffectScope.session => McpActionEffectScope.session,
            },
          ),
          PluginMcpActionUnavailable(:final reason) => McpControlUnavailable(
            reason: switch (reason) {
              PluginMcpActionUnavailableReason.unsupportedScope => McpActionUnavailableReason.unsupportedScope,
              PluginMcpActionUnavailableReason.liveSessionRequired => McpActionUnavailableReason.liveSessionRequired,
              PluginMcpActionUnavailableReason.targetNotFound => McpActionUnavailableReason.targetNotFound,
            },
          ),
          PluginMcpActionFailed(:final cause, :final causeStackTrace) => _actionFailed(
            pluginId: pluginId,
            target: target,
            cause: cause,
            stackTrace: causeStackTrace,
          ),
        };
      },
    );
    return result ?? const McpControlUnavailable(reason: McpActionUnavailableReason.pluginInactive);
  }

  Future<McpControlResult> forgetAuthentication({required String pluginId, required McpServerTarget target}) async {
    final nativeScope = await _resolveScope(
      pluginId: pluginId,
      scope: target.scope,
      operation: McpOperation.executeAction,
    );
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.executeAction,
      body: (plugin, _) async {
        if (plugin is! McpAuthenticationPluginApi) {
          return const McpControlUnavailable(reason: McpActionUnavailableReason.unsupportedHarness);
        }
        try {
          final effectScope = await (plugin as McpAuthenticationPluginApi).forgetMcpAuthentication(
            target: PluginMcpServerTarget(scope: nativeScope, serverKey: target.serverKey),
          );
          return McpControlCompleted(
            effectScope: switch (effectScope) {
              PluginMcpActionEffectScope.harness => McpActionEffectScope.harness,
              PluginMcpActionEffectScope.project => McpActionEffectScope.project,
              PluginMcpActionEffectScope.session => McpActionEffectScope.session,
            },
          );
        } on PluginMcpAuthenticationUnavailableException catch (error) {
          return McpControlUnavailable(
            reason: switch (error.reason) {
              PluginMcpAuthenticationUnavailableReason.unsupportedScope => McpActionUnavailableReason.unsupportedScope,
              PluginMcpAuthenticationUnavailableReason.liveSessionRequired =>
                McpActionUnavailableReason.liveSessionRequired,
              PluginMcpAuthenticationUnavailableReason.targetNotFound => McpActionUnavailableReason.targetNotFound,
              PluginMcpAuthenticationUnavailableReason.nativeConfigurationRequired =>
                McpActionUnavailableReason.nativeConfigurationRequired,
              PluginMcpAuthenticationUnavailableReason.notSupported => McpActionUnavailableReason.notSupported,
              PluginMcpAuthenticationUnavailableReason.notImplemented => McpActionUnavailableReason.notImplemented,
            },
          );
        } on Exception catch (error, stackTrace) {
          return _actionFailed(pluginId: pluginId, target: target, cause: error, stackTrace: stackTrace);
        }
      },
    );
    return result ?? const McpControlUnavailable(reason: McpActionUnavailableReason.pluginInactive);
  }

  Future<McpControlResult> resolveConnectorSetup({
    required String pluginId,
    required McpConnectorOfferTarget target,
  }) async {
    final scope = await _resolveScope(pluginId: pluginId, scope: target.scope, operation: McpOperation.executeAction);
    final result = await _runtime.useIfActive(
      pluginId: pluginId,
      operation: McpOperation.executeAction,
      body: (plugin, _) async {
        if (plugin is! McpConnectorSetupPluginApi) {
          return const McpControlUnavailable(reason: McpActionUnavailableReason.unsupportedHarness);
        }
        final native = await (plugin as McpConnectorSetupPluginApi).resolveMcpConnectorSetup(
          target: PluginMcpConnectorOfferTarget(scope: scope, offerKey: target.offerKey),
        );
        return switch (native) {
          PluginMcpConnectorExternalSetup(:final destination) => McpControlExternalSetup(destination: destination),
          PluginMcpConnectorSetupUnavailable(:final reason) => McpControlUnavailable(
            reason: switch (reason) {
              PluginMcpConnectorSetupUnavailableReason.unsupportedScope => McpActionUnavailableReason.unsupportedScope,
              PluginMcpConnectorSetupUnavailableReason.liveSessionRequired =>
                McpActionUnavailableReason.liveSessionRequired,
              PluginMcpConnectorSetupUnavailableReason.targetNotFound => McpActionUnavailableReason.targetNotFound,
              PluginMcpConnectorSetupUnavailableReason.nativeConfigurationRequired =>
                McpActionUnavailableReason.nativeConfigurationRequired,
              PluginMcpConnectorSetupUnavailableReason.notSupported => McpActionUnavailableReason.notSupported,
            },
          ),
          PluginMcpConnectorSetupFailed(:final cause, :final causeStackTrace) => _actionFailed(
            pluginId: pluginId,
            target: target,
            cause: cause,
            stackTrace: causeStackTrace,
          ),
        };
      },
    );
    return result ?? const McpControlUnavailable(reason: McpActionUnavailableReason.pluginInactive);
  }

  McpControlFailed _actionFailed({
    required String pluginId,
    required McpEntryTarget target,
    required Exception cause,
    required StackTrace stackTrace,
  }) {
    Log.w("MCP action failed for $pluginId on $target", cause, stackTrace);
    return const McpControlFailed();
  }

  Future<PluginMcpScope> _resolveScope({
    required String pluginId,
    required McpScope scope,
    required McpOperation operation,
  }) async {
    switch (scope) {
      case McpHarnessScope():
        return const PluginMcpHarnessScope();
      case McpProjectScope(:final projectId):
        final project = await _projectsDao.getProject(projectId: projectId);
        if (project == null) throw ProjectNotFoundException(projectId: projectId);
        return PluginMcpProjectScope(projectId: project.path);
      case McpSessionScope(:final sessionId):
        final session = await _sessionDao.getSession(sessionId: sessionId);
        if (session == null) {
          throw PluginOperationException.notFound(
            operation.name,
            message: "Session not found: $sessionId",
          );
        }
        if (session.pluginId != pluginId) {
          throw PluginOperationException(
            operation.name,
            message: "The session does not belong to the selected integration.",
            statusCode: 400,
          );
        }
        if (operation != McpOperation.getInventory && session.archivedAt != null) {
          throw SessionArchivedReadOnlyException(
            rejection: SessionArchivedRejection(sessionId: sessionId, reason: SessionArchivedReason.archivedReadOnly),
          );
        }
        return PluginMcpSessionScope(sessionId: session.backendSessionId);
    }
  }
}

/// Owns the one native cancellation attempt across explicit cancel and teardown.
class _PreparedMcpAuthentication({required final PluginMcpAuthenticationOperation operation}) {
  final CompositeSubscription subscriptions = CompositeSubscription();
  Future<void>? _cancellation;

  PluginMcpAuthenticationOperation get ownedOperation => switch (operation) {
    PluginMcpCancelableAuthentication(:final effectScope, :final events, :final submitCallback) =>
      PluginMcpCancelableAuthentication(
        effectScope: effectScope,
        events: events,
        submitCallback: submitCallback,
        cancel: cancel,
      ),
    PluginMcpNativeSettlementAuthentication() => operation,
  };

  Future<void> cancelSubscription() => subscriptions.cancel();

  Future<void> cancel() => _cancellation ??= Future<void>.sync(
    () => switch (operation) {
      PluginMcpCancelableAuthentication(:final cancel) => cancel(),
      PluginMcpNativeSettlementAuthentication() => Future<void>.value(),
    },
  );
}
