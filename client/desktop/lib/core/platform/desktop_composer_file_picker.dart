import "package:file_selector/file_selector.dart" as file_selector;
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@visibleForTesting
typedef DesktopOpenFiles = Future<List<file_selector.XFile>> Function();

/// Desktop file picker for the composer: any files, several at once.
///
/// It hands over paths only. Shared core decides which become image
/// attachments and which are inserted as paths, and reads only what it stages.
@LazySingleton(as: ComposerFilePicker)
class DesktopComposerFilePicker.forTesting({
  required final DesktopOpenFiles openFiles,
}) implements ComposerFilePicker {
  final DesktopOpenFiles _openFiles = openFiles;

  new() : this.forTesting(openFiles: file_selector.openFiles);

  @override
  Future<ComposerPickResult?> pick() async {
    final files = await _openFiles();
    if (files.isEmpty) return null;
    return ComposerPickedHostPaths(paths: [for (final file in files) file.path]);
  }
}
