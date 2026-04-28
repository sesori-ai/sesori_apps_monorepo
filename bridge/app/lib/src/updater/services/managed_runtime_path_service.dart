import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

import '../models/managed_runtime_paths.dart';

class ManagedRuntimePathService {
  const ManagedRuntimePathService();

  ManagedRuntimePaths currentPaths({required Map<String, String> environment}) {
    if (Platform.isWindows) {
      final localAppData = _requireEnv(
        environment: environment,
        key: 'LOCALAPPDATA',
      );
      final installRoot = p.join(localAppData, 'sesori');
      return ManagedRuntimePaths(
        installRoot: installRoot,
        binaryPath: p.join(installRoot, 'bin', 'sesori-bridge.exe'),
        cacheDirectory: installRoot,
      );
    }

    final home = _requireEnv(environment: environment, key: 'HOME');
    final installRoot = p.join(home, '.local', 'share', 'sesori');
    return ManagedRuntimePaths(
      installRoot: installRoot,
      binaryPath: p.join(installRoot, 'bin', 'sesori-bridge'),
      cacheDirectory: installRoot,
    );
  }

  String _requireEnv({required Map<String, String> environment, required String key}) {
    final value = environment[key];
    if (value == null || value.isEmpty) {
      throw StateError('$key environment variable not set');
    }

    return value;
  }
}
