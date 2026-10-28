import "dart:io";

import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/routing/read_file_preview_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/test_drive_roots_api.dart";
import "routing_test_helpers.dart";

void main() {
  group("ReadFilePreviewHandler", () {
    late Directory tempDir;
    late ReadFilePreviewHandler handler;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync("sesori_preview_handler_");
      handler = ReadFilePreviewHandler(
        filesystemRepository: FilesystemRepository(
          filesystemApi: const FilesystemApi(),
          permissionValidator: const FilesystemPermissionValidator(),
          driveRootsApi: windowsDriveRootsApi,
        ),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    Future<FilePreviewResponse> read(String path) {
      return handler.handle(makeRequest("POST", "/filesystem/file"), body: FilePreviewRequest(path: path));
    }

    test("handles only POST /filesystem/file", () {
      expect(handler.canHandle(makeRequest("POST", "/filesystem/file")), isTrue);
      expect(handler.canHandle(makeRequest("GET", "/filesystem/file")), isFalse);
    });

    test("returns the repository's preview", () async {
      File("${tempDir.path}/main.dart").writeAsStringSync("void main() {}");

      expect(await read("${tempDir.path}/main.dart"), const FilePreviewResponse.text(content: "void main() {}"));
      expect(await read("${tempDir.path}/absent.dart"), const FilePreviewResponse.missing());
    });

    test("rejects a relative path or a parent segment with 400", () async {
      for (final path in ["src/main.dart", "${tempDir.path}/../main.dart"]) {
        await expectLater(
          () => read(path),
          throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
          reason: path,
        );
      }
    });
  });
}
