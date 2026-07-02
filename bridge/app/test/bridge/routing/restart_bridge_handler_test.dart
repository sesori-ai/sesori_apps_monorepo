import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/bridge/routing/restart_bridge_handler.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/bridge_restart_command_builder.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge/src/server/services/bridge_restart_service.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show ServerClock;
import 'package:test/test.dart';

import 'routing_test_helpers.dart';

class _NoopProcessRunner implements ProcessRunner {
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

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('restart-bridge-handler');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  BridgeRestartService buildService({required String binaryPath}) {
    return BridgeRestartService(
      processRepository: ProcessRepository(
        api: SystemProcessApi(
          processRunner: _NoopProcessRunner(),
          clock: const ServerClock(),
          isWindows: false,
          platform: 'linux',
        ),
        currentUser: null,
      ),
      commandBuilder: const BridgeRestartCommandBuilder(),
      binaryPath: binaryPath,
      cliArgs: const ['run'],
      currentPid: 1234,
      isSupervised: false,
    );
  }

  test('canHandle POST /global/restart only', () {
    final handler = RestartBridgeHandler(restartService: buildService(binaryPath: '/x'));

    expect(handler.canHandle(makeRequest('POST', '/global/restart')), isTrue);
    expect(handler.canHandle(makeRequest('GET', '/global/restart')), isFalse);
    expect(handler.canHandle(makeRequest('POST', '/global/health')), isFalse);
  });

  test('replies {restarting:true} and flags the restart when spawnable', () async {
    final binaryPath = p.join(tempDir.path, 'sesori-bridge');
    File(binaryPath).writeAsStringSync('binary');
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', binaryPath]);
    }
    final service = buildService(binaryPath: binaryPath);
    final handler = RestartBridgeHandler(restartService: service);

    final response = await handler.handleInternal(
      makeRequest('POST', '/global/restart'),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );

    expect(response.status, 200);
    expect(response.body, contains('"restarting":true'));
    expect(service.consumeRestartRequest(), isTrue);
  });

  test('returns 503 without flagging a restart when the binary is unavailable', () async {
    final service = buildService(binaryPath: p.join(tempDir.path, 'missing'));
    final handler = RestartBridgeHandler(restartService: service);

    final response = await handler.handleInternal(
      makeRequest('POST', '/global/restart'),
      pathParams: const {},
      queryParams: const {},
      fragment: null,
    );

    expect(response.status, 503);
    expect(response.body, contains('sesori.com'));
    expect(service.consumeRestartRequest(), isFalse);
  });
}
