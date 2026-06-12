import 'package:path/path.dart' as path;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';

import '../api/system_process_api.dart';

class BridgeInstanceRepository {
  BridgeInstanceRepository({
    required SystemProcessApi api,
    required ProcessUser? currentUser,
  }) : _api = api,
       _currentUser = currentUser;

  static const Set<String> _dartExecutableNames = <String>{
    'dart',
    'dart.exe',
    'dartvm',
    'dartvm.exe',
    'dartaotruntime',
    'dartaotruntime.exe',
    'bridge.dart',
  };

  final SystemProcessApi _api;
  final ProcessUser? _currentUser;

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

    return executableBasename != null && _dartExecutableNames.contains(executableBasename);
  }
}
