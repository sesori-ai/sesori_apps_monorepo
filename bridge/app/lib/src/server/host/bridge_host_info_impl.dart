import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgeHostInfo, ProcessIdentity;

import "../foundation/process_match.dart";
import "../repositories/process_repository.dart";

class BridgeHostInfoImpl implements BridgeHostInfo {
  BridgeHostInfoImpl({
    required this.identity,
    required this.ownerSessionId,
    required this.terminatedBridgeIdentities,
    required ProcessRepository processRepository,
  }) : _processRepository = processRepository;

  @override
  final ProcessIdentity identity;

  @override
  final String ownerSessionId;

  @override
  final List<ProcessIdentity> terminatedBridgeIdentities;

  final ProcessRepository _processRepository;

  /// Mirrors the stale-kill authorization predicate
  /// (`OpenCodeServerService._isStaleKillAuthorized`): classification plus
  /// marker matching, deliberately without a same-user check — returning
  /// `true` spares the pid's runtimes, and sparing another user's live bridge
  /// is the conservative direction.
  @override
  Future<bool> isLiveBridgeProcess({required int pid, required String? startMarker}) async {
    final match = await _processRepository.inspectProcessMatch(pid: pid);
    if (match == null || match.kind != ProcessMatchKind.sesoriBridge) {
      return false;
    }

    if (startMarker != null || match.identity.startMarker != null) {
      return match.identity.startMarker == startMarker;
    }

    // Both markers are null (e.g. Windows). The decision rests on the
    // bridge-process classification alone.
    return true;
  }
}
