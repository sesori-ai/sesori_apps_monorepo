import "package:file_selector/file_selector.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/platform/desktop_composer_file_picker.dart";

void main() {
  test("adapter hands over every selected path without reading the files", () async {
    final picker = DesktopComposerFilePicker.forTesting(
      openFiles: () async => [XFile("/work/notes.dart"), XFile("/work/clip.mp4")],
    );

    final picked = await picker.pick(source: ComposerPickSource.files);

    expect(picked, isA<ComposerPickedHostPaths>());
    if (picked is! ComposerPickedHostPaths) return;
    expect(picked.paths, ["/work/notes.dart", "/work/clip.mp4"]);
    expect(picked.oversizedCount, 0);
  });

  test("adapter returns null when selection is dismissed", () async {
    final picker = DesktopComposerFilePicker.forTesting(openFiles: () async => const []);

    expect(await picker.pick(source: ComposerPickSource.files), isNull);
  });
}
