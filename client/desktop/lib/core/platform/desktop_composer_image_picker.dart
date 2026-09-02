import "package:file_selector/file_selector.dart" as file_selector;
import "package:flutter/foundation.dart" show visibleForTesting;
import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

@visibleForTesting
typedef DesktopOpenImageFile = Future<file_selector.XFile?> Function({
  required List<file_selector.XTypeGroup> acceptedTypeGroups,
});

/// Desktop file picker for composer images.
@LazySingleton(as: ComposerImagePicker)
class DesktopComposerImagePicker.forTesting({
  required final DesktopOpenImageFile openFile,
}) implements ComposerImagePicker {
  static const _imageTypes = file_selector.XTypeGroup(
    label: "Images",
    extensions: ["bmp", "gif", "jpeg", "jpg", "png", "webp"],
  );

  final DesktopOpenImageFile _openFile = openFile;

  new() : this.forTesting(openFile: file_selector.openFile);

  @override
  Future<ComposerPickedImage?> pickImage() async {
    final file = await _openFile(acceptedTypeGroups: const [_imageTypes]);
    if (file == null) return null;
    return ComposerPickedImage(
      bytes: await file.readAsBytes(),
      filename: file.name,
    );
  }
}
