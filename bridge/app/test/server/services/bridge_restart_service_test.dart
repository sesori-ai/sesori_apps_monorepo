import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/bridge/foundation/legacy_post_update_relaunch.dart';
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart';
import 'package:sesori_bridge/src/server/foundation/bridge_restart_env.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_restart_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show ServerClock;
import 'package:test/test.dart';

class _RecordingProcessRunner implements ProcessRunner {
  final List<({String executable, List<String> arguments, Map<String, String>? environment})> detachedCalls = [];
  bool throwOnSpawn = false;

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
    if (throwOnSpawn) {
      throw const ProcessException('sesori-bridge', <String>[], 'spawn failed');
    }
    detachedCalls.add((executable: executable, arguments: arguments, environment: environment));
    return 4242;
  }
}

void main() {
  late Directory tempDir;
  late _RecordingProcessRunner runner;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('bridge-restart-service');
    runner = _RecordingProcessRunner();
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  BridgeRestartService buildService({required String binaryPath, List<String> cliArgs = const ['run']}) {
    return BridgeRestartService(
      processRepository: ProcessRepository(
        api: SystemProcessApi(
          processRunner: runner,
          clock: const ServerClock(),
          isWindows: false,
          platform: 'linux',
        ),
        currentUser: null,
      ),
      commandBuilder: const BridgeRestartCommandBuilder(),
      binaryPath: binaryPath,
      cliArgs: cliArgs,
      currentPid: 7777,
    );
  }

  test('requestRestart is consumed exactly once', () {
    final service = buildService(binaryPath: '/x');

    expect(service.consumeRestartRequest(), isFalse);
    service.requestRestart();
    expect(service.consumeRestartRequest(), isTrue);
    expect(service.consumeRestartRequest(), isFalse);
  });

  test('canSpawnSuccessor reflects whether the binary exists and is executable', () async {
    final existing = p.join(tempDir.path, 'sesori-bridge');
    File(existing).writeAsStringSync('binary');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', existing]);
    }

    expect(await buildService(binaryPath: existing).canSpawnSuccessor(), isTrue);
    expect(await buildService(binaryPath: p.join(tempDir.path, 'missing')).canSpawnSuccessor(), isFalse);
  });

  test('canSpawnSuccessor is false for a present but non-executable binary (POSIX)', () async {
    if (Platform.isWindows) {
      return; // the execute-bit preflight is POSIX-only
    }
    final notExecutable = p.join(tempDir.path, 'sesori-bridge');
    File(notExecutable).writeAsStringSync('binary'); // 0644, no execute bit

    expect(await buildService(binaryPath: notExecutable).canSpawnSuccessor(), isFalse);
  });

  test('spawnSuccessor starts the binary with cli args and the predecessor pid', () async {
    final service = buildService(binaryPath: '/opt/sesori/sesori-bridge', cliArgs: ['run', '--relay', 'wss://r']);

    final spawned = await service.spawnSuccessor();

    expect(spawned, isTrue);
    expect(runner.detachedCalls, hasLength(1));
    final call = runner.detachedCalls.single;
    expect(call.executable, '/opt/sesori/sesori-bridge');
    expect(call.arguments, ['run', '--relay', 'wss://r']);
    expect(call.environment, containsPair(sesoriRestartPredecessorPidEnvVar, '7777'));
    // The legacy post-update relaunch flag must be cleared so a non-interactive
    // mode set by a legacy updater does not propagate to restart successors.
    expect(call.environment, containsPair(sesoriPostUpdateRestartEnvVar, ''));
  });

  test('spawnSuccessor returns false when the process cannot be started', () async {
    runner.throwOnSpawn = true;
    final service = buildService(binaryPath: '/opt/sesori/sesori-bridge');

    expect(await service.spawnSuccessor(), isFalse);
  });
}
