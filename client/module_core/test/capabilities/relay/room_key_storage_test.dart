import "dart:convert";
import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/foundation/persistence/persistence_keys.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  late MockSecureStorageRepository mockStorage;
  late RoomKeyStorage roomKeyStorage;

  setUpAll(registerCoreFallbackValues);

  setUp(() {
    mockStorage = MockSecureStorageRepository();
    roomKeyStorage = RoomKeyStorage(storage: mockStorage);
  });

  group("RoomKeyStorage", () {
    test("saveRoomKey base64url-encodes and writes with correct key", () async {
      // given
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final encoded = base64Url.encode(key);
      when(() => mockStorage.write(key: CoreSecretKey.relayRoomKey, value: encoded)).thenAnswer((_) async {
        return;
      });

      // when
      await roomKeyStorage.saveRoomKey(key);

      // then
      verify(() => mockStorage.write(key: CoreSecretKey.relayRoomKey, value: encoded)).called(1);
    });

    test("getRoomKey reads and base64url-decodes correctly", () async {
      // given
      final key = Uint8List.fromList([
        0x00,
        0xFF,
        0x10,
        0xAB,
        0xCD,
        0xEF,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0A,
        0xF0,
        0xF1,
        0xF2,
        0xF3,
        0xF4,
        0xF5,
        0xF6,
        0xF7,
        0xF8,
        0xF9,
        0xFA,
        0xFB,
        0xFC,
        0xFD,
        0xFE,
        0xFF,
      ]);
      when(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).thenAnswer((_) async => base64Url.encode(key));

      // when
      final result = await roomKeyStorage.getRoomKey();

      // then
      verify(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).called(1);
      expect(result, equals(key));
    });

    test("getRoomKey returns null when storage returns null", () async {
      // given
      when(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).thenAnswer((_) async => null);

      // when
      final result = await roomKeyStorage.getRoomKey();

      // then
      verify(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).called(1);
      expect(result, isNull);
    });

    test("clearRoomKey deletes with correct key", () async {
      // given
      when(() => mockStorage.delete(key: CoreSecretKey.relayRoomKey)).thenAnswer((_) async {
        return;
      });

      // when
      await roomKeyStorage.clearRoomKey();

      // then
      verify(() => mockStorage.delete(key: CoreSecretKey.relayRoomKey)).called(1);
    });

    test("saveRoomKey rethrows on storage error", () async {
      // given
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final encoded = base64Url.encode(key);
      final error = Exception("write failed");
      when(() => mockStorage.write(key: CoreSecretKey.relayRoomKey, value: encoded)).thenThrow(error);

      // when/then
      await expectLater(roomKeyStorage.saveRoomKey(key), throwsA(same(error)));
      verify(() => mockStorage.write(key: CoreSecretKey.relayRoomKey, value: encoded)).called(1);
    });

    test("getRoomKey returns null on storage error", () async {
      // given
      when(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).thenThrow(Exception("read failed"));

      // when
      final result = await roomKeyStorage.getRoomKey();

      // then
      verify(() => mockStorage.read(key: CoreSecretKey.relayRoomKey)).called(1);
      expect(result, isNull);
    });
  });
}
