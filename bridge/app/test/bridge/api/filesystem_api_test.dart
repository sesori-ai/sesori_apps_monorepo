import "dart:io";

import "package:path/path.dart" as p;
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

  test("owner-only directory creation makes missing parents and hardens the directory", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));
    final target = p.join(directory.path, "a", "b");

    await const FilesystemApi().createOwnerOnlyDirectory(path: target);

    expect(Directory(target).existsSync(), isTrue);
    expect(_mode(path: target), 0x1c0);
  }, testOn: "!windows");

  test("owner-only directory creation hardens a directory that already exists", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));
    final target = p.join(directory.path, "existing");
    await Directory(target).create();
    await Process.run("chmod", ["755", target]);

    await const FilesystemApi().createOwnerOnlyDirectory(path: target);

    expect(_mode(path: target), 0x1c0);
  }, testOn: "!windows");

  test("owner-only temporary directory creation names it with the prefix and hardens it", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));

    final created = await const FilesystemApi().createOwnerOnlyTemporaryDirectory(
      parent: directory.path,
      prefix: "2026-11-08-",
    );

    expect(p.dirname(created), directory.path);
    expect(p.basename(created), startsWith("2026-11-08-"));
    expect(Directory(created).existsSync(), isTrue);
    expect(_mode(path: created), 0x1c0);
  }, testOn: "!windows");

  test("owner-only file writes store the bytes in a file only the user can open", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));
    final target = p.join(directory.path, "file.bin");

    await const FilesystemApi().writeOwnerOnlyFile(path: target, bytes: [1, 2, 3]);

    expect(File(target).readAsBytesSync(), [1, 2, 3]);
    expect(_mode(path: target), 0x180);
  }, testOn: "!windows");

  test("async directory listing returns only the immediate child directories", () async {
    final directory = await Directory.systemTemp.createTemp("filesystem_api_test");
    addTearDown(() => directory.delete(recursive: true));
    await Directory(p.join(directory.path, "a", "nested")).create(recursive: true);
    await File(p.join(directory.path, "file.txt")).writeAsString("x");

    final directories = await const FilesystemApi().listDirectoriesAsync(path: directory.path);

    expect(directories.map((entry) => entry.path), [p.join(directory.path, "a")]);
  });
}

int _mode({required String path}) => FileStat.statSync(path).mode & 0x1ff;
