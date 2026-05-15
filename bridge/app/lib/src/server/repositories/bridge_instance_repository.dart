import 'package:path/path.dart' as path;

import '../api/system_process_api.dart';
import '../foundation/bridge_instance_candidate.dart';

class BridgeInstanceRepository {
  BridgeInstanceRepository({
    required SystemProcessApi api,
    required String? currentUser,
  }) : _api = api,
       _currentUser = currentUser;

  final SystemProcessApi _api;
  final String? _currentUser;

  Future<List<BridgeInstanceCandidate>> listLiveBridgeCandidates({required int currentPid}) async {
    final facts = await _api.listProcesses();
    final candidates = <BridgeInstanceCandidate>[];
    for (final fact in facts) {
      if (fact.pid == currentPid || !_isLiveBridgeFact(fact: fact)) {
        continue;
      }
      candidates.add(
        BridgeInstanceCandidate(
          pid: fact.pid,
          startMarker: fact.startMarker,
          executablePath: fact.executablePath,
          commandLine: fact.commandLine,
          ownerUser: fact.ownerUser,
          platform: fact.platform,
          capturedAt: fact.capturedAt,
        ),
      );
    }
    return candidates;
  }

  bool _isLiveBridgeFact({required SystemProcessFact fact}) {
    if (_currentUser != null && fact.ownerUser != null && fact.ownerUser != _currentUser) {
      return false;
    }

    final executableBasename = fact.executablePath == null ? null : path.basename(fact.executablePath!).toLowerCase();
    final commandLine = fact.commandLine.toLowerCase();

    if (executableBasename == 'sesori-bridge' || executableBasename == 'sesori-bridge.exe') {
      return true;
    }

    if (!commandLine.contains('bridge/app/bin/bridge.dart')) {
      return false;
    }

    return executableBasename == 'dart' || executableBasename == 'dart.exe' || executableBasename == 'bridge.dart';
  }
}
