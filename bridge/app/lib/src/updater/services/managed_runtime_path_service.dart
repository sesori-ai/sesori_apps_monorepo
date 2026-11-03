import 'dart:io' show Platform;

import 'package:path/path.dart' as p;
import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show resolveUserHomeDirectory;

import '../models/managed_runtime_paths.dart';

class const ManagedRuntimePathService() {
  ManagedRuntimePaths currentPaths({required Map<String, String> environment}) {
    if (Platform.isWindows) {
      final localAppData = environment['LOCALAPPDATA'];
      if (localAppData == null || localAppData.isEmpty) {
        throw StateError('LOCALAPPDATA environment variable not set');
      }
      final installRoot = p.join(localAppData, 'sesori');
      return ManagedRuntimePaths(installRoot: installRoot, binaryPath: p.join(installRoot, 'bin', 'sesori-bridge.exe'));
    }

    final home = resolveUserHomeDirectory(environment: environment);
    if (home == null) {
      throw StateError('HOME environment variable not set');
    }
    final installRoot = p.join(home, '.local', 'share', 'sesori');
    return ManagedRuntimePaths(installRoot: installRoot, binaryPath: p.join(installRoot, 'bin', 'sesori-bridge'));
  }
}
