import 'dart:async';
import 'dart:io';

import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;
import 'package:test/test.dart';
import 'package:win32/win32.dart';

void main() {
  test('macOS starts caffeinate and kills it on disable', () async {
    final process = _FakeProcess();
    final calls = <List<String>>[];
    final client = _client(
      platform: PlatformOs.macos,
      processStarter: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return process;
      },
    );

    await client.enable();
    await client.disable();

    expect(calls, [
      ['caffeinate', '-i', '-s', '-w', pid.toString()],
    ]);
    expect(process.killCalled, isTrue);
    expect(client.preventsLidCloseSleep, isFalse);
  });

  test('Linux starts systemd-inhibit once and kills it on disable', () async {
    final process = _FakeProcess();
    final calls = <List<String>>[];
    final client = _client(
      platform: PlatformOs.linux,
      processStarter: (executable, arguments) async {
        calls.add([executable, ...arguments]);
        return process;
      },
    );

    await client.enable();
    await client.enable();
    await client.disable();

    expect(calls.single, [
      'systemd-inhibit',
      '--what=idle:sleep:handle-lid-switch',
      '--who=sesori-bridge',
      '--why=Bridge is running',
      'cat',
    ]);
    expect(process.killCalled, isTrue);
    expect(client.preventsLidCloseSleep, isTrue);
  });

  for (final platform in [PlatformOs.macos, PlatformOs.linux]) {
    test('${platform.name} logs unavailable process with error and stack trace', () async {
      final warnings = <({String message, Object? error, StackTrace? stackTrace})>[];
      final client = WakeLockClient.forPlatform(
        platform: platform,
        processStarter: (executable, arguments) async {
          throw ProcessException(executable, arguments, 'unavailable');
        },
        executionStateSetter: (_) => const EXECUTION_STATE(1),
        warningLogger: (message, [error, stackTrace]) {
          warnings.add((message: message, error: error, stackTrace: stackTrace));
        },
      );

      await client.enable();

      expect(warnings.single.message, contains('unavailable'));
      expect(warnings.single.error, isA<ProcessException>());
      expect(warnings.single.stackTrace, isNotNull);
    });
  }

  test('Linux logs unexpected nonzero process exit', () async {
    final process = _FakeProcess();
    final warnings = <String>[];
    final client = WakeLockClient.forPlatform(
      platform: PlatformOs.linux,
      processStarter: (_, _) async => process,
      executionStateSetter: (_) => const EXECUTION_STATE(1),
      warningLogger: (message, [_, _]) => warnings.add(message),
    );

    await client.enable();
    process.completeExit(7);
    await Future<void>.delayed(Duration.zero);

    expect(warnings.single, contains('exited unexpectedly with code 7'));
  });

  test('Windows sets expected execution states and warns on failure', () async {
    final flags = <EXECUTION_STATE>[];
    final warnings = <String>[];
    final client = WakeLockClient.forPlatform(
      platform: PlatformOs.windows,
      processStarter: Process.start,
      executionStateSetter: (value) {
        flags.add(value);
        return flags.length == 1 ? const EXECUTION_STATE(1) : const EXECUTION_STATE(0);
      },
      warningLogger: (message, [_, _]) => warnings.add(message),
    );

    await client.enable();
    await client.disable();

    expect(flags, [ES_CONTINUOUS | ES_SYSTEM_REQUIRED, ES_CONTINUOUS]);
    expect(warnings.single, contains('SetThreadExecutionState(disable) failed'));
    expect(client.preventsLidCloseSleep, isFalse);
  });
}

WakeLockClient _client({required PlatformOs platform, required ProcessStarter processStarter}) {
  return WakeLockClient.forPlatform(
    platform: platform,
    processStarter: processStarter,
    executionStateSetter: (_) => const EXECUTION_STATE(1),
    warningLogger: (_, [_, _]) {},
  );
}

typedef ProcessStarter = Future<Process> Function(String executable, List<String> arguments);

class _FakeProcess() implements Process {
  bool killCalled = false;
  final Completer<int> _exitCode = Completer<int>();

  @override
  Future<int> get exitCode => _exitCode.future;

  void completeExit(int exitCode) => _exitCode.complete(exitCode);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killCalled = true;
    if (!_exitCode.isCompleted) _exitCode.complete(0);
    return true;
  }

  @override
  int get pid => 12345;

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Stream<List<int>> get stdout => const Stream.empty();
}
