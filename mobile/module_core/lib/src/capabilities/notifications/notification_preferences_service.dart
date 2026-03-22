import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

enum NotificationCategoryPreference {
  aiInteraction("notification_pref_ai_interaction"),
  sessionMessage("notification_pref_session_message"),
  connectionStatus("notification_pref_connection_status"),
  systemUpdate("notification_pref_system_update")
  ;

  const NotificationCategoryPreference(this.storageKey);

  final String storageKey;
}

@lazySingleton
class NotificationPreferencesService {
  final SecureStorage _storage;

  NotificationPreferencesService(SecureStorage storage) : _storage = storage;

  Future<bool> isEnabled(NotificationCategoryPreference category) async {
    final value = await _storage.read(key: category.storageKey);
    return value != "false";
  }

  Future<void> setEnabled(NotificationCategoryPreference category, {required bool enabled}) async {
    await _storage.write(key: category.storageKey, value: enabled.toString());
  }

  Future<Map<NotificationCategoryPreference, bool>> getAll() async {
    final results = <NotificationCategoryPreference, bool>{};

    for (final category in NotificationCategoryPreference.values) {
      results[category] = await isEnabled(category);
    }

    return results;
  }
}
