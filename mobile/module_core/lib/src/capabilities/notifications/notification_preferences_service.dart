import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

extension NotificationCategoryStorage on NotificationCategory {
  String get storageKey => "notification_pref_$name";
}

@lazySingleton
class NotificationPreferencesService {
  final SecureStorage _storage;

  NotificationPreferencesService(SecureStorage storage) : _storage = storage;

  Future<bool> isEnabled(NotificationCategory category) async {
    final value = await _storage.read(key: category.storageKey);
    return value != "false";
  }

  Future<void> setEnabled(NotificationCategory category, {required bool enabled}) async {
    await _storage.write(key: category.storageKey, value: enabled.toString());
  }

  Future<Map<NotificationCategory, bool>> getAll() async {
    final results = <NotificationCategory, bool>{};

    for (final category in NotificationCategory.values) {
      results[category] = await isEnabled(category);
    }

    return results;
  }
}
