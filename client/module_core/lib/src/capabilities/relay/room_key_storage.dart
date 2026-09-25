import "dart:convert";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_persistence/sesori_persistence.dart";

import "../../foundation/persistence/persistence_keys.dart";
import "../../logging/logging.dart";

@lazySingleton
class RoomKeyStorage({required final SecureStorageRepository _storage}) {
  Future<Uint8List?> getRoomKey() async {
    try {
      final encoded = await _storage.read(key: CoreSecretKey.relayRoomKey);
      if (encoded == null) return null;
      return base64Url.decode(encoded);
    } catch (e) {
      loge("Failed to retrieve room key", e);
      return null;
    }
  }

  Future<void> saveRoomKey(Uint8List key) async {
    try {
      await _storage.write(key: CoreSecretKey.relayRoomKey, value: base64Url.encode(key));
    } catch (e) {
      loge("Failed to save room key", e);
      rethrow;
    }
  }

  Future<void> clearRoomKey() async {
    try {
      await _storage.delete(key: CoreSecretKey.relayRoomKey);
    } catch (e) {
      loge("Failed to clear room key", e);
      rethrow;
    }
  }
}
