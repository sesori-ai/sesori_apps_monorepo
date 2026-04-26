import 'dart:io';

import 'linux_wake_lock_api.dart';
import 'macos_wake_lock_api.dart';
import 'windows_wake_lock_api.dart';

/// Controls device wake lock state.
abstract class WakeLockClient {
  Future<void> enable();

  Future<void> disable();

  factory WakeLockClient.forPlatform() => switch (true) {
    _ when Platform.isMacOS => MacOSWakeLockApi(processStarter: Process.start),
    _ when Platform.isLinux => LinuxWakeLockApi(processStarter: Process.start),
    _ when Platform.isWindows => WindowsWakeLockApi(),
    _ => throw UnsupportedError(
      'Unsupported platform for wake lock: ${Platform.operatingSystem}',
    ),
  };
}
