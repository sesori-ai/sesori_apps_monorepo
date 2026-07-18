import "dart:io";

import "package:path/path.dart" as path;
import "package:sesori_bridge/src/api/app_onboarding_state_storage.dart";
import "package:test/test.dart";

void main() {
  group("AppOnboardingStateStorage", () {
    late Directory temporaryDirectory;
    late String markerDirectory;
    late AppOnboardingStateStorage storage;

    setUp(() async {
      temporaryDirectory = await Directory.systemTemp.createTemp("sesori-onboarding-storage-");
      markerDirectory = path.join(temporaryDirectory.path, "markers");
      storage = AppOnboardingStateStorage(directoryPath: markerDirectory);
    });

    tearDown(() {
      if (temporaryDirectory.existsSync()) {
        temporaryDirectory.deleteSync(recursive: true);
      }
    });

    test("writes an empty marker idempotently and clears the marker directory", () async {
      const key = "aabbcc";

      expect(await storage.markerExists(key: key), isFalse);
      await storage.writeMarker(key: key);
      await storage.writeMarker(key: key);

      final marker = File(path.join(markerDirectory, key));
      expect(await storage.markerExists(key: key), isTrue);
      expect(marker.readAsStringSync(), isEmpty);

      await storage.clearAll();

      expect(Directory(markerDirectory).existsSync(), isFalse);
      await storage.clearAll();
    });

    test("restricts the marker directory and files on Unix", () async {
      if (Platform.isWindows) return;

      const key = "ddeeff";
      await storage.writeMarker(key: key);

      final directoryMode = FileStat.statSync(markerDirectory).mode & 0x1ff;
      final markerMode = FileStat.statSync(path.join(markerDirectory, key)).mode & 0x1ff;
      expect(directoryMode, equals(0x1c0));
      expect(markerMode, equals(0x180));
    });
  });
}
