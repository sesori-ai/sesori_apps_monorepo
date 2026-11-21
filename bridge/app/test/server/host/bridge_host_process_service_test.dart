import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sesori_bridge/src/foundation/process_runner.dart';
import 'package:sesori_bridge/src/server/api/system_process_api.dart';
import 'package:sesori_bridge/src/server/api/windows_job_object_api.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_process_service.dart';
import 'package:sesori_bridge/src/server/repositories/process_repository.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show HostProcessCommandExecutor;
import 'package:sesori_plugin_interface/sesori_plugin_interface.dart';
import 'package:test/test.dart';

import '../../helpers/fake_process_repository.dart';

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
      );
    }

    Future<SpawnedProcess> spawnAgent({
      bool isWindows = false,
      String executable = '/usr/local/bin/agent',
      ProcessLifetime lifetime = const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
    }) {
      return service(isWindows: isWindows).spawn(
        includeParentEnvironment: true,
        executable: executable,
        arguments: const ['--stdio'],
        environment: const {'AGENT_MODE': 'acp'},
        workingDirectory: '/tmp/workdir',
        runInShell: false,
        lifetime: lifetime,
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
      expect(starter.includeParentEnvironment, isTrue);
    });

    test('spawn forwards explicit environment isolation to the OS starter', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      await service().spawn(
        executable: '/runtime/agent',
        arguments: const [],
        environment: const {'PATH': '/runtime'},
        workingDirectory: null,
        runInShell: false,
        includeParentEnvironment: false,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
      );
      expect(starter.includeParentEnvironment, isFalse);
      expect(starter.environment, {'PATH': '/runtime'});
    });

    test('spawn starts a Windows runtime that ends with the bridge inside the job object', () async {
      processRepository.jobProcess = _FakeProcess(pidValue: 7001);

      final spawned = await spawnAgent(
        isWindows: true,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
      );

      expect(spawned.pid, 7001);
      expect(processRepository.jobStarts, [
        (
          executable: '/usr/local/bin/agent',
          arguments: const ['--stdio'],
          environment: const {'AGENT_MODE': 'acp'},
          workingDirectory: '/tmp/workdir',
          runInShell: false,
          includeParentEnvironment: true,
        ),
      ]);
      expect(starter.executable, isNull);
      expect(processRepository.boundPids, isEmpty);
    });

    test('spawn falls back to a normal start and a bind when starting inside the job fails', () async {
      processRepository.jobStartError = const OSError('CreateProcess', 2);
      starter.process = _FakeProcess(pidValue: 7001);

      final spawned = await spawnAgent(
        isWindows: true,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
      );

      expect(spawned.pid, 7001);
      expect(starter.executable, '/usr/local/bin/agent');
      expect(processRepository.boundPids, [7001]);
    });

    test('spawn leaves a Windows process that may outlive the bridge out of the job object', () async {
      starter.process = _FakeProcess(pidValue: 7001);

      await spawnAgent(isWindows: true, lifetime: const ProcessLifetime.mayOutliveBridge());

      expect(processRepository.jobStarts, isEmpty);
      expect(processRepository.boundPids, isEmpty);
    });

    test('spawn binds nothing on POSIX, where ownership records stop runtimes', () async {
      starter.process = _FakeProcess(pidValue: 7001);

      await spawnAgent(lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}));

      expect(processRepository.jobStarts, isEmpty);
      expect(processRepository.boundPids, isEmpty);
    });

    test('command executor spawns stay out of the Windows job object', () async {
      // `opencode service start` runs through the command executor and
      // detaches a shared service that must outlive the bridge.
      final process = _FakeProcess(pidValue: 7002);
      starter.process = process;
      unawaited(process.stdoutController.close());
      unawaited(process.stderrController.close());
      process.exitCodeCompleter.complete(0);
      final executor = HostProcessCommandExecutor(
        processes: service(isWindows: true),
        runInShell: true,
        includeParentEnvironment: true,
        maxCapturedOutputCharactersPerStream: null,
      );

      await executor.run(
        executable: 'opencode',
        arguments: const ['service', 'start'],
        workingDirectory: null,
        environment: null,
        timeout: null,
      );

      expect(starter.executable, 'opencode');
      expect(processRepository.jobStarts, isEmpty);
      expect(processRepository.boundPids, isEmpty);
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

    test('spawn upgrades the identity of a launcher that already execed its native binary in the same pid', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      final inspected = _identity(
        pid: 7001,
        startMarker: 'Mon Jun  1 09:00:00 2026',
        executablePath: '/opt/vendor/agent-native',
        commandLine: '/opt/vendor/agent-native --stdio',
      );
      processRepository.inspectResults[7001] = <ProcessIdentity?>[inspected];

      final spawned = await spawnAgent();

      expect(spawned.identity, same(inspected));
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
      processRepository.jobProcess = _FakeProcess(pidValue: 7001);
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
      processRepository.jobProcess = _FakeProcess(pidValue: 7001);
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
      processRepository.jobProcess = _FakeProcess(pidValue: 7001);
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

    test('signals reach the descendants of a running POSIX child that ends with the bridge', () async {
      final process = _FakeProcess(pidValue: 7001);
      starter.process = process;
      processRepository.descendants[7001] = <int>[7002, 7003];
      processRepository.gracefulResult = _signalResult(pid: 7001, signal: ShutdownSignal.graceful);
      processRepository.forceResult = _signalResult(pid: 7001, signal: ShutdownSignal.force);
      final host = service();
      await host.spawn(
        includeParentEnvironment: true,
        executable: '/usr/local/bin/agent',
        arguments: const ['acp'],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{'__shared_helper'}),
      );

      final graceful = await host.signalGraceful(pid: 7001);
      await host.signalForce(pid: 7001);

      expect(graceful.pid, 7001);
      expect(
        processRepository.signalRequests,
        equals(<String>['graceful:7002', 'graceful:7003', 'graceful:7001', 'force:7002', 'force:7003', 'force:7001']),
      );
      // The listing leaves out the shared helpers the spawn declared.
      expect(
        processRepository.descendantQueries,
        equals(<Set<String>>[
          <String>{'__shared_helper'},
          <String>{'__shared_helper'},
        ]),
      );

      // Once the child exits its pid may be reused, so only that pid is signalled.
      process.exitCodeCompleter.complete(0);
      await process.exitCode;
      await Future<void>.delayed(Duration.zero);
      processRepository.signalRequests.clear();
      await host.signalForce(pid: 7001);
      expect(processRepository.signalRequests, equals(<String>['force:7001']));
    });

    test('a Windows child sharing helpers starts outside the job and is stopped process by process', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.descendants[7001] = <int>[7002, 7003];
      processRepository.killErrors[7002] = const ProcessException('taskkill', <String>[], 'Access denied', 1);
      final host = service(isWindows: true);
      await host.spawn(
        includeParentEnvironment: true,
        executable: 'omp.exe',
        arguments: const ['acp'],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{'__shared_helper'}),
      );

      expect(processRepository.jobStarts, isEmpty);
      expect(processRepository.boundPids, isEmpty);
      expect(starter.executable, 'omp.exe');

      final graceful = await host.signalGraceful(pid: 7001);

      // No `taskkill /T`: each process is killed on its own, one failure does
      // not stop the rest, and the root goes last so its exit means the rest
      // is already killed.
      expect(graceful.pid, 7001);
      expect(graceful.requestedSignal, ShutdownSignal.graceful);
      expect(processRepository.signalRequests, equals(<String>['kill:7002', 'kill:7003', 'kill:7001']));
      expect(
        processRepository.descendantQueries,
        equals(<Set<String>>[
          <String>{'__shared_helper'},
        ]),
      );
    });

    test('a Windows child in the job keeps the whole-tree signal', () async {
      processRepository.jobProcess = _FakeProcess(pidValue: 7001);
      processRepository.forceResult = _signalResult(pid: 7001, signal: ShutdownSignal.force);
      final host = service(isWindows: true);
      await host.spawn(
        includeParentEnvironment: true,
        executable: 'agent.exe',
        arguments: const ['acp'],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
      );

      await host.signalForce(pid: 7001);

      expect(processRepository.signalRequests, equals(<String>['force:7001']));
      expect(processRepository.descendantQueries, isEmpty);
    });

    test('signals leave the descendants of a child that may outlive the bridge running', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.descendants[7001] = <int>[7002];
      processRepository.forceResult = _signalResult(pid: 7001, signal: ShutdownSignal.force);
      final host = service();
      await host.spawn(
        includeParentEnvironment: true,
        executable: '/usr/local/bin/opencode',
        arguments: const ['service', 'start'],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        lifetime: const ProcessLifetime.mayOutliveBridge(),
      );

      await host.signalForce(pid: 7001);

      expect(processRepository.signalRequests, equals(<String>['force:7001']));
    });

    test('a failed descendant listing still signals the child itself', () async {
      starter.process = _FakeProcess(pidValue: 7001);
      processRepository.descendantsError = const ProcessException('ps', <String>[], 'boom', 1);
      processRepository.gracefulResult = _signalResult(pid: 7001, signal: ShutdownSignal.graceful);
      final host = service();
      await host.spawn(
        includeParentEnvironment: true,
        executable: '/usr/local/bin/agent',
        arguments: const ['acp'],
        environment: null,
        workingDirectory: null,
        runInShell: false,
        lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
      );

      await host.signalGraceful(pid: 7001);

      expect(processRepository.signalRequests, equals(<String>['graceful:7001']));
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
            ),
            windowsJobObjectApi: WindowsJobObjectApi(),
            currentUser: null,
          ),
          clock: const ServerClock(),
          currentUser: null,
          isWindows: Platform.isWindows,
        );

        final spawned = await realService.spawn(
          includeParentEnvironment: true,
          executable: '/bin/cat',
          arguments: const [],
          environment: null,
          workingDirectory: null,
          runInShell: false,
          lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
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

      test('signalGraceful also stops a command the child left running in the background', () async {
        if (Platform.isWindows) {
          return;
        }

        final realService = BridgeHostProcessService(
          processStarter: Process.start,
          processRepository: ProcessRepository(
            api: SystemProcessApi(processRunner: ProcessRunner(), clock: const ServerClock(), isWindows: false),
            windowsJobObjectApi: WindowsJobObjectApi(),
            currentUser: null,
          ),
          clock: const ServerClock(),
          currentUser: null,
          isWindows: false,
        );
        // Like a harness running a tool command: the shell dies on SIGTERM
        // and would leave its `sleep` behind, reparented to init.
        final spawned = await realService.spawn(
          includeParentEnvironment: true,
          executable: '/bin/sh',
          arguments: const ['-c', r'sleep 60 & echo $!; wait'],
          environment: null,
          workingDirectory: null,
          runInShell: false,
          lifetime: const ProcessLifetime.endsWithBridge(sharedHelperArguments: <String>{}),
        );
        unawaited(spawned.stderr.drain<void>());
        final grandchildPid = int.parse((await spawned.stdout.transform(utf8.decoder).first).trim());
        addTearDown(() => Process.killPid(grandchildPid, ProcessSignal.sigkill));

        await realService.signalGraceful(pid: spawned.pid);
        await spawned.exitCode.timeout(const Duration(seconds: 5));

        expect(await _waitUntilGone(pid: grandchildPid), isTrue, reason: 'sleep $grandchildPid survived its parent');
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
    capturedAt: DateTime.utc(2026, 5, 15, 12),
  );
}

Future<bool> _waitUntilGone({required int pid}) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    final result = await Process.run('ps', <String>['-p', '$pid', '-o', 'stat=']);
    final state = result.stdout.toString().trim();
    // An exited orphan can linger briefly as a zombie until init reaps it.
    if (result.exitCode != 0 || state.isEmpty || state.startsWith('Z')) return true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  return false;
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

class _RecordingStarter() {
  _FakeProcess? process;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  String? workingDirectory;
  bool? runInShell;
  bool? includeParentEnvironment;

  Future<Process> call(
    String executable,
    List<String> arguments, {
    Map<String, String>? environment,
    String? workingDirectory,
    bool runInShell = false,
    required bool includeParentEnvironment,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    this.workingDirectory = workingDirectory;
    this.runInShell = runInShell;
    this.includeParentEnvironment = includeParentEnvironment;
    final process = this.process;
    if (process == null) {
      throw StateError('No fake process configured');
    }
    return process;
  }
}

class _FakeProcess({required final int _pidValue}) implements Process {
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

class _FakeServerClock() implements ServerClock {
  @override
  DateTime now() {
    return DateTime.utc(2026, 5, 15, 12, 30);
  }

  @override
  Future<void> delay({required Duration duration}) async {}
}

class _FakeProcessRepository() extends StrictFakeProcessRepository {
  final Map<int, List<ProcessIdentity?>> inspectResults = <int, List<ProcessIdentity?>>{};
  Object? inspectError;
  SignalResult? gracefulResult;
  SignalResult? forceResult;
  final List<String> signalRequests = <String>[];
  final Map<int, List<int>> descendants = <int, List<int>>{};
  Object? descendantsError;
  final Map<int, Object> killErrors = <int, Object>{};
  final List<Set<String>> descendantQueries = <Set<String>>[];
  final List<int> boundPids = <int>[];
  final List<
    ({
      String executable,
      List<String> arguments,
      Map<String, String>? environment,
      String? workingDirectory,
      bool runInShell,
      bool includeParentEnvironment,
    })
  >
  jobStarts = [];
  Process? jobProcess;
  Object? jobStartError;

  @override
  Process startBoundToBridgeLifetime({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
    required bool includeParentEnvironment,
  }) {
    jobStarts.add((
      executable: executable,
      arguments: arguments,
      environment: environment,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      includeParentEnvironment: includeParentEnvironment,
    ));
    final error = jobStartError;
    if (error != null) {
      throw error;
    }
    return jobProcess ?? fail('no job process configured');
  }

  @override
  void bindToBridgeLifetime({required int pid}) => boundPids.add(pid);

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
  Future<List<int>> listDescendants({required int pid, required Set<String> sharedHelperArguments}) async {
    descendantQueries.add(sharedHelperArguments);
    final error = descendantsError;
    if (error != null) {
      throw error;
    }
    return descendants[pid] ?? const <int>[];
  }

  @override
  Future<SignalResult> sendGracefulSignal({required int pid}) async {
    signalRequests.add('graceful:$pid');
    return gracefulResult ?? fail('no graceful signal result configured');
  }

  @override
  Future<SignalResult> sendForceSignal({required int pid}) async {
    signalRequests.add('force:$pid');
    return forceResult ?? fail('no force signal result configured');
  }

  @override
  Future<SignalResult> killWindowsProcess({required int pid, required ShutdownSignal requestedSignal}) async {
    signalRequests.add('kill:$pid');
    final error = killErrors[pid];
    if (error != null) {
      throw error;
    }
    return _signalResult(pid: pid, signal: requestedSignal);
  }
}
