import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("CodexProjectStorage", () {
    late Directory codexHome;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-store-");
    });

    tearDown(() {
      try {
        codexHome.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    });

    CodexProjectStorage storageFor(Map<String, String> env) =>
        CodexProjectStorage(environment: env);

    test(r"codexHome resolves $CODEX_HOME, then $HOME/.codex, else null", () {
      expect(
        storageFor({"CODEX_HOME": "/explicit/home"}).codexHome,
        equals("/explicit/home"),
      );
      expect(
        storageFor({"HOME": "/users/me"}).codexHome,
        equals(p.join("/users/me", ".codex")),
      );
      expect(storageFor(const {}).codexHome, isNull);
    });

    test("reads are empty and writes are no-ops when CODEX_HOME is unresolvable", () {
      final storage = storageFor(const {});
      expect(storage.filePath, isNull);
      expect(storage.listOpenedProjects(), isEmpty);
      // Must not throw even though there is nowhere to persist.
      expect(() => storage.upsertProject(path: "/x"), returnsNormally);
    });

    test("listOpenedProjects is empty when the file does not exist", () {
      expect(storageFor({"CODEX_HOME": codexHome.path}).listOpenedProjects(), isEmpty);
    });

    test("upsertProject persists a path with a positive addedAt", () {
      final storage = storageFor({"CODEX_HOME": codexHome.path});
      storage.upsertProject(path: "/work/alpha");

      final projects = storage.listOpenedProjects();
      expect(projects, hasLength(1));
      expect(projects.single.path, equals("/work/alpha"));
      expect(projects.single.name, isNull);
      expect(projects.single.addedAt, greaterThan(0));
    });

    test("re-upserting a path preserves its addedAt and applies a later name", () {
      final storage = storageFor({"CODEX_HOME": codexHome.path});
      storage.upsertProject(path: "/work/alpha");
      final firstAddedAt = storage.listOpenedProjects().single.addedAt;

      // Name-only update keeps the original timestamp.
      storage.upsertProject(path: "/work/alpha", name: "Alpha");
      final afterName = storage.listOpenedProjects().single;
      expect(afterName.addedAt, equals(firstAddedAt));
      expect(afterName.name, equals("Alpha"));

      // A subsequent null-name upsert leaves the existing name intact.
      storage.upsertProject(path: "/work/alpha");
      expect(storage.listOpenedProjects().single.name, equals("Alpha"));
    });

    test("malformed JSON degrades to an empty list", () {
      File(p.join(codexHome.path, "sesori_projects.json"))
          .writeAsStringSync("{ this is not valid json");
      expect(storageFor({"CODEX_HOME": codexHome.path}).listOpenedProjects(), isEmpty);
    });

    test("entries with no usable path are skipped", () {
      File(p.join(codexHome.path, "sesori_projects.json")).writeAsStringSync(
        '[{"name":"orphan"},{"path":"","addedAt":1},{"path":"/ok","addedAt":2}]',
      );
      final projects = storageFor({"CODEX_HOME": codexHome.path}).listOpenedProjects();
      expect(projects.map((e) => e.path).toList(), equals(["/ok"]));
    });

    test("persists across separate storage instances (survives restart)", () {
      storageFor({"CODEX_HOME": codexHome.path})
          .upsertProject(path: "/work/beta", name: "Beta");

      final reopened = storageFor({"CODEX_HOME": codexHome.path}).listOpenedProjects();
      expect(reopened, hasLength(1));
      expect(reopened.single.path, equals("/work/beta"));
      expect(reopened.single.name, equals("Beta"));
    });
  });
}
