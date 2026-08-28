import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_restart_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show ServerClock;

import 'fake_process_runner.dart';

export 'fake_process_runner.dart' show NoopProcessRunner;

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
    onSupervisedRestartRequested: () {},
  );
}
