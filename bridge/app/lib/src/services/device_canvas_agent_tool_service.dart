import "package:sesori_shared/sesori_shared.dart"
    show maxDeviceCanvasClientDeviceKeyLength, maxDeviceCanvasClientIdentifierLength;

import "../auth/bridge_id_provider.dart";
import "../bridge/device_canvas/integration_state.dart";
import "../bridge/device_canvas/protocol.dart";
import "../repositories/device_canvas_claim_repository.dart";
import "../repositories/models/stored_session.dart";
import "../repositories/session_repository.dart";
import "device_canvas_claim_service.dart";

enum DeviceCanvasAgentDeviceOwnership() { unclaimed, currentSession, anotherSession }

class const DeviceCanvasAgentDevice({
  required final String deviceKey,
  required final DeviceCanvasPlatform platform,
  required final String displayName,
  required final String runtimeDescription,
  required final String modelDescription,
  required final DeviceCanvasAgentDeviceOwnership ownership,
});

sealed class const DeviceCanvasAgentToolResult();

final class const DeviceCanvasAgentSimulatorsListed({
  required final List<DeviceCanvasAgentDevice> devices,
  required final bool truncated,
}) extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorClaimed({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorAlreadyOwned({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorReleased({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorAlreadyReleased({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorConflict({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSimulatorUnavailable({required final String deviceKey})
    extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentSessionUnavailable() extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentIntegrationUnavailable() extends DeviceCanvasAgentToolResult;

final class const DeviceCanvasAgentBridgeUnavailable() extends DeviceCanvasAgentToolResult;

class DeviceCanvasAgentToolService({
  required final BridgeIdProvider _bridgeIdProvider,
  required final DeviceCanvasClaimService _claimService,
  required final DeviceCanvasIntegrationState _integrationState,
  required final SessionRepository _sessionRepository,
}) {
  static const int _maxDevices = 128;
  static const int _maxPluginIdLength = 128;
  static const int _maxDisplayLength = 256;
  static const int _maxDescriptionLength = 512;

  Future<DeviceCanvasAgentToolResult> listSimulators({
    required String pluginId,
    required String backendSessionId,
  }) async {
    final resolution = await _resolveInvocation(pluginId: pluginId, backendSessionId: backendSessionId);
    if (resolution case final _InvocationUnavailable unavailable) return unavailable.result;
    final invocation = resolution as _InvocationAvailable;
    if (!_integrationState.isConnected) return const DeviceCanvasAgentIntegrationUnavailable();

    final inventory = _integrationState.presenceSnapshot.devicesByKey;
    final claims = await _claimService.clientSnapshot(
      bridgeId: invocation.bridgeId,
      sessionId: invocation.session.id,
      liveDeviceKeys: inventory.keys.toSet(),
      priorityDeviceKey: null,
      limit: _maxDevices,
    );
    if (!await _bridgeIdIsUnchanged(invocation.bridgeId)) return const DeviceCanvasAgentBridgeUnavailable();

    final claimsByDeviceKey = <String, DeviceCanvasClaimProjection>{
      for (final claim in claims.projections) claim.deviceKey: claim,
    };
    final deviceKeys = inventory.keys.toList(growable: false)..sort();
    return DeviceCanvasAgentSimulatorsListed(
      devices: [
        for (final deviceKey in deviceKeys.take(_maxDevices))
          _mapDevice(
            descriptor: inventory[deviceKey]!,
            claim: claimsByDeviceKey[deviceKey],
            sessionId: invocation.session.id,
          ),
      ],
      truncated: claims.truncated || deviceKeys.length > _maxDevices,
    );
  }

  Future<DeviceCanvasAgentToolResult> claimSimulator({
    required String pluginId,
    required String backendSessionId,
    required String deviceKey,
  }) async {
    if (!_isValidDeviceKey(deviceKey)) return DeviceCanvasAgentSimulatorUnavailable(deviceKey: deviceKey);
    final resolution = await _resolveInvocation(pluginId: pluginId, backendSessionId: backendSessionId);
    if (resolution case final _InvocationUnavailable unavailable) return unavailable.result;
    final invocation = resolution as _InvocationAvailable;
    if (!_integrationState.isConnected) return const DeviceCanvasAgentIntegrationUnavailable();

    final attempt = await _claimService.claim(
      bridgeId: invocation.bridgeId,
      deviceKey: deviceKey,
      sessionId: invocation.session.id,
    );
    if (!await _bridgeIdIsUnchanged(invocation.bridgeId)) return const DeviceCanvasAgentBridgeUnavailable();
    return switch (attempt) {
      DeviceCanvasClaimed() || DeviceCanvasClaimReassigned() => DeviceCanvasAgentSimulatorClaimed(
        deviceKey: deviceKey,
      ),
      DeviceCanvasClaimAlreadyOwned() => DeviceCanvasAgentSimulatorAlreadyOwned(deviceKey: deviceKey),
      DeviceCanvasClaimConflict() => DeviceCanvasAgentSimulatorConflict(deviceKey: deviceKey),
      DeviceCanvasClaimDeviceUnavailable() => DeviceCanvasAgentSimulatorUnavailable(deviceKey: deviceKey),
      DeviceCanvasClaimSessionUnavailable() => const DeviceCanvasAgentSessionUnavailable(),
    };
  }

  Future<DeviceCanvasAgentToolResult> releaseSimulator({
    required String pluginId,
    required String backendSessionId,
    required String deviceKey,
  }) async {
    if (!_isValidDeviceKey(deviceKey)) return DeviceCanvasAgentSimulatorUnavailable(deviceKey: deviceKey);
    final resolution = await _resolveInvocation(pluginId: pluginId, backendSessionId: backendSessionId);
    if (resolution case final _InvocationUnavailable unavailable) return unavailable.result;
    final invocation = resolution as _InvocationAvailable;
    if (!_integrationState.isConnected) return const DeviceCanvasAgentIntegrationUnavailable();

    final attempt = await _claimService.release(
      bridgeId: invocation.bridgeId,
      deviceKey: deviceKey,
      sessionId: invocation.session.id,
    );
    if (!await _bridgeIdIsUnchanged(invocation.bridgeId)) return const DeviceCanvasAgentBridgeUnavailable();
    return switch (attempt) {
      DeviceCanvasReleased() => DeviceCanvasAgentSimulatorReleased(deviceKey: deviceKey),
      DeviceCanvasAlreadyReleased() => DeviceCanvasAgentSimulatorAlreadyReleased(deviceKey: deviceKey),
      DeviceCanvasReleaseConflict() => DeviceCanvasAgentSimulatorConflict(deviceKey: deviceKey),
    };
  }

  Future<_InvocationResolution> _resolveInvocation({
    required String pluginId,
    required String backendSessionId,
  }) async {
    if (pluginId.isEmpty ||
        pluginId.length > _maxPluginIdLength ||
        backendSessionId.isEmpty ||
        backendSessionId.length > maxDeviceCanvasClientIdentifierLength) {
      return const _InvocationUnavailable(result: DeviceCanvasAgentSessionUnavailable());
    }
    final session = await _sessionRepository.getStoredSessionByBackendId(
      pluginId: pluginId,
      backendSessionId: backendSessionId,
    );
    if (session == null || session.archivedAt != null || await _sessionRepository.isSessionTombstoned(sessionId: session.id)) {
      return const _InvocationUnavailable(result: DeviceCanvasAgentSessionUnavailable());
    }
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null || bridgeId.isEmpty || bridgeId.length > maxDeviceCanvasClientIdentifierLength) {
      return const _InvocationUnavailable(result: DeviceCanvasAgentBridgeUnavailable());
    }
    return _InvocationAvailable(bridgeId: bridgeId, session: session);
  }

  Future<bool> _bridgeIdIsUnchanged(String expectedBridgeId) async {
    if (_bridgeIdProvider.bridgeId == expectedBridgeId) return true;
    await _claimService.cleanupBridgeIdentity(bridgeId: expectedBridgeId);
    return false;
  }

  bool _isValidDeviceKey(String deviceKey) =>
      deviceKey.isNotEmpty && deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength;

  DeviceCanvasAgentDevice _mapDevice({
    required DeviceCanvasDescriptor descriptor,
    required DeviceCanvasClaimProjection? claim,
    required String sessionId,
  }) {
    return DeviceCanvasAgentDevice(
      deviceKey: descriptor.deviceKey,
      platform: descriptor.platform,
      displayName: _truncate(descriptor.displayName, _maxDisplayLength),
      runtimeDescription: _truncate(descriptor.runtimeDescription, _maxDescriptionLength),
      modelDescription: _truncate(descriptor.modelDescription, _maxDescriptionLength),
      ownership: switch (claim) {
        null => DeviceCanvasAgentDeviceOwnership.unclaimed,
        final claim when claim.sessionId == sessionId => DeviceCanvasAgentDeviceOwnership.currentSession,
        _ => DeviceCanvasAgentDeviceOwnership.anotherSession,
      },
    );
  }

  String _truncate(String value, int limit) {
    final runes = value.runes;
    return runes.length <= limit ? value : String.fromCharCodes(runes.take(limit));
  }
}

sealed class const _InvocationResolution();

final class const _InvocationAvailable({required final String bridgeId, required final StoredSession session})
    extends _InvocationResolution;

final class const _InvocationUnavailable({required final DeviceCanvasAgentToolResult result})
    extends _InvocationResolution;
