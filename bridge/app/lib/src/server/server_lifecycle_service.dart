import 'dart:async';
import 'dart:io';

import '../server/process.dart';
import 'server_health_config.dart';

class ServerLifecycleService {
  final ServerHealthConfig _config;
  Process? _process;
  final StreamController<int> _exitController = StreamController<int>.broadcast();
  bool _stopped = false;

  ServerLifecycleService({
    required ServerHealthConfig config,
    required Process? initialProcess,
  }) : _config = config,
       _process = initialProcess {
    if (initialProcess != null) {
      initialProcess.exitCode.then(_exitController.add);
    }
  }

  bool get isManaged => _config.isManaged;

  Stream<int> get processExitEvents => _exitController.stream;

  Future<void> restart() async {
    if (!_config.isManaged) return;
    await stop();
    _stopped = false;
    final port = Uri.parse(_config.serverURL).port;
    _process = await startServer(_config.binaryPath, port, _config.password);
    unawaited(_process!.exitCode.then(_exitController.add));
    await waitReady(_config.serverURL, _config.password);
  }

  Future<void> stop() async {
    if (_stopped) return;
    _stopped = true;
    await stopServer(_process);
    _process = null;
  }
}
