import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:win32/win32.dart';

import 'linux_wake_lock_api.dart';
import 'macos_wake_lock_api.dart';
import 'windows_wake_lock_api.dart';

/// Controls device wake lock state.
abstract class WakeLockClient {
  Future<void> enable();

  Future<void> disable();

  /// Whether this platform's wake-lock implementation also prevents the
  /// system from sleeping when the laptop lid is closed.
  bool get preventsLidCloseSleep;

  factory WakeLockClient.forPlatform() => switch (true) {
    _ when Platform.isMacOS => MacOSWakeLockApi(processStarter: Process.start),
    _ when Platform.isLinux => LinuxWakeLockApi(processStarter: Process.start),
    _ when Platform.isWindows => WindowsWakeLockApi(
      executionStateSetter: SetThreadExecutionState,
      warningLogger: Log.w,
    ),
    _ => throw UnsupportedError(
      'Unsupported platform for wake lock: ${Platform.operatingSystem}',
    ),
  };
}
