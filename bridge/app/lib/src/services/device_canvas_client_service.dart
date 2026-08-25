import "package:sesori_shared/sesori_shared.dart";

import "../auth/bridge_id_provider.dart";
import "../bridge/device_canvas/integration_state.dart";
import "../bridge/device_canvas/protocol.dart" as ipc;
import "../repositories/device_canvas_claim_repository.dart";
import "../repositories/session_repository.dart";
import "device_canvas_claim_service.dart";

class const DeviceCanvasClientBridgeUnavailable() implements Exception;

class DeviceCanvasClientService({
  required final BridgeIdProvider _bridgeIdProvider,
  required final DeviceCanvasClaimService _claimService,
  required final DeviceCanvasIntegrationState _integrationState,
  required final SessionRepository _sessionRepository,
}) {
  static const int _maxDevices = 128;
  static const int _maxDisplayLength = 256;
  static const int _maxDescriptionLength = 512;

  Future<DeviceCanvasSessionStatusResponse> status({required String sessionId}) {
    final bridgeId = _requireBridgeId();
    return _buildCurrentStatus(bridgeId: bridgeId, sessionId: sessionId, priorityDeviceKey: null);
  }

  Future<DeviceCanvasMutationResponse> claim({required DeviceCanvasClaimRequest request}) async {
    final bridgeId = _requireBridgeId();
    if (request.expectedBridgeId != bridgeId) throw const DeviceCanvasClientBridgeUnavailable();
    final attempt = request.reassign
        ? await _claimService.reassign(
            bridgeId: bridgeId,
            deviceKey: request.deviceKey,
            sessionId: request.sessionId,
            expectedOwnerSessionId: request.expectedOwnerSessionId!,
            expectedClaimRevision: request.expectedClaimRevision!,
          )
        : await _claimService.claim(
            bridgeId: bridgeId,
            deviceKey: request.deviceKey,
            sessionId: request.sessionId,
          );
    await _requireUnchangedBridgeId(bridgeId);
    return DeviceCanvasMutationResponse(
      outcome: switch (attempt) {
        DeviceCanvasClaimed() => DeviceCanvasMutationOutcome.claimed,
        DeviceCanvasClaimAlreadyOwned() => DeviceCanvasMutationOutcome.alreadyOwned,
        DeviceCanvasClaimReassigned() => DeviceCanvasMutationOutcome.reassigned,
        DeviceCanvasClaimConflict() => DeviceCanvasMutationOutcome.conflict,
        DeviceCanvasClaimDeviceUnavailable() => DeviceCanvasMutationOutcome.deviceUnavailable,
        DeviceCanvasClaimSessionUnavailable() => DeviceCanvasMutationOutcome.sessionUnavailable,
      },
      status: await _buildCurrentStatus(
        bridgeId: bridgeId,
        sessionId: request.sessionId,
        priorityDeviceKey: request.deviceKey,
      ),
    );
  }

  Future<DeviceCanvasMutationResponse> release({required DeviceCanvasReleaseRequest request}) async {
    final bridgeId = _requireBridgeId();
    if (request.expectedBridgeId != bridgeId) throw const DeviceCanvasClientBridgeUnavailable();
    final attempt = await _claimService.release(
      bridgeId: bridgeId,
      deviceKey: request.deviceKey,
      sessionId: request.sessionId,
      expectedClaimRevision: request.expectedClaimRevision,
    );
    await _requireUnchangedBridgeId(bridgeId);
    return DeviceCanvasMutationResponse(
      outcome: switch (attempt) {
        DeviceCanvasReleased() => DeviceCanvasMutationOutcome.released,
        DeviceCanvasAlreadyReleased() => DeviceCanvasMutationOutcome.alreadyReleased,
        DeviceCanvasReleaseConflict() => DeviceCanvasMutationOutcome.conflict,
      },
      status: await _buildCurrentStatus(
        bridgeId: bridgeId,
        sessionId: request.sessionId,
        priorityDeviceKey: request.deviceKey,
      ),
    );
  }

  Future<DeviceCanvasSessionStatusResponse> _buildCurrentStatus({
    required String bridgeId,
    required String sessionId,
    required String? priorityDeviceKey,
  }) async {
    final status = await _buildStatus(
      bridgeId: bridgeId,
      sessionId: sessionId,
      priorityDeviceKey: priorityDeviceKey,
    );
    await _requireUnchangedBridgeId(bridgeId);
    return status;
  }

  Future<DeviceCanvasSessionStatusResponse> _buildStatus({
    required String bridgeId,
    required String sessionId,
    required String? priorityDeviceKey,
  }) async {
    final storedSession = await _sessionRepository.getStoredSession(sessionId: sessionId);
    final projectId = storedSession?.projectId;
    final sessionAvailable =
        storedSession != null &&
        storedSession.archivedAt == null &&
        projectId != null &&
        projectId.isNotEmpty &&
        projectId.length <= maxDeviceCanvasClientIdentifierLength;
    final inventory = _integrationState.presenceSnapshot.devicesByKey;
    final projectionPage = await _claimService.clientSnapshot(
      bridgeId: bridgeId,
      sessionId: sessionId,
      liveDeviceKeys: inventory.keys.toSet(),
      priorityDeviceKey: priorityDeviceKey,
      limit: _maxDevices,
    );
    var truncated = projectionPage.truncated;
    final claimsByKey = <String, DeviceCanvasClaimProjection>{};
    for (final claim in projectionPage.projections) {
      if (!_isBoundedClaim(claim)) {
        truncated = true;
        continue;
      }
      claimsByKey[claim.deviceKey] = claim;
    }
    final keys = {...inventory.keys, ...claimsByKey.keys}.toList(growable: false)
      ..sort((a, b) {
        final priority =
            _devicePriority(
              deviceKey: a,
              priorityDeviceKey: priorityDeviceKey,
              sessionId: sessionId,
              inventory: inventory,
              claimsByKey: claimsByKey,
            ).compareTo(
              _devicePriority(
                deviceKey: b,
                priorityDeviceKey: priorityDeviceKey,
                sessionId: sessionId,
                inventory: inventory,
                claimsByKey: claimsByKey,
              ),
            );
        return priority != 0 ? priority : a.compareTo(b);
      });
    if (keys.length > _maxDevices) truncated = true;

    return DeviceCanvasSessionStatusResponse(
      bridgeId: bridgeId,
      sessionId: sessionId,
      sessionAvailable: sessionAvailable,
      projectId: sessionAvailable ? projectId : null,
      connection: _integrationState.isConnected
          ? DeviceCanvasClientConnectionStatus.connected
          : DeviceCanvasClientConnectionStatus.disconnected,
      devices: [
        for (final deviceKey in keys.take(_maxDevices))
          DeviceCanvasDeviceStatus(
            deviceKey: deviceKey,
            descriptor: switch (inventory[deviceKey]) {
              final descriptor? => _mapDescriptor(descriptor),
              null => null,
            },
            claim: switch (claimsByKey[deviceKey]) {
              final claim? => DeviceCanvasClaimStatus(
                projectId: claim.projectId,
                sessionId: claim.sessionId,
                revision: claim.claimRevision,
                claimedAt: claim.claimedAt,
                displayTitle: _truncate(claim.displayTitle, _maxDisplayLength),
              ),
              null => null,
            },
          ),
      ],
      inventoryTruncated: truncated,
      supportsReassignment: true,
    );
  }

  int _devicePriority({
    required String deviceKey,
    required String? priorityDeviceKey,
    required String sessionId,
    required Map<String, ipc.DeviceCanvasDescriptor> inventory,
    required Map<String, DeviceCanvasClaimProjection> claimsByKey,
  }) {
    if (deviceKey == priorityDeviceKey) return -1;
    if (claimsByKey[deviceKey]?.sessionId == sessionId) return 0;
    if (inventory.containsKey(deviceKey)) return 1;
    return 2;
  }

  bool _isBoundedClaim(DeviceCanvasClaimProjection claim) =>
      claim.deviceKey.isNotEmpty &&
      claim.deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength &&
      claim.projectId.isNotEmpty &&
      claim.projectId.length <= maxDeviceCanvasClientIdentifierLength &&
      claim.sessionId.isNotEmpty &&
      claim.sessionId.length <= maxDeviceCanvasClientIdentifierLength;

  DeviceCanvasClientDescriptor _mapDescriptor(ipc.DeviceCanvasDescriptor descriptor) {
    return DeviceCanvasClientDescriptor(
      platform: switch (descriptor.platform) {
        ipc.DeviceCanvasPlatform.ios => DeviceCanvasClientPlatform.ios,
        ipc.DeviceCanvasPlatform.android => DeviceCanvasClientPlatform.android,
      },
      displayName: _truncate(descriptor.displayName, _maxDisplayLength) ?? "",
      runtimeDescription: _truncate(descriptor.runtimeDescription, _maxDescriptionLength) ?? "",
      modelDescription: _truncate(descriptor.modelDescription, _maxDescriptionLength) ?? "",
      dimensions: switch (descriptor.dimensions) {
        final dimensions? => DeviceCanvasClientDimensions(width: dimensions.width, height: dimensions.height),
        null => null,
      },
      orientation: switch (descriptor.orientation) {
        ipc.DeviceCanvasOrientation.portrait => DeviceCanvasClientOrientation.portrait,
        ipc.DeviceCanvasOrientation.landscape => DeviceCanvasClientOrientation.landscape,
        null => null,
      },
      capabilities: DeviceCanvasClientCapabilities(
        localView: descriptor.capabilities.localView,
        remoteVideo: descriptor.capabilities.remoteVideo,
        remoteControl: descriptor.capabilities.remoteControl,
        input: descriptor.capabilities.input,
      ),
    );
  }

  String _requireBridgeId() {
    final bridgeId = _bridgeIdProvider.bridgeId;
    if (bridgeId == null || bridgeId.isEmpty) throw const DeviceCanvasClientBridgeUnavailable();
    return bridgeId;
  }

  Future<void> _requireUnchangedBridgeId(String expectedBridgeId) async {
    if (_bridgeIdProvider.bridgeId == expectedBridgeId) return;
    await _claimService.cleanupBridgeIdentity(bridgeId: expectedBridgeId);
    throw const DeviceCanvasClientBridgeUnavailable();
  }

  String? _truncate(String? value, int maxRunes) {
    if (value == null) return null;
    final runes = value.runes;
    return runes.length <= maxRunes ? value : String.fromCharCodes(runes.take(maxRunes));
  }
}
