import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

@lazySingleton
class NotificationPreferencesApi {
  final SecureStorage _storage;

  NotificationPreferencesApi({required SecureStorage storage}) : _storage = storage;

  Future<bool?> readValue({required NotificationCategory category}) {
    return _storage.read(key: category.storageKey).then((value) => value != "false");
  }

  Future<void> writeValue({required NotificationCategory category, required bool enabled}) {
    return _storage.write(key: category.storageKey, value: enabled.toString());
  }

  Future<void> deleteValue({required NotificationCategory category}) {
    return _storage.delete(key: category.storageKey);
  }
}

extension on NotificationCategory {
  String get storageKey => "notification_pref_$name";
}
