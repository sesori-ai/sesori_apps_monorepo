import "dart:io";

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/scratch_repository.dart";
import "package:test/test.dart";

import "../helpers/test_database.dart";

void main() {
  group("ScratchRepository", () {
    late AppDatabase db;
    late Directory parent;
    late String scratchRoot;
    late ScratchRepository repository;

    setUp(() {
      db = createTestDatabase();
      parent = Directory.systemTemp.createTempSync("scratch-repository-");
      scratchRoot = p.join(parent.path, "scratch");
      repository = testScratchRepository(sessionDao: db.sessionDao, scratchRoot: scratchRoot);
    });

    tearDown(() async {
      await db.close();
      await parent.delete(recursive: true);
    });

    Directory sessionFolder({required String name}) {
      final folder = Directory(p.join(scratchRoot, name))..createSync(recursive: true);
      File(p.join(folder.path, "notes.txt")).writeAsStringSync("draft");
      return folder;
    }

    group("createSessionDirectory", () {
      test("creates the missing root and a dated folder directly in it", () async {
        final path = await withClock(
          Clock.fixed(DateTime(2026, 3, 7, 23, 59)),
          () => repository.createSessionDirectory(),
        );

        expect(Directory(path).existsSync(), isTrue);
        expect(p.dirname(path), scratchRoot);
        expect(p.basename(path), matches(RegExp(r"^2026-03-07-.+$")));
      });

      test("gives every call its own folder", () async {
        final first = await repository.createSessionDirectory();
        final second = await repository.createSessionDirectory();

        expect(second, isNot(first));
        expect(Directory(scratchRoot).listSync().whereType<Directory>(), hasLength(2));
      });
    });

    group("deleteSessionDirectoryIfUnused", () {
      test("deletes an unused session folder and everything in it", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        Directory(p.join(folder.path, "src", "lib")).createSync(recursive: true);
        File(p.join(folder.path, "src", "lib", "main.dart")).writeAsStringSync("void main() {}");

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(folder.existsSync(), isFalse);
        expect(Directory(scratchRoot).existsSync(), isTrue);
      });

      test("removes a link inside the folder without following it", () async {
        final outside = Directory(p.join(parent.path, "outside"))..createSync();
        File(p.join(outside.path, "keep.txt")).writeAsStringSync("keep me");
        final folder = sessionFolder(name: "2026-10-25-abc");
        Link(p.join(folder.path, "outside-link")).createSync(outside.path);

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(folder.existsSync(), isFalse);
        expect(File(p.join(outside.path, "keep.txt")).readAsStringSync(), "keep me");
      });

      test("keeps a folder that another session row still uses", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        await insertTestSessionInDirectory(
          db: db,
          sessionId: "sibling",
          projectId: scratchRoot,
          directory: folder.path,
        );

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(File(p.join(folder.path, "notes.txt")).existsSync(), isTrue);
      });

      test("keeps a folder that another session row stores in a different spelling", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        await insertTestSessionInDirectory(
          db: db,
          sessionId: "sibling",
          projectId: scratchRoot,
          directory: p.join(folder.path, ".", "src", ".."),
        );

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(File(p.join(folder.path, "notes.txt")).existsSync(), isTrue);
      });

      test("keeps a folder that contains another session row's directory", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        await insertTestSessionInDirectory(
          db: db,
          sessionId: "child",
          projectId: scratchRoot,
          directory: p.join(folder.path, "packages", "app"),
        );

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(File(p.join(folder.path, "notes.txt")).existsSync(), isTrue);
      });

      test("deletes the folder when other rows only use a folder whose name it prefixes", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        final neighbour = sessionFolder(name: "2026-10-25-abcd");
        await insertTestSessionInDirectory(
          db: db,
          sessionId: "neighbour",
          projectId: scratchRoot,
          directory: neighbour.path,
        );

        await repository.deleteSessionDirectoryIfUnused(path: folder.path);

        expect(folder.existsSync(), isFalse);
        expect(neighbour.existsSync(), isTrue);
      });

      test("keeps the scratch root itself", () async {
        sessionFolder(name: "2026-10-25-abc");

        await repository.deleteSessionDirectoryIfUnused(path: scratchRoot);

        expect(File(p.join(scratchRoot, "2026-10-25-abc", "notes.txt")).existsSync(), isTrue);
      });

      test("keeps a folder outside the scratch root", () async {
        final outside = Directory(p.join(parent.path, "project"))..createSync();
        File(p.join(outside.path, "main.dart")).writeAsStringSync("void main() {}");

        await repository.deleteSessionDirectoryIfUnused(path: outside.path);

        expect(File(p.join(outside.path, "main.dart")).existsSync(), isTrue);
      });

      test("keeps a folder in a sibling whose name the scratch root prefixes", () async {
        final sibling = Directory(p.join(parent.path, "scratch-other", "2026-10-25-abc"))..createSync(recursive: true);

        await repository.deleteSessionDirectoryIfUnused(path: sibling.path);

        expect(sibling.existsSync(), isTrue);
      });

      test("keeps a folder nested below a session folder", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        final nested = Directory(p.join(folder.path, "src"))..createSync();

        await repository.deleteSessionDirectoryIfUnused(path: nested.path);

        expect(nested.existsSync(), isTrue);
      });

      test("keeps a path spelled with dot-dot segments", () async {
        final folder = sessionFolder(name: "2026-10-25-abc");
        sessionFolder(name: "2026-10-25-def");

        await repository.deleteSessionDirectoryIfUnused(
          path: p.join(scratchRoot, "2026-10-25-def", "..", "2026-10-25-abc"),
        );
        await repository.deleteSessionDirectoryIfUnused(path: p.join(scratchRoot, "..", "scratch", "2026-10-25-abc"));

        expect(File(p.join(folder.path, "notes.txt")).existsSync(), isTrue);
      });

      test("keeps a link in the scratch root and the folder it points to", () async {
        final target = Directory(p.join(parent.path, "project"))..createSync();
        File(p.join(target.path, "main.dart")).writeAsStringSync("void main() {}");
        Directory(scratchRoot).createSync();
        final link = Link(p.join(scratchRoot, "2026-10-25-link"))..createSync(target.path);

        await repository.deleteSessionDirectoryIfUnused(path: link.path);

        expect(link.existsSync(), isTrue);
        expect(File(p.join(target.path, "main.dart")).existsSync(), isTrue);
      });

      test("keeps a file in the scratch root", () async {
        Directory(scratchRoot).createSync();
        final file = File(p.join(scratchRoot, "2026-10-25-file"))..writeAsStringSync("not a folder");

        await repository.deleteSessionDirectoryIfUnused(path: file.path);

        expect(file.existsSync(), isTrue);
      });

      test("completes when the folder is already gone", () async {
        Directory(scratchRoot).createSync();

        await repository.deleteSessionDirectoryIfUnused(path: p.join(scratchRoot, "2026-10-25-gone"));
      });
    });
  });
}
