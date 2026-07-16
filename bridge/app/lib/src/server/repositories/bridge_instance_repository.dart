import 'package:path/path.dart' as path;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

import '../api/process_id_lookup_api.dart';
import '../api/system_process_api.dart';

class BridgeInstanceRepository {
  BridgeInstanceRepository({
    required ProcessIdLookupApi processIdLookupApi,
    required SystemProcessApi processApi,
    required ProcessUser? currentUser,
  }) : _processIdLookupApi = processIdLookupApi,
       _processApi = processApi,
       _currentUser = currentUser;

  static const String _bridgeExecutableName = 'sesori-bridge';
  static const Set<String> _bridgeExecutableBasenames = <String>{'sesori-bridge', 'sesori-bridge.exe'};

  final ProcessIdLookupApi _processIdLookupApi;
  final SystemProcessApi _processApi;
  final ProcessUser? _currentUser;

  Future<List<ProcessIdentity>> listLiveBridgeCandidates({required int currentPid}) async {
    final processIds = await _processIdLookupApi.listProcessIdsByExecutableName(
      executableName: _bridgeExecutableName,
    );
    final candidates = <ProcessIdentity>[];
    for (final processId in processIds) {
      if (processId == currentPid) {
        continue;
      }

      final candidate = await _processApi.inspectProcess(pid: processId);
      if (candidate != null && _isLiveBridge(process: candidate)) {
        candidates.add(candidate);
      }
    }
    return candidates;
  }

  bool _isLiveBridge({required ProcessIdentity process}) {
    if (_currentUser != null && process.ownerUser != null && process.ownerUser != _currentUser) {
      return false;
    }

    final executableBasename = process.executablePath == null
        ? null
        : path.basename(process.executablePath!).toLowerCase();
    return executableBasename != null && _bridgeExecutableBasenames.contains(executableBasename);
  }
}
