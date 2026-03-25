import "dart:io";

import "package:sesori_bridge/src/bridge/routing/close_project_handler.dart";
import "package:sesori_bridge/src/bridge/routing/hidden_projects_store.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("CloseProjectHandler", () {
    late Directory tempDir;
    late HiddenProjectsStore store;
    late CloseProjectHandler handler;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("sesori_close_project_handler_");
      store = HiddenProjectsStore.withFile(file: File("${tempDir.path}/hidden_projects.json"));
      handler = CloseProjectHandler(store);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test("canHandle DELETE /project/:id", () {
      expect(handler.canHandle(makeRequest("DELETE", "/project/p1")), isTrue);
    });

    test("returns 200 and stores hidden project id", () async {
      final response = await handler.handle(
        makeRequest("DELETE", "/project/p1"),
        pathParams: {"id": "p1"},
        queryParams: {},
      );

      final hiddenIds = await store.getHiddenProjectIds();
      expect(response.status, equals(200));
      expect(hiddenIds, contains("p1"));
    });

    test("returns 400 when project id is missing", () async {
      final response = await handler.handle(
        makeRequest("DELETE", "/project/"),
        pathParams: {},
        queryParams: {},
      );

      expect(response.status, equals(400));
      expect(response.body, contains("missing project id"));
    });
  });
}
