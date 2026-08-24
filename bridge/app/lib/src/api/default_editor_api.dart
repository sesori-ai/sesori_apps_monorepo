import 'package:sesori_bridge_foundation/sesori_bridge_foundation.dart' show PlatformOs;

import '../foundation/process_runner.dart';

sealed class DefaultEditorApi {
  Future<void> openFile(String filePath);

  factory forPlatform({
    required PlatformOs platform,
    required ProcessRunner processRunner,
  }) => switch (platform) {
    PlatformOs.macos => _MacosDefaultEditorApi(processRunner: processRunner),
    PlatformOs.linux => _LinuxDefaultEditorApi(processRunner: processRunner),
    PlatformOs.windows => _WindowsDefaultEditorApi(processRunner: processRunner),
  };
}

final class _MacosDefaultEditorApi({required final ProcessRunner _processRunner}) implements DefaultEditorApi {
  @override
  Future<void> openFile(String filePath) async {
    await _processRunner.startDetached(executable: 'open', arguments: [filePath]);
  }
}

final class _LinuxDefaultEditorApi({required final ProcessRunner _processRunner}) implements DefaultEditorApi {
  @override
  Future<void> openFile(String filePath) async {
    await _processRunner.startDetached(executable: 'xdg-open', arguments: [filePath]);
  }
}

final class _WindowsDefaultEditorApi({required final ProcessRunner _processRunner}) implements DefaultEditorApi {
  @override
  Future<void> openFile(String filePath) async {
    await _processRunner.startDetached(executable: 'cmd', arguments: ['/c', 'start', '', filePath]);
  }
}
