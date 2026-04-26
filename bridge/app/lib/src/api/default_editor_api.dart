import 'dart:io';

import '../bridge/foundation/process_runner.dart';
import 'linux_default_editor_api.dart';
import 'macos_default_editor_api.dart';
import 'windows_default_editor_api.dart';

abstract class DefaultEditorApi {
  Future<void> openFile(String filePath);

  factory DefaultEditorApi.forPlatform({
    required ProcessRunner processRunner,
  }) => switch (true) {
    _ when Platform.isMacOS => MacosDefaultEditorApi(processRunner: processRunner),
    _ when Platform.isLinux => LinuxDefaultEditorApi(processRunner: processRunner),
    _ when Platform.isWindows => WindowsDefaultEditorApi(processRunner: processRunner),
    _ => throw UnsupportedError(
      'Unsupported platform for opening files: ${Platform.operatingSystem}',
    ),
  };
}
