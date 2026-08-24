import 'dart:async';
import 'dart:io';

import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;
import 'package:win32/win32.dart';

import '../foundation/process_starter.dart';
import '../foundation/warning_logger.dart';

typedef ExecutionStateSetter = EXECUTION_STATE Function(EXECUTION_STATE flags);

/// Controls device wake lock state.
sealed class WakeLockClient {
  Future<void> enable();

  Future<void> disable();

  /// Whether this platform's wake-lock implementation also prevents the
  /// system from sleeping when the laptop lid is closed.
  bool get preventsLidCloseSleep;

  factory forPlatform({
    required PlatformOs platform,
    required ProcessStarter processStarter,
    required ExecutionStateSetter executionStateSetter,
    required WarningLogger warningLogger,
  }) => switch (platform) {
    PlatformOs.macos => _MacOSWakeLockClient(processStarter: processStarter, warningLogger: warningLogger),
    PlatformOs.linux => _LinuxWakeLockClient(processStarter: processStarter, warningLogger: warningLogger),
    PlatformOs.windows => _WindowsWakeLockClient(
      executionStateSetter: executionStateSetter,
      warningLogger: warningLogger,
    ),
  };
}

final class _MacOSWakeLockClient({
  required final ProcessStarter _processStarter,
  required final WarningLogger _warningLogger,
}) implements WakeLockClient {
  Process? _process;

  @override
  Future<void> enable() async {
    await disable();
    try {
      _process = await _processStarter('caffeinate', <String>['-i', '-s', '-w', pid.toString()]);
    } on ProcessException catch (error, stackTrace) {
      _warningLogger('[wake-lock] caffeinate unavailable', error, stackTrace);
    }
  }

  @override
  Future<void> disable() async {
    final process = _process;
    _process = null;
    process?.kill();
  }

  @override
  bool get preventsLidCloseSleep => false;
}

final class _LinuxWakeLockClient({
  required final ProcessStarter _processStarter,
  required final WarningLogger _warningLogger,
}) implements WakeLockClient {
  Process? _process;

  @override
  Future<void> enable() async {
    if (_process != null) return;

    try {
      final process = await _processStarter('systemd-inhibit', const <String>[
        '--what=idle:sleep:handle-lid-switch',
        '--who=sesori-bridge',
        '--why=Bridge is running',
        'cat',
      ]);
      _process = process;
      unawaited(
        process.exitCode.then((exitCode) {
          if (_process == process) {
            _process = null;
            if (exitCode != 0) _warningLogger('[wake-lock] systemd-inhibit exited unexpectedly with code $exitCode');
          }
        }),
      );
    } on ProcessException catch (error, stackTrace) {
      _warningLogger('[wake-lock] systemd-inhibit unavailable', error, stackTrace);
    }
  }

  @override
  Future<void> disable() async {
    final process = _process;
    _process = null;
    process?.kill();
  }

  @override
  bool get preventsLidCloseSleep => _process != null;
}

final class _WindowsWakeLockClient({
  required final ExecutionStateSetter executionStateSetter,
  required final WarningLogger warningLogger,
}) implements WakeLockClient {
  @override
  Future<void> enable() async => _setExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED, action: 'enable');

  @override
  Future<void> disable() async => _setExecutionState(ES_CONTINUOUS, action: 'disable');

  void _setExecutionState(EXECUTION_STATE flags, {required String action}) {
    if (executionStateSetter(flags) == 0) {
      warningLogger('[wake-lock] SetThreadExecutionState($action) failed');
    }
  }

  @override
  bool get preventsLidCloseSleep => false;
}
