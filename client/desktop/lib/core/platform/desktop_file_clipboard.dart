import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:pasteboard/pasteboard.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@visibleForTesting
typedef DesktopReadPasteboardFiles = Future<List<String>> Function();

@visibleForTesting
typedef DesktopReadPasteboardText = Future<String?> Function();

/// The files copied in Finder or Explorer, as paths on this computer.
///
/// On macOS the pasteboard reports a path for every URL it holds, so a copied
/// `https://example.com/` reads as the path `/`. When the clipboard's text is
/// a link to anything but a file, the copy was a link and no paths are
/// returned.
@LazySingleton(as: FileClipboard)
class DesktopFileClipboard.forTesting({
  required final DesktopReadPasteboardFiles readFiles,
  required final DesktopReadPasteboardText readText,
}) implements FileClipboard {
  final DesktopReadPasteboardFiles _readFiles = readFiles;
  final DesktopReadPasteboardText _readText = readText;

  new() : this.forTesting(readFiles: Pasteboard.files, readText: () => Pasteboard.text);

  @override
  Future<List<String>> readPaths() async {
    final paths = await _readFiles();
    if (paths.isEmpty) return paths;
    final text = await _readText();
    final link = text == null ? null : Uri.tryParse(text.trim());
    if (link != null && link.hasScheme && link.scheme != "file") return const [];
    return paths;
  }
}
