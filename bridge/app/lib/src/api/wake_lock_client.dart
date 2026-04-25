import 'dart:io';

import 'linux_wake_lock_api.dart';
import 'macos_wake_lock_api.dart';
import 'windows_wake_lock_api.dart';

/// Controls device wake lock state.
abstract class WakeLockClient {
  Future<void> enable();

  Future<void> disable();

  static WakeLockClient forPlatform() {
    return switch (Platform.operatingSystem) {
      'macos' => MacOSWakeLockApi(processStarter: Process.start),
      'linux' => LinuxWakeLockApi(processStarter: Process.start),
      'windows' => WindowsWakeLockApi(),
      _ => throw UnsupportedError(
        'Unsupported platform for wake lock: ${Platform.operatingSystem}',
      ),
    };
  }
}
