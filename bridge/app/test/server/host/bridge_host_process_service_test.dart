import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge/src/bridge/foundation/process_runner.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/foundation/process_match.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_process_service.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeHostProcessService', () {
    late _RecordingStarter starter;
    late _FakeProcessRepository processRepository;

    setUp(() {
      starter = _RecordingStarter();
      processRepository = _FakeProcessRepository();
    });

    BridgeHostProcessService service({bool isWindows = false}) {
      return BridgeHostProcessService(
        processStarter: starter.call,
        processRepository: processRepository,
        clock: _FakeServerClock(),
        currentUser: ProcessUser.fromRawUser('alex'),
        isWindows: isWindows,
        platform: 'macos',
      );
    }

    Future<SpawnedProcess> spawnAgent({bool isWindows = false, String executable = '/usr/local/bin/agent'}) {
      return service(isWindows: isWindows).spawn(
        executable: executable,
        arguments: const ['--stdio'],
        environment: const {'AGENT_MODE': 'acp'},
        workingDirectory: '/tmp/workdir',
        runInShell: false,
      );
    }

    test('spawn forwards executable, arguments, environment, workingDirectory, and runInShell', () async {
      starter.process = _FakeProcess(pidValue: 7001);

      await spawnAgent();

      expect(starter.executable, '/usr/local/bin/agent');
      expect(starter.arguments, equals(<String>['--stdio']));
      expect(starter.environment, equals(<String, String>{'AGENT_MODE': 'acp'}));
      expect(starter.workingDirectory, '/tmp/workdir');
      expect(starter.runInShell, isFalse);
    });

    test('spawn upgrades the identity from post-spawn inspection when the command line matches', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      final inspected = _identity(
        pid: 7001,
        startMarker: 'Mon Jun  1 09:00:00 2026',
        executablePath: '/usr/local/bin/agent',
        commandLine: '/usr/local/bin/agent --stdio',
      );
      processRepository.inspectResults[7001] = <ProcessIdentity?>[inspected];

      final spawned = await spawnAgent();

      expect(spawned.identity, same(inspected));
      expect(spawned.identity.startMarker, 'Mon Jun  1 09:00:00 2026');
    });

    test('spawn falls back to the partial spawn-time identity when the child is already gone', () async {
      starter.process = _FakeProcess(pidValue: 7001);

      final spawned = await spawnAgent();

      expect(spawned.identity.pid, 7001);
      expect(spawned.identity.startMarker, isNull);
      expect(spawned.identity.executablePath, '/usr/local/bin/agent');
      expect(spawned.identity.commandLine, '/usr/local/bin/agent --stdio');
      expect(spawned.identity.ownerUser, ProcessUser.fromRawUser('alex'));
      expect(spawned.identity.platform, 'macos');
    });

    test('spawn falls back when the inspected command line does not match (pid reuse)', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.inspectResults[7001] = <ProcessIdentity?>[
        _identity(
          pid: 7001,
          startMarker: 'Mon Jun  1 09:00:00 2026',
          executablePath: '/usr/bin/vim',
          commandLine: '/usr/bin/vim notes.txt',
        ),
      ];

      final spawned = await spawnAgent();

      expect(spawned.identity.startMarker, isNull);
      expect(spawned.identity.commandLine, '/usr/local/bin/agent --stdio');
    });

    test('spawn upgrades the identity for an interpreter-shim spawn (ps prefixes the interpreter)', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      // A `#!/usr/bin/env node` wrapper (e.g. Homebrew's `codex`) is reported by
      // ps with `node` prepended to our exact spawn command line. The adopted
      // identity must still carry the real start marker so ownership matching
      // works across restarts (otherwise the child + its port leak).
      final inspected = _identity(
        pid: 7001,
        startMarker: 'Mon Jun  1 09:00:00 2026',
        executablePath: '/opt/homebrew/bin/node',
        commandLine: 'node /usr/local/bin/agent --stdio',
      );
      processRepository.inspectResults[7001] = <ProcessIdentity?>[inspected];

      final spawned = await spawnAgent();

      expect(spawned.identity, same(inspected));
      expect(spawned.identity.startMarker, 'Mon Jun  1 09:00:00 2026');
    });

    test('spawn falls back when inspection throws instead of failing the spawn', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.inspectError = const ProcessException('ps', <String>['-p', '7001']);

      final spawned = await spawnAgent();

      expect(spawned.identity.pid, 7001);
      expect(spawned.identity.startMarker, isNull);
    });

    test('spawn falls back when inspection throws an Error — the child must never be orphaned', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.inspectError = ArgumentError('broken process-table parse');

      final spawned = await spawnAgent();

      expect(spawned.identity.pid, 7001);
      expect(spawned.identity.startMarker, isNull);
    });

    test('spawn matches Windows image-name-only command lines by executable path', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      final inspected = _identity(
        pid: 7001,
        startMarker: null,
        executablePath: r'C:\TOOLS\AGENT.EXE',
        commandLine: 'agent.exe',
      );
      processRepository.inspectResults[7001] = <ProcessIdentity?>[inspected];

      final spawned = await spawnAgent(isWindows: true, executable: 'C:/tools/agent.exe');

      expect(spawned.identity, same(inspected));
    });

    test('spawn matches a bare Windows image name against the resolved path by basename', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      final inspected = _identity(
        pid: 7001,
        startMarker: null,
        executablePath: r'C:\Program Files\agent\agent.exe',
        commandLine: 'agent.exe',
      );
      processRepository.inspectResults[7001] = <ProcessIdentity?>[inspected];

      final spawned = await spawnAgent(isWindows: true, executable: 'agent.exe');

      expect(spawned.identity, same(inspected));
    });

    test('spawn rejects Windows image-name-only matches with a different executable', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.inspectResults[7001] = <ProcessIdentity?>[
        _identity(
          pid: 7001,
          startMarker: null,
          executablePath: r'C:\other\bogus.exe',
          commandLine: 'bogus.exe',
        ),
      ];

      final spawned = await spawnAgent(isWindows: true, executable: r'C:\tools\agent.exe');

      expect(spawned.identity.executablePath, r'C:\tools\agent.exe');
      expect(spawned.identity.startMarker, isNull);
    });

    test('spawn leaves stdout and stderr to the caller instead of draining them', () async {
      final process = _FakeProcess(pidValue: 7001);
      starter.process = process;

      final spawned = await spawnAgent();

      // Single-subscription streams: this listen would throw if the service
      // had subscribed (drained) them itself.
      final stdoutChunks = <List<int>>[];
      final stderrChunks = <List<int>>[];
      spawned.stdout.listen(stdoutChunks.add);
      spawned.stderr.listen(stderrChunks.add);
      process.stdoutController.add(utf8.encode('out'));
      process.stderrController.add(utf8.encode('err'));
      await pumpEventQueue();

      expect(utf8.decode(stdoutChunks.single), 'out');
      expect(utf8.decode(stderrChunks.single), 'err');
    });

    test('spawned process exposes pid and exitCode of the child', () async {
      final process = _FakeProcess(pidValue: 7001);
      starter.process = process;

      final spawned = await spawnAgent();
      process.exitCodeCompleter.complete(3);

      expect(spawned.pid, 7001);
      expect(await spawned.exitCode, 3);
    });

    test('inspect delegates to the process repository', () async {
      final identity = _identity(
        pid: 211,
        startMarker: 'marker',
        executablePath: '/usr/local/bin/opencode',
        commandLine: '/usr/local/bin/opencode serve',
      );
      processRepository.inspectResults[211] = <ProcessIdentity?>[identity];

      expect(await service().inspect(pid: 211), same(identity));
    });

    test('signalGraceful and signalForce delegate to the process repository', () async {
      processRepository.gracefulResult = _signalResult(pid: 211, signal: ShutdownSignal.graceful);
      processRepository.forceResult = _signalResult(pid: 211, signal: ShutdownSignal.force);

      final graceful = await service().signalGraceful(pid: 211);
      final force = await service().signalForce(pid: 211);

      expect(graceful.requestedSignal, ShutdownSignal.graceful);
      expect(force.requestedSignal, ShutdownSignal.force);
      expect(processRepository.signalRequests, equals(<String>['graceful:211', 'force:211']));
    });

    group('against a real child process', () {
      // This is a deliberate integration test over the real `Process.start`
      // seam: it proves the stdio surface, exitCode, and pid that the fakes
      // stand in for elsewhere actually behave as expected end-to-end.
      //
      // It intentionally does NOT assert on `identity.startMarker` /
      // identity adoption. That depends on a real `ps` lookup racing the
      // just-spawned child and on `ps` output format, which makes it
      // environment-flaky. The marker-capture parsing is covered
      // deterministically by `system_process_api_test.dart`, and the
      // spawn-time identity adoption/matching by the faked-repository tests
      // above — neither needs a real process.
      test('spawn exposes a working stdio surface over a real child', () async {
        if (Platform.isWindows) {
          return;
        }

        final realService = BridgeHostProcessService(
          processStarter: Process.start,
          processRepository: ProcessRepository(
            api: SystemProcessApi(
              processRunner: ProcessRunner(),
              clock: const ServerClock(),
              isWindows: Platform.isWindows,
              platform: Platform.operatingSystem,
            ),
            currentUser: null,
          ),
          clock: const ServerClock(),
          currentUser: null,
          isWindows: Platform.isWindows,
          platform: Platform.operatingSystem,
        );

        final spawned = await realService.spawn(
          executable: '/bin/cat',
          arguments: const [],
          environment: null,
          workingDirectory: null,
          runInShell: false,
        );

        final stdoutFuture = spawned.stdout.transform(utf8.decoder).join();
        final stderrFuture = spawned.stderr.transform(utf8.decoder).join();

        spawned.stdin.writeln('ping');
        await spawned.stdin.flush();
        await spawned.stdin.close();

        expect(await spawned.exitCode, 0);
        expect(await stdoutFuture, 'ping\n');
        expect(await stderrFuture, isEmpty);
        expect(spawned.pid, greaterThan(0));
        expect(spawned.identity.pid, spawned.pid);
      });
    });
  });
}

ProcessIdentity _identity({
  required int pid,
  required String? startMarker,
  required String executablePath,
  required String commandLine,
}) {
  return ProcessIdentity(
    pid: pid,
    startMarker: startMarker,
    executablePath: executablePath,
    commandLine: commandLine,
    ownerUser: ProcessUser.fromRawUser('alex'),
    platform: 'macos',
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

SignalResult _signalResult({required int pid, required ShutdownSignal signal}) {
  return SignalResult(
    pid: pid,
    requestedSignal: signal,
    deliveredSignal: signal == ShutdownSignal.graceful ? ProcessSignal.sigterm : ProcessSignal.sigkill,
    wasRequested: true,
    attemptedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

class _RecordingStarter {
  _FakeProcess? process;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  String? workingDirectory;
  bool? runInShell;

  Future<Process> call(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    this.workingDirectory = workingDirectory;
    this.runInShell = runInShell;
    final process = this.process;
    if (process == null) {
      throw StateError('No fake process configured');
    }
    return process;
  }
}

class _FakeProcess implements Process {
  _FakeProcess({required int pidValue}) : _pidValue = pidValue;

  final int _pidValue;
  final StreamController<List<int>> stdoutController = StreamController<List<int>>();
  final StreamController<List<int>> stderrController = StreamController<List<int>>();
  final Completer<int> exitCodeCompleter = Completer<int>();

  @override
  int get pid => _pidValue;

  @override
  Stream<List<int>> get stdout => stdoutController.stream;

  @override
  Stream<List<int>> get stderr => stderrController.stream;

  @override
  Future<int> get exitCode => exitCodeCompleter.future;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    return true;
  }
}

class _FakeServerClock implements ServerClock {
  @override
  DateTime now() {
    return DateTime.utc(2026, 5, 15, 12, 30);
  }

  @override
  Future<void> delay({required Duration duration}) async {}
}

class _FakeProcessRepository implements ProcessRepository {
  @override
  Future<int> startDetached({
    required String executable,
    required List<String> arguments,
    Map<String, String>? environment,
  }) async {
    throw UnimplementedError();
  }

  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
  Object? inspectError;
  SignalResult? gracefulResult;
  SignalResult? forceResult;
  final List<String> signalRequests = <String>[];

  @override
  Future<ProcessIdentity?> inspectProcess({required int pid}) async {
    final error = inspectError;
    if (error != null) {
      throw error;
    }
    final queue = inspectResults[pid];
    if (queue == null || queue.isEmpty) {
      return null;
    }
    return queue.removeAt(0);
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add('graceful:$pid');
    return gracefulResult!;
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) async {
    signalRequests.add('force:$pid');
    return forceResult!;
  }

  @override
  Future<ProcessMatch?> inspectProcessMatch({required int pid}) {
    throw UnimplementedError();
  }
}
