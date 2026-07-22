import "dart:io";

import "package:sesori_bridge/src/bridge/api/filesystem_api.dart";
import "package:sesori_bridge/src/bridge/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/bridge/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/bridge/routing/create_directory_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  group("CreateDirectoryHandler", () {
    late CreateDirectoryHandler handler;
    late Directory tempDir;

    Future<FilesystemSuggestion> create({required String parentPath, required String name}) {
      return handler.handle(
        makeRequest("POST", "/filesystem/directory"),
        body: FilesystemCreateDirectoryRequest(parentPath: parentPath, name: name),
        pathParams: {},
        queryParams: {},
        fragment: null,
      );
    }

    Matcher throwsStatus(int status) =>
        throwsA(isA<RelayResponse>().having((r) => r.status, "status", equals(status)));

    setUp(() async {
      handler = CreateDirectoryHandler(
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
        ),
      );
      tempDir = await Directory.systemTemp.createTemp("create-directory-handler-test-");
    });

    tearDown(() async {
      if (tempDir.existsSync()) await tempDir.delete(recursive: true);
    });

    test("canHandle POST /filesystem/directory", () {
      expect(handler.canHandle(makeRequest("POST", "/filesystem/directory")), isTrue);
    });

    test("creates the folder and returns it as a browser entry", () async {
      final result = await create(parentPath: tempDir.path, name: "new-app");

      expect(Directory("${tempDir.path}/new-app").existsSync(), isTrue);
      expect(result.path, equals("${tempDir.path}/new-app"));
      expect(result.name, equals("new-app"));
      // Only the directory was made — no git setup, no project registration.
      expect(Directory("${tempDir.path}/new-app/.git").existsSync(), isFalse);
      expect(result.isGitRepo, isFalse);
    });

    test("trims surrounding whitespace from the name", () async {
      final result = await create(parentPath: tempDir.path, name: "  spaced  ");

      expect(result.name, equals("spaced"));
      expect(Directory("${tempDir.path}/spaced").existsSync(), isTrue);
    });

    test("a name that would escape the parent is rejected", () async {
      // The name is one segment, so neither a separator nor a walk-up may
      // place the folder outside the parent the client is browsing.
      for (final name in ["nested/child", r"nested\child", "..", "."]) {
        await expectLater(() => create(parentPath: tempDir.path, name: name), throwsStatus(400));
      }
      expect(tempDir.listSync(), isEmpty);
    });

    test("empty name or parent returns 400", () async {
      await expectLater(() => create(parentPath: tempDir.path, name: "   "), throwsStatus(400));
      await expectLater(() => create(parentPath: "", name: "app"), throwsStatus(400));
    });

    test("relative or traversing parent returns 400", () async {
      await expectLater(() => create(parentPath: "relative/dir", name: "app"), throwsStatus(400));
      await expectLater(() => create(parentPath: "${tempDir.path}/../x", name: "app"), throwsStatus(400));
    });

    test("existing folder returns 409", () async {
      Directory("${tempDir.path}/taken").createSync();

      await expectLater(() => create(parentPath: tempDir.path, name: "taken"), throwsStatus(409));
    });

    test("missing parent returns 400", () async {
      await expectLater(
        () => create(parentPath: "${tempDir.path}/absent", name: "app"),
        throwsStatus(400),
      );
    });
  });
}
