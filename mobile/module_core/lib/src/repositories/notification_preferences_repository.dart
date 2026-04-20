import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_preferences_api.dart";

@lazySingleton
class NotificationPreferencesRepository {
  final NotificationPreferencesApi _api;

  NotificationPreferencesRepository({required NotificationPreferencesApi api}) : _api = api;

  Future<bool> isEnabled({required NotificationCategory category}) async {
    final enabled = await _api.readValue(category: category);
    return enabled ?? true;
  }

  Future<void> setEnabled({required NotificationCategory category, required bool enabled}) {
    if (enabled) {
      return _api.deleteValue(category: category);
    }

    return _api.writeValue(category: category, enabled: enabled);
  }

  Future<Map<NotificationCategory, bool>> getAll() async {
    final results = <NotificationCategory, bool>{};

    for (final category in NotificationCategory.values) {
      results[category] = await isEnabled(category: category);
    }

    return results;
  }
}
