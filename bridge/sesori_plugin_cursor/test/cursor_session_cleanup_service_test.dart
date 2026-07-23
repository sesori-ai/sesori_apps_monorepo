import "dart:io";

import "package:cursor_plugin/cursor_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("CursorSessionCleanupService", () {
    late Directory tempDirectory;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp(
        "cursor-session-cleanup-test-",
      );
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    CursorSessionCleanupService buildService({
      required Map<String, String> environment,
    }) {
      return CursorSessionCleanupService(
        repository: CursorSessionStorageRepository(
          api: const CursorSessionStorageApi(),
        ),
        environment: environment,
      );
    }

    String sessionDirectory({required String configDirectory, required String sessionId}) {
      return p.join(configDirectory, "acp-sessions", sessionId);
    }

    Future<void> seedSession({
      required String configDirectory,
      required String sessionId,
    }) async {
      final file = File(
        p.join(
          sessionDirectory(
            configDirectory: configDirectory,
            sessionId: sessionId,
          ),
          "nested",
          "store.db",
        ),
      );
      await file.create(recursive: true);
      await file.writeAsString("stored session");
    }

    test("deletes only the requested session directory", () async {
      final configDirectory = p.join(tempDirectory.path, "config");
      await seedSession(
        configDirectory: configDirectory,
        sessionId: "deleted-session",
      );
      await seedSession(
        configDirectory: configDirectory,
        sessionId: "kept-session",
      );
      final service = buildService(
        environment: {"CURSOR_CONFIG_DIR": configDirectory},
      );

      await service.deletePersistedSession(
        backendSessionId: "deleted-session",
      );

      expect(
        Directory(
          sessionDirectory(
            configDirectory: configDirectory,
            sessionId: "deleted-session",
          ),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          sessionDirectory(
            configDirectory: configDirectory,
            sessionId: "kept-session",
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test("treats an already-missing session as success", () async {
      final service = buildService(
        environment: {
          "CURSOR_CONFIG_DIR": p.join(tempDirectory.path, "config"),
        },
      );

      await service.deletePersistedSession(
        backendSessionId: "missing-session",
      );
    });

    test("uses Cursor config-directory precedence", () async {
      final explicit = p.join(tempDirectory.path, "explicit");
      final xdg = p.join(tempDirectory.path, "xdg");
      final home = p.join(tempDirectory.path, "home");
      final xdgConfig = p.join(xdg, "cursor");
      final homeConfig = p.join(home, ".cursor");
      for (final configDirectory in [explicit, xdgConfig, homeConfig]) {
        await seedSession(
          configDirectory: configDirectory,
          sessionId: "session-1",
        );
      }
      final service = buildService(
        environment: {
          "CURSOR_CONFIG_DIR": explicit,
          "XDG_CONFIG_HOME": xdg,
          "HOME": home,
        },
      );

      await service.deletePersistedSession(backendSessionId: "session-1");

      expect(
        Directory(
          sessionDirectory(
            configDirectory: explicit,
            sessionId: "session-1",
          ),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          sessionDirectory(
            configDirectory: xdgConfig,
            sessionId: "session-1",
          ),
        ).existsSync(),
        isTrue,
      );
      expect(
        Directory(
          sessionDirectory(
            configDirectory: homeConfig,
            sessionId: "session-1",
          ),
        ).existsSync(),
        isTrue,
      );
    });

    test("falls back through XDG and the platform home", () async {
      final xdg = p.join(tempDirectory.path, "xdg");
      final home = p.join(tempDirectory.path, "home");
      await seedSession(
        configDirectory: p.join(xdg, "cursor"),
        sessionId: "xdg-session",
      );
      await seedSession(
        configDirectory: p.join(home, ".cursor"),
        sessionId: "home-session",
      );

      await buildService(
        environment: {"XDG_CONFIG_HOME": xdg, "HOME": home},
      ).deletePersistedSession(backendSessionId: "xdg-session");
      await buildService(
        environment: {"HOME": home},
      ).deletePersistedSession(backendSessionId: "home-session");

      expect(
        Directory(
          sessionDirectory(
            configDirectory: p.join(xdg, "cursor"),
            sessionId: "xdg-session",
          ),
        ).existsSync(),
        isFalse,
      );
      expect(
        Directory(
          sessionDirectory(
            configDirectory: p.join(home, ".cursor"),
            sessionId: "home-session",
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test("falls back to USERPROFILE when HOME is unavailable", () async {
      final profile = p.join(tempDirectory.path, "profile");
      await seedSession(
        configDirectory: p.join(profile, ".cursor"),
        sessionId: "windows-session",
      );

      await buildService(
        environment: {"USERPROFILE": profile},
      ).deletePersistedSession(backendSessionId: "windows-session");

      expect(
        Directory(
          sessionDirectory(
            configDirectory: p.join(profile, ".cursor"),
            sessionId: "windows-session",
          ),
        ).existsSync(),
        isFalse,
      );
    });

    test("rejects a non-directory entry at the session path", () async {
      final configDirectory = p.join(tempDirectory.path, "config");
      final sessionPath = sessionDirectory(
        configDirectory: configDirectory,
        sessionId: "session-file",
      );
      final file = File(sessionPath);
      await file.create(recursive: true);
      final service = buildService(
        environment: {"CURSOR_CONFIG_DIR": configDirectory},
      );

      await expectLater(
        service.deletePersistedSession(backendSessionId: "session-file"),
        throwsA(isA<FileSystemException>()),
      );
      expect(file.existsSync(), isTrue);
    });

    test("accepts a session directory removed during deletion", () async {
      final service = CursorSessionCleanupService(
        repository: _DisappearingSessionStorageRepository(),
        environment: {
          "CURSOR_CONFIG_DIR": p.join(tempDirectory.path, "config"),
        },
      );

      await service.deletePersistedSession(
        backendSessionId: "removed-session",
      );
    });

    test("rejects paths outside the session storage root", () async {
      final configDirectory = p.join(tempDirectory.path, "config");
      final outside = Directory(p.join(configDirectory, "outside"));
      await outside.create(recursive: true);
      final service = buildService(
        environment: {"CURSOR_CONFIG_DIR": configDirectory},
      );

      await expectLater(
        service.deletePersistedSession(backendSessionId: "../outside"),
        throwsArgumentError,
      );
      await expectLater(
        service.deletePersistedSession(
          backendSessionId: outside.absolute.path,
        ),
        throwsArgumentError,
      );
      expect(outside.existsSync(), isTrue);
    });
  });
}

class _DisappearingSessionStorageRepository implements CursorSessionStorageRepository {
  var _typeReads = 0;

  @override
  @override
  CursorSessionStorageEntryType entryType({required String path}) {
    return _typeReads++ == 0 ? CursorSessionStorageEntryType.directory : CursorSessionStorageEntryType.missing;
  }

  @override
  Future<void> deleteDirectory({required String path}) {
    throw FileSystemException("directory disappeared", path);
  }
}
