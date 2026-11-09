import "package:file_selector/file_selector.dart" as file_selector;
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@visibleForTesting
typedef OpenDocuments = Future<List<file_selector.XFile>> Function();

/// The system's document picker for any files, several at once. Each pick is
/// copied into the app's own storage, and the copies' paths are handed over
/// for shared core to route like any file on this device.
///
/// On iOS, file_selector copies every pick, and shared core turns away one over
/// the attachment budget without reading it. Android's picker
/// (`DocumentPickerService.kt`) checks each file's size first, so a large
/// video is never copied, and reports how many it left out.
@lazySingleton
class DocumentPickerClient.forTesting({required final OpenDocuments openFiles}) {
  static const _androidChannel = MethodChannel("com.sesori.app/document-picker");

  final OpenDocuments _openFiles = openFiles;

  new() : this.forTesting(openFiles: file_selector.openFiles);

  /// Returns `null` when the user dismisses the picker.
  Future<ComposerPickedHostPaths?> pick() async {
    if (defaultTargetPlatform == TargetPlatform.android) return _pickOnAndroid();
    final files = await _openFiles();
    if (files.isEmpty) return null;
    return ComposerPickedHostPaths(paths: [for (final file in files) file.path], oversizedCount: 0);
  }

  Future<ComposerPickedHostPaths?> _pickOnAndroid() async {
    final picked = await _androidChannel.invokeMapMethod<String, Object?>("pick", {
      "maxBytes": maxComposerPromptAttachmentBytes,
    });
    if (picked == null) return null;
    return switch (picked) {
      {"paths": final List<Object?> paths, "oversizedCount": final int oversizedCount} => ComposerPickedHostPaths(
        paths: paths.whereType<String>().toList(),
        oversizedCount: oversizedCount,
      ),
      _ => throw FormatException("Unexpected document picker result", picked),
    };
  }
}
