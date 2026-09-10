import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/models/connection_status.dart";
import "../foundation/models/session_interaction_state.dart";
import "../repositories/models/plugin_management_result.dart";

/// Projects backend-neutral management evidence into the interaction policy for
/// one session. It deliberately owns no cache or lifecycle state.
@lazySingleton
class const SessionInteractionCalculator() {
  SessionInteractionState calculate({
    required String pluginId,
    required PluginManagementLoadResult? managementResult,
    required ConnectionStatus connectionStatus,
    required SessionInteractionState? previous,
  }) {
    if (connectionStatus is! ConnectionConnected) {
      return previous ?? const SessionInteractionState.checking();
    }

    return switch (managementResult) {
      // Reconnect clears the live snapshot, not the last known chat policy.
      // Keep the composer (or confirmed block) until management reports a result.
      null || PluginManagementLoadResultLoading() => previous ?? const SessionInteractionState.checking(),
      PluginManagementLoadResultUnsupported() => const SessionInteractionState.legacyUnverified(),
      PluginManagementLoadResultFailure(:final error) => SessionInteractionState.blocked(
        reason: SessionInteractionBlockedReason.statusCheckFailed,
        displayName: null,
        actionHint: null,
        refreshError: error,
      ),
      PluginManagementLoadResultSupported(:final response, :final refreshError) => _fromSupported(
        pluginId: pluginId,
        response: response,
        refreshError: refreshError,
      ),
    };
  }

  SessionInteractionState _fromSupported({
    required String pluginId,
    required PluginManagementResponse response,
    required ApiError? refreshError,
  }) {
    PluginManagementMetadata? metadata;
    for (final candidate in response.plugins) {
      if (candidate.setup.id == pluginId) {
        metadata = candidate;
        break;
      }
    }
    if (metadata == null) {
      return SessionInteractionState.blocked(
        reason: SessionInteractionBlockedReason.missingHarness,
        displayName: null,
        actionHint: null,
        refreshError: refreshError,
      );
    }

    final displayName = metadata.setup.displayName;
    final actionHint = metadata.actionHint ?? metadata.setup.actionHint;
    if (metadata.runtimeState == PluginRuntimeState.disabled) {
      return SessionInteractionState.blocked(
        reason: SessionInteractionBlockedReason.disabled,
        displayName: displayName,
        actionHint: actionHint,
        refreshError: refreshError,
      );
    }

    final setupReason = switch (metadata.setup.state) {
      PluginSetupState.ready => null,
      PluginSetupState.authenticationRequired => SessionInteractionBlockedReason.authenticationRequired,
      PluginSetupState.runtimeMissing => SessionInteractionBlockedReason.runtimeMissing,
      PluginSetupState.unavailable => SessionInteractionBlockedReason.unavailable,
      PluginSetupState.notInspected => SessionInteractionBlockedReason.notInspected,
      PluginSetupState.unknown => SessionInteractionBlockedReason.unknownStatus,
    };
    if (setupReason != null) {
      return SessionInteractionState.blocked(
        reason: setupReason,
        displayName: displayName,
        actionHint: actionHint,
        refreshError: refreshError,
      );
    }

    if (metadata.runtimeState.isRoutable) {
      return SessionInteractionState.available(refreshError: refreshError);
    }
    final runtimeReason = switch (metadata.runtimeState) {
      PluginRuntimeState.stopping => SessionInteractionBlockedReason.stopping,
      PluginRuntimeState.unknown => SessionInteractionBlockedReason.unknownStatus,
      PluginRuntimeState.disabled ||
      PluginRuntimeState.blocked ||
      PluginRuntimeState.failed ||
      PluginRuntimeState.dormant ||
      PluginRuntimeState.starting ||
      PluginRuntimeState.active ||
      PluginRuntimeState.degraded => SessionInteractionBlockedReason.unavailable,
    };
    return SessionInteractionState.blocked(
      reason: runtimeReason,
      displayName: displayName,
      actionHint: actionHint,
      refreshError: refreshError,
    );
  }
}
