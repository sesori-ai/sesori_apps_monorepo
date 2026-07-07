import 'dart:io';

import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_restart_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show ServerClock;

/// A [ProcessRunner] that fails fast if used — restart is never actually
/// triggered in these tests, so the runner must stay untouched.
class NoopProcessRunner implements ProcessRunner {
  @override
  Future<ProcessResult> run(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }
}

/// Builds an inert [BridgeRestartService] for wiring tests that construct an
/// `Orchestrator`/`BridgeRuntime` but never exercise the restart path.
BridgeRestartService buildTestRestartService() {
  return BridgeRestartService(
    processRepository: ProcessRepository(
      api: SystemProcessApi(
        processRunner: NoopProcessRunner(),
        clock: const ServerClock(),
        isWindows: false,
        platform: 'linux',
      ),
      currentUser: null,
    ),
    commandBuilder: const BridgeRestartCommandBuilder(),
    binaryPath: '/tmp/sesori-bridge',
    cliArgs: const <String>[],
    currentPid: 0,
    isSupervised: false,
  );
}
