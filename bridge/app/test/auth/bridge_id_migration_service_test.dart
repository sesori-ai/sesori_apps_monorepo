import "dart:io";

import "package:sesori_bridge/src/auth/bridge_id_migration_service.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late FakeBridgeIdStorage storage;
  late _RecordingLegacyReader legacyReader;

  BridgeIdMigrationService buildService() => BridgeIdMigrationService(
    bridgeIdStorage: storage,
    readLegacyBridgeId: legacyReader.read,
  );

  setUp(() {
    storage = FakeBridgeIdStorage();
    legacyReader = _RecordingLegacyReader();
  });

  test("copies a legacy bridge id into empty storage", () async {
    legacyReader.value = "br_legacy999";

    await buildService().migrate();

    expect(legacyReader.callCount, equals(1));
    expect(storage.bridgeId, equals("br_legacy999"));
  });

  test("is a no-op and never reads legacy when storage already holds an id", () async {
    storage.bridgeId = "br_existing1";
    legacyReader.value = "br_legacy999";

    await buildService().migrate();

    expect(legacyReader.callCount, equals(0));
    expect(storage.bridgeId, equals("br_existing1"));
  });

  test("leaves storage empty when there is no legacy id", () async {
    legacyReader.value = null;

    await buildService().migrate();

    expect(storage.bridgeId, isNull);
  });

  test("propagates a write failure so startup can retry before token.json is rewritten", () async {
    legacyReader.value = "br_legacy999";
    storage.writeError = const FileSystemException("disk full");

    await expectLater(buildService().migrate(), throwsA(isA<FileSystemException>()));
    // The legacy source is untouched, so a retry can still adopt it.
    expect(legacyReader.value, equals("br_legacy999"));
  });
}

class _RecordingLegacyReader {
  String? value;
  int callCount = 0;

  Future<String?> read() async {
    callCount += 1;
    return value;
  }
}
