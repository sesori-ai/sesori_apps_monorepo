import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_preferences_api.dart";

extension on NotificationCategory {
  String get storageKey => "notification_pref_$name";
}

@lazySingleton
class NotificationPreferencesRepository {
  final NotificationPreferencesApi _api;

  NotificationPreferencesRepository({required NotificationPreferencesApi api}) : _api = api;

  Future<bool> isEnabled({required NotificationCategory category}) async {
    final value = await _api.readValue(key: category.storageKey);
    return value != "false";
  }

  Future<void> setEnabled({required NotificationCategory category, required bool enabled}) {
    if (enabled) {
      return _api.deleteValue(key: category.storageKey);
    }

    return _api.writeValue(key: category.storageKey, value: enabled.toString());
  }

  Future<Map<NotificationCategory, bool>> getAll() async {
    final results = <NotificationCategory, bool>{};

    for (final category in NotificationCategory.values) {
      results[category] = await isEnabled(category: category);
    }

    return results;
  }
}
