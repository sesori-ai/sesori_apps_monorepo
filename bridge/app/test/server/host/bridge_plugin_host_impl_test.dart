import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sesori_bridge/src/server/api/loopback_port_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/host/bridge_plugin_host_impl.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgePluginHostImpl.create', () {
    late Directory tempDir;

    final bridgeIdentity = ProcessIdentity(
      pid: 100,
      startMarker: 'bridge-start-marker',
      executablePath: '/usr/local/bin/sesori-bridge',
      commandLine: '/usr/local/bin/sesori-bridge',
      ownerUser: ProcessUser.fromRawUser('alex'),
      platform: 'macos',
      capturedAt: DateTime.utc(2026, 5, 15, 12),
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('bridge-plugin-host-impl-test-');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    Future<BridgePluginHostImpl> createHost({required String stateDirectory}) {
      return BridgePluginHostImpl.create(
        config: const PluginConfig(values: {'port': '4096'}),
        stateDirectory: stateDirectory,
        environment: const {'HOME': '/home/alex'},
        clock: const ServerClock(),
        startAborted: StartAbortSignal.never,
        bridgeIdentity: bridgeIdentity,
        ownerSessionId: '100:bridge-start-marker',
        terminatedBridgeIdentities: const [],
        processRepository: _UnusedProcessRepository(),
        loopbackPortApi: const LoopbackPortApi(),
        processStarter: _failingStarter,
        currentUser: ProcessUser.fromRawUser('alex'),
        isWindows: false,
        platform: 'macos',
      );
    }

    test('creates the state directory before the plugin starts', () async {
      final stateDirectory = p.join(tempDir.path, 'plugins', 'acp');

      final host = await createHost(stateDirectory: stateDirectory);

      expect(Directory(stateDirectory).existsSync(), isTrue);
      expect(host.stateDirectory, stateDirectory);
    });

    test('store persists files inside the state directory', () async {
      final stateDirectory = p.join(tempDir.path, 'plugins', 'acp');
      final host = await createHost(stateDirectory: stateDirectory);

      await host.store.write(name: 'state.json', contents: '{"a":1}');

      expect(File(p.join(stateDirectory, 'state.json')).existsSync(), isTrue);
      expect(await host.store.read(name: 'state.json'), '{"a":1}');
    });

    test('wires config, environment, clock, abort signal, and bridge facts through', () async {
      final host = await createHost(stateDirectory: p.join(tempDir.path, 'plugins', 'acp'));

      expect(host.config.intValue('port'), 4096);
      expect(host.environment, equals(<String, String>{'HOME': '/home/alex'}));
      expect(host.clock, isA<ServerClock>());
      expect(host.startAborted.isAborted, isFalse);
      expect(host.bridge.identity, same(bridgeIdentity));
      expect(host.bridge.ownerSessionId, '100:bridge-start-marker');
    });

    test('hands the plugin an unmodifiable view of the environment', () async {
      final host = await createHost(stateDirectory: p.join(tempDir.path, 'plugins', 'acp'));

      expect(() => host.environment['INJECTED'] = 'value', throwsUnsupportedError);
    });

    test('rejects a relative state directory', () async {
      await expectLater(
        createHost(stateDirectory: p.join('relative', 'plugins', 'acp')),
        throwsArgumentError,
      );
    });

    test('ports probe reports a held loopback port as not bindable', () async {
      final occupiedSocket = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(occupiedSocket.close);
      final host = await createHost(stateDirectory: p.join(tempDir.path, 'plugins', 'acp'));

      expect(
        await host.ports.isBindable(host: '127.0.0.1', port: occupiedSocket.port),
        isFalse,
      );
    });
  });
}

Future<Process> _failingStarter(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
  String? workingDirectory,
  bool runInShell = false,
}) {
  throw StateError('This test never spawns');
}

class _UnusedProcessRepository implements ProcessRepository {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) {
    throw UnimplementedError();
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) {
    throw UnimplementedError();
  }
}
