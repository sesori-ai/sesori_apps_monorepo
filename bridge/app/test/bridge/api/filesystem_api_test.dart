import "dart:io";

import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:test/test.dart";

void main() {
  test("bounded entry enumeration stops at the requested maximum", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));
    for (final name in ["a", "b", "c"]) {
      await File("${directory.path}/$name").writeAsString(name);
    }

    final names = await const FilesystemApi().listEntryNamesBounded(
      path: directory.path,
      maximumEntries: 2,
    );

    expect(names, hasLength(2));
    expect(names.toSet().difference({"a", "b", "c"}), isEmpty);
  });

  test("bounded entry enumeration rejects a non-positive maximum", () async {
    await expectLater(
      () => const FilesystemApi().listEntryNamesBounded(path: "/unused", maximumEntries: 0),
      throwsArgumentError,
    );
  });
}
