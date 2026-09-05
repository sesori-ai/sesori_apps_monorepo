import "dart:io";
import "dart:typed_data";

import "package:path/path.dart" as path;
import "package:sesori_dart_core/src/foundation/io/file_attachment_thumbnail_storage.dart";
import "package:sesori_dart_core/src/foundation/io/temporary_directory_client.dart";
import "package:sesori_dart_core/src/foundation/platform/temporary_directory_provider.dart";
import "package:test/test.dart";

class _FixedTemporaryDirectoryProvider({required final Directory _directory}) implements TemporaryDirectoryProvider {
  @override
  Future<Directory> temporaryDirectory() async => _directory;
}

void main() {
  late Directory temporaryDirectory;
  late FileAttachmentThumbnailStorage storage;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp("sesori-thumbnail-storage-");
    storage = FileAttachmentThumbnailStorage(
      temporaryDirectoryClient: TemporaryDirectoryClient(
        provider: _FixedTemporaryDirectoryProvider(directory: temporaryDirectory),
      ),
    );
  });

  tearDown(() async {
    try {
      await temporaryDirectory.delete(recursive: true);
    } on PathNotFoundException {
      // A test may already have removed its complete temporary scope.
    }
  });

  Directory scopeDirectory(String scope) => Directory("${temporaryDirectory.path}/attachment_thumbnails/$scope");

  Future<bool> hasTemporaryFiles(Directory directory) =>
      directory.list().any((entity) => entity is File && path.basename(entity.path).startsWith(".tmp-"));

  test("writes atomically, reads bytes, and lists file metadata", () async {
    final bytes = Uint8List.fromList(const [1, 2, 3]);

    await storage.write(scope: "account", key: "thumbnail", bytes: bytes);

    expect(await storage.read(scope: "account", key: "thumbnail"), bytes);
    final file = File("${scopeDirectory("account").path}/thumbnail");
    expect(file.existsSync(), isTrue);
    final metadata = await storage.listMetadata(scope: "account");
    expect(metadata, hasLength(1));
    expect(metadata.single.key, "thumbnail");
    expect(metadata.single.sizeBytes, bytes.length);
    expect(metadata.single.modifiedAt, file.statSync().modified);
  });

  test("missing reads and deletes are benign", () async {
    expect(await storage.read(scope: "missing", key: "thumbnail"), isNull);
    await storage.delete(scope: "missing", key: "thumbnail");
    await storage.deleteScope(scope: "missing");
    expect(await storage.listMetadata(scope: "missing"), isEmpty);
  });

  test("metadata listing ignores temporary files and leaves them in place", () async {
    final directory = scopeDirectory("account");
    await directory.create(recursive: true);
    final temporaryFile = File(path.join(directory.path, ".tmp-interrupted"));
    await temporaryFile.writeAsBytes(const [1, 2, 3]);

    expect(await storage.listMetadata(scope: "account"), isEmpty);
    expect(temporaryFile.existsSync(), isTrue);
  });

  test("deletes one entry or its complete scope", () async {
    await storage.write(scope: "first", key: "one", bytes: Uint8List.fromList(const [1]));
    await storage.write(scope: "first", key: "two", bytes: Uint8List.fromList(const [2]));
    await storage.write(scope: "second", key: "one", bytes: Uint8List.fromList(const [3]));

    await storage.delete(scope: "first", key: "one");
    expect(await storage.read(scope: "first", key: "one"), isNull);
    expect(await storage.read(scope: "first", key: "two"), isNotNull);

    await storage.deleteScope(scope: "first");
    expect(await storage.listMetadata(scope: "first"), isEmpty);
    expect(await storage.read(scope: "second", key: "one"), isNotNull);
  });

  test("rejects unsafe scope and key segments", () async {
    for (final segment in ["", ".", "..", "nested/path", r"nested\path"]) {
      await expectLater(storage.read(scope: segment, key: "thumbnail"), throwsArgumentError);
      await expectLater(storage.read(scope: "account", key: segment), throwsArgumentError);
    }
  });

  test("concurrent writes to the same file use separate temporary files", () async {
    final firstBytes = Uint8List.fromList(const [1]);
    final secondBytes = Uint8List.fromList(const [2]);
    await Future.wait([
      storage.write(scope: "account", key: "thumbnail", bytes: firstBytes),
      storage.write(scope: "account", key: "thumbnail", bytes: secondBytes),
    ]);

    expect(await storage.read(scope: "account", key: "thumbnail"), anyOf(equals(firstBytes), equals(secondBytes)));
    expect(await hasTemporaryFiles(scopeDirectory("account")), isFalse);
  });

  test("replaces an existing file and cleans its temporary file when replacement fails", () async {
    await storage.write(scope: "account", key: "thumbnail", bytes: Uint8List.fromList(const [1]));
    await storage.write(scope: "account", key: "thumbnail", bytes: Uint8List.fromList(const [2, 3]));
    expect(await storage.read(scope: "account", key: "thumbnail"), Uint8List.fromList(const [2, 3]));

    final target = Directory("${scopeDirectory("account").path}/failing");
    await target.create();
    await expectLater(
      storage.write(scope: "account", key: "failing", bytes: Uint8List.fromList(const [1, 2, 3])),
      throwsA(isA<FileSystemException>()),
    );
    expect(await hasTemporaryFiles(target.parent), isFalse);
  });
}
