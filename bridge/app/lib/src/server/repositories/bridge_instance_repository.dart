import 'package:path/path.dart' as path;

import '../api/system_process_api.dart';
import '../foundation/process_identity.dart';

class BridgeInstanceRepository {
  BridgeInstanceRepository({
    required SystemProcessApi api,
    required String? currentUser,
  }) : _api = api,
       _currentUser = currentUser;

  final SystemProcessApi _api;
  final String? _currentUser;

  Future<List<ProcessIdentity>> listLiveBridgeCandidates({required int currentPid}) async =>
      (await _api.listProcesses()) //
          .where((p) => p.pid != currentPid && _isLiveBridge(process: p))
          .toList();

  bool _isLiveBridge({required ProcessIdentity process}) {
    if (_currentUser != null && process.ownerUser != null && process.ownerUser != _currentUser) {
      return false;
    }

    final executableBasename = process.executablePath == null
        ? null
        : path.basename(process.executablePath!).toLowerCase();
    final commandLine = process.commandLine.toLowerCase();

    if (executableBasename == 'sesori-bridge' || executableBasename == 'sesori-bridge.exe') {
      return true;
    }

    // test for bridge started as dart (dev mode)
    if (!commandLine.contains('bridge/app/bin/bridge.dart')) {
      return false;
    }

    return executableBasename == 'dart' || executableBasename == 'dart.exe' || executableBasename == 'bridge.dart';
  }
}
