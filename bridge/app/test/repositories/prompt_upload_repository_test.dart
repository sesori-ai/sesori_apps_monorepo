import "dart:convert";
import "dart:io";

import "package:clock/clock.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:test/test.dart";

void main() {
  group("PromptUploadRepository", () {
    late Directory parent;
    late String uploadsRoot;
    late PromptUploadRepository repository;

    setUp(() {
      parent = Directory.systemTemp.createTempSync("prompt-upload-repository-");
      uploadsRoot = p.join(parent.path, "uploads");
      repository = PromptUploadRepository(filesystemApi: const FilesystemApi(), uploadsRoot: uploadsRoot);
    });

    tearDown(() => parent.delete(recursive: true));

    Future<String> save({required String sessionId, required String filename}) {
      return repository.save(sessionId: sessionId, bytes: [1, 2, 3], filename: filename);
    }

    List<String> childNames({required String path}) {
      return Directory(path).listSync().map((entry) => p.basename(entry.path)).toList()..sort();
    }

    group("save", () {
      test("writes each file in its own dated folder inside the session folder", () async {
        final first = await withClock(Clock.fixed(DateTime(2026, 11, 8, 23, 59)), () {
          return save(sessionId: "ses_1", filename: "report.pdf");
        });
        final second = await save(sessionId: "ses_1", filename: "report.pdf");

        expect(p.dirname(p.dirname(first)), p.join(uploadsRoot, "ses_1"));
        expect(p.basename(p.dirname(first)), startsWith("2026-11-08-"));
        expect(p.basename(first), "report.pdf");
        expect(File(first).readAsBytesSync(), [1, 2, 3]);
        expect(p.dirname(second), isNot(p.dirname(first)));
        expect(childNames(path: p.join(uploadsRoot, "ses_1")), hasLength(2));
      });

      test("keeps the root, the folders and the file owner-only", () async {
        final path = await save(sessionId: "ses_1", filename: "report.pdf");

        int mode(String path) => FileStat.statSync(path).mode & 0x1ff;
        expect(mode(uploadsRoot), 0x1c0);
        expect(mode(p.join(uploadsRoot, "ses_1")), 0x1c0);
        expect(mode(p.dirname(path)), 0x1c0);
        expect(mode(path), 0x180);
      }, testOn: "!windows");

      final sanitizedNames = {
        "../x": "x",
        r"a\b": "a_b",
        r"..\x": ".._x",
        ".": "attachment",
        "..": "attachment",
        "": "attachment",
        "dir/..": "attachment",
        "My Report.pdf": "My_Report.pdf",
        "tab\tnew\nline": "tab_new_line",
        "bell\u0007.txt": "bell_.txt",
        "a\"b'c`d*e?f<g>h|i:j.txt": "a_b_c_d_e_f_g_h_i_j.txt",
        "${"x" * 296}.pdf": "${"x" * 116}.pdf",
        "a.${"e" * 300}": "a.${"e" * 118}",
      };
      for (final MapEntry(key: filename, value: expected) in sanitizedNames.entries) {
        final description = filename.length > 40 ? "a ${filename.length}-character name" : jsonEncode(filename);
        test("sanitizes $description", () async {
          final path = await save(sessionId: "ses_1", filename: filename);

          expect(p.basename(path), expected);
          expect(p.dirname(p.dirname(path)), p.join(uploadsRoot, "ses_1"));
        });
      }

      test("keeps a capped name to whole characters", () async {
        final path = await save(sessionId: "ses_1", filename: "${"😀" * 200}.txt");

        expect(p.basename(path).runes, hasLength(120));
        expect(p.basename(path), endsWith("😀.txt"));
      });

      for (final sessionId in ["", ".", "..", "../ses_1", "a/b", r"a\b"]) {
        test("rejects the session id '$sessionId' before creating anything", () async {
          await expectLater(save(sessionId: sessionId, filename: "x.txt"), throwsStateError);

          expect(Directory(uploadsRoot).existsSync(), isFalse);
          expect(childNames(path: parent.path), isEmpty);
        });
      }

      test("removes the file's folder and rethrows when the write fails", () async {
        repository = PromptUploadRepository(filesystemApi: _FailingWriteFilesystemApi(), uploadsRoot: uploadsRoot);

        await expectLater(save(sessionId: "ses_1", filename: "x.txt"), throwsA(isA<FileSystemException>()));

        expect(childNames(path: p.join(uploadsRoot, "ses_1")), isEmpty);
      });
    });

    group("deleteSessions", () {
      test("removes the named sessions' folders and skips sessions without one", () async {
        await save(sessionId: "ses_1", filename: "a.txt");
        await save(sessionId: "ses_1", filename: "b.txt");
        await save(sessionId: "ses_2", filename: "c.txt");
        await save(sessionId: "ses_3", filename: "d.txt");

        await repository.deleteSessions(sessionIds: ["ses_1", "ses_2", "ses_none"]);

        expect(childNames(path: uploadsRoot), ["ses_3"]);
      });

      test("rejects an id that is not a single path segment", () async {
        await save(sessionId: "ses_1", filename: "a.txt");

        await expectLater(repository.deleteSessions(sessionIds: [".."]), throwsStateError);

        expect(childNames(path: uploadsRoot), ["ses_1"]);
      });
    });

    group("deleteFileFoldersDatedBefore", () {
      void createFolder({required String sessionId, required String name}) {
        final folder = Directory(p.join(uploadsRoot, sessionId, name))..createSync(recursive: true);
        File(p.join(folder.path, "file.txt")).writeAsStringSync("x");
      }

      test("removes only file folders dated before the cutoff day and keeps session folders", () async {
        createFolder(sessionId: "ses_1", name: "2026-10-31-old");
        createFolder(sessionId: "ses_1", name: "2026-11-01-cutoff-day");
        createFolder(sessionId: "ses_1", name: "2026-11-07-recent");
        createFolder(sessionId: "ses_1", name: "notes");
        createFolder(sessionId: "ses_1", name: "2026-1x-01-bad");
        createFolder(sessionId: "ses_2", name: "2025-01-01-old");

        await repository.deleteFileFoldersDatedBefore(cutoff: DateTime(2026, 11, 1, 12));

        expect(childNames(path: p.join(uploadsRoot, "ses_1")), [
          "2026-11-01-cutoff-day",
          "2026-11-07-recent",
          "2026-1x-01-bad",
          "notes",
        ]);
        expect(childNames(path: p.join(uploadsRoot, "ses_2")), isEmpty);
      });

      test("skips folders that something else removed meanwhile", () async {
        createFolder(sessionId: "ses_1", name: "2026-10-01-raced");
        createFolder(sessionId: "ses_1", name: "2026-10-02-old");
        createFolder(sessionId: "ses_2", name: "2026-10-03-raced-session");
        createFolder(sessionId: "ses_3", name: "2026-10-04-old");
        repository = PromptUploadRepository(
          filesystemApi: _RacingFilesystemApi(
            racedPaths: {
              p.join(uploadsRoot, "ses_1", "2026-10-01-raced"),
              p.join(uploadsRoot, "ses_2"),
            },
          ),
          uploadsRoot: uploadsRoot,
        );

        await repository.deleteFileFoldersDatedBefore(cutoff: DateTime(2026, 11));

        expect(childNames(path: uploadsRoot), ["ses_1", "ses_3"]);
        expect(childNames(path: p.join(uploadsRoot, "ses_1")), isEmpty);
        expect(childNames(path: p.join(uploadsRoot, "ses_3")), isEmpty);
      });
    });
  });
}

class _FailingWriteFilesystemApi() extends FilesystemApi {
  @override
  Future<void> writeOwnerOnlyFile({required String path, required List<int> bytes}) async {
    throw FileSystemException("No space left on device", path);
  }
}

/// Removes each of [_racedPaths] just before the repository lists or deletes
/// it, as a concurrent sweep or session delete would.
class _RacingFilesystemApi({required final Set<String> _racedPaths}) extends FilesystemApi {
  @override
  List<Directory> listDirectories({required String path}) {
    _race(path: path);
    return super.listDirectories(path: path);
  }

  @override
  Future<void> deleteDirectoryRecursivelyAsync({required String path}) {
    _race(path: path);
    return super.deleteDirectoryRecursivelyAsync(path: path);
  }

  void _race({required String path}) {
    if (_racedPaths.remove(path)) Directory(path).deleteSync(recursive: true);
  }
}
