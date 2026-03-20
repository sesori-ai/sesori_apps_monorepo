import "dart:convert";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";

@lazySingleton
class RoomKeyStorage {
  static const _key = "relay_room_key";
  final SecureStorage _storage;

  RoomKeyStorage(SecureStorage storage) : _storage = storage;

  Future<Uint8List?> getRoomKey() async {
    try {
      final encoded = await _storage.read(key: _key);
      if (encoded == null) return null;
      return base64Url.decode(encoded);
    } catch (e) {
      loge("Failed to retrieve room key", e);
      return null;
    }
  }

  Future<void> saveRoomKey(Uint8List key) async {
    try {
      await _storage.write(key: _key, value: base64Url.encode(key));
    } catch (e) {
      loge("Failed to save room key", e);
      rethrow;
    }
  }

  Future<void> clearRoomKey() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      loge("Failed to clear room key", e);
      rethrow;
    }
  }
}
