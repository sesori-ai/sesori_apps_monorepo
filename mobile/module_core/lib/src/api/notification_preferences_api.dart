import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

@lazySingleton
class NotificationPreferencesApi {
  final SecureStorage _storage;

  NotificationPreferencesApi({required SecureStorage storage}) : _storage = storage;

  Future<String?> readValue({required String key}) {
    return _storage.read(key: key);
  }

  Future<void> writeValue({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  Future<void> deleteValue({required String key}) {
    return _storage.delete(key: key);
  }
}
