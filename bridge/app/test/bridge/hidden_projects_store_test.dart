import "dart:io";

import "package:sesori_bridge/src/bridge/hidden_projects_store.dart";
import "package:test/test.dart";

void main() {
  group("HiddenProjectsStore", () {
    late Directory tempDir;
    late File file;
    late HiddenProjectsStore store;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("sesori_hidden_projects_store_");
      file = File("${tempDir.path}/hidden_projects.json");
      store = HiddenProjectsStore.withFile(file: file);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test("returns empty set when file is missing", () async {
      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });

    test("hide persists ids", () async {
      await store.hideProject(projectId: "project-1");

      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("hide is idempotent", () async {
      await store.hideProject(projectId: "project-1");
      await store.hideProject(projectId: "project-1");

      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("unhide removes project id", () async {
      await store.hideProject(projectId: "project-1");

      await store.unhideProject(projectId: "project-1");

      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });

    test("unhide is no-op for unknown id", () async {
      await store.hideProject(projectId: "project-1");

      await store.unhideProject(projectId: "project-2");

      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, equals({"project-1"}));
    });

    test("returns empty set for corrupted JSON", () async {
      await file.parent.create(recursive: true);
      await file.writeAsString("{this-is-not-json");

      final hiddenIds = await store.getHiddenProjectIds();
      expect(hiddenIds, isEmpty);
    });
  });
}
