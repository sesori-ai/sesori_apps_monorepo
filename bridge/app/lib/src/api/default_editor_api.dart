import 'dart:io';

import 'linux_default_editor_api.dart';
import 'macos_default_editor_api.dart';
import 'windows_default_editor_api.dart';

abstract class DefaultEditorApi {
  Future<void> openFile(String filePath);

  static DefaultEditorApi forPlatform() {
    return switch (Platform.operatingSystem) {
      'macos' => MacosDefaultEditorApi(runProcess: Process.run),
      'linux' => LinuxDefaultEditorApi(runProcess: Process.run),
      'windows' => WindowsDefaultEditorApi(runProcess: Process.run),
      _ => throw UnsupportedError(
        'Unsupported platform for opening files: ${Platform.operatingSystem}',
      ),
    };
  }
}
