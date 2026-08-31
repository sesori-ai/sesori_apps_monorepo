import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  group("BridgeProcessLogStorage", () {
    late Directory root;
    late _FixedApplicationSupportDirectory applicationSupportDirectory;

    setUp(() {
      root = Directory.systemTemp.createTempSync("sesori_bridge_logs_");
      applicationSupportDirectory = _FixedApplicationSupportDirectory(directory: root);
    });

    tearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test("prepares an empty active log before any helper output exists", () async {
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: 12,
        isWindows: true,
        setPermissions: _noOpPermissionSetter,
      );

      final File current = File(await storage.logFilePath);

      expect(current.existsSync(), isTrue);
      expect(current.readAsStringSync(), isEmpty);
    });

    test("appends under desktop app data and rotates before the size cap", () async {
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: 12,
        isWindows: true,
        setPermissions: _noOpPermissionSetter,
      );

      await storage.appendLine(line: "first");
      await storage.appendLine(line: "second");

      final File current = File(await storage.logFilePath);
      final File rotated = File(path.join(root.path, "logs", "bridge.log.1"));
      expect(await current.readAsString(), "second\n");
      expect(await rotated.readAsString(), "first\n");
      expect(await current.length(), lessThanOrEqualTo(12));
      expect(await rotated.length(), lessThanOrEqualTo(12));
    });

    test("one oversized line is UTF-8 valid and remains within the cap", () async {
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: 8,
        isWindows: true,
        setPermissions: _noOpPermissionSetter,
      );

      await storage.appendLine(line: "prefix-🙂🙂");

      final File current = File(await storage.logFilePath);
      expect(await current.length(), lessThanOrEqualTo(8));
      expect(await current.readAsString(), "🙂\n");
    });

    test("hardens the POSIX directory and files, including rotation replacements", () async {
      final List<(String, String)> permissions = <(String, String)>[];
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: 8,
        isWindows: false,
        setPermissions: ({required String path, required String mode}) async {
          permissions.add((path, mode));
        },
      );

      await storage.appendLine(line: "first");
      await storage.appendLine(line: "second");

      expect(permissions.where((entry) => entry.$2 == "700"), hasLength(1));
      expect(permissions.where((entry) => entry.$2 == "600"), hasLength(3));
      expect(permissions.any((entry) => entry.$1.endsWith("bridge.log.1") && entry.$2 == "600"), isTrue);
    });

    test("a failed initialization is surfaced and the next append retries", () async {
      int permissionCalls = 0;
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        maxFileBytes: 100,
        isWindows: false,
        setPermissions: ({required String path, required String mode}) async {
          permissionCalls++;
          if (permissionCalls == 1) {
            throw const FileSystemException("read-only");
          }
        },
      );

      await expectLater(storage.appendLine(line: "first"), throwsA(isA<FileSystemException>()));
      await storage.appendLine(line: "second");

      expect(await File(await storage.logFilePath).readAsString(), "second\n");
      expect(permissionCalls, greaterThanOrEqualTo(3));
    });

    test("production POSIX permission setter creates owner-only paths", () async {
      if (Platform.isWindows) {
        return;
      }
      final BridgeProcessLogStorage storage = BridgeProcessLogStorage(
        applicationSupportDirectory: applicationSupportDirectory,
      );

      await storage.appendLine(line: "private");

      final File file = File(await storage.logFilePath);
      final Directory directory = file.parent;
      expect(directory.statSync().mode & 0x1FF, 0x1C0);
      expect(file.statSync().mode & 0x1FF, 0x180);
    });
  });
}

Future<void> _noOpPermissionSetter({required String path, required String mode}) async {}

class _FixedApplicationSupportDirectory({required final Directory directory})
    implements DesktopApplicationSupportDirectory {
  @override
  Future<Directory> resolve() async => directory;
}
