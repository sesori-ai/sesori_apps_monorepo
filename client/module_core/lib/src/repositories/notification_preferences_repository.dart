import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../api/notification_preferences_api.dart";
import "../api/storage/notification_preferences_device_id_storage.dart";

@lazySingleton
class NotificationPreferencesRepository {
  final NotificationPreferencesApi _api;
  final NotificationPreferencesDeviceIdStorage _deviceIdStorage;

  final Map<String, Map<NotificationCategory, bool>> _cachedPreferences = {};
  final Map<String, Future<Map<NotificationCategory, bool>>> _activeFetches = {};
  final Map<String, int> _cacheGenerations = {};

  NotificationPreferencesRepository({
    required NotificationPreferencesApi api,
    required NotificationPreferencesDeviceIdStorage deviceIdStorage,
  }) : _api = api,
       _deviceIdStorage = deviceIdStorage;

  Future<bool> isEnabled({required String userId, required NotificationCategory category}) async {
    if (category == NotificationCategory.unknown) return true;

    final cached = _cachedPreferences[userId];
    if (cached != null) return _cachedPreference(cached, category: category);

    final preferences = await _fetch(userId: userId);
    return _cachedPreference(preferences, category: category);
  }

  Future<bool> setEnabled({
    required String userId,
    required NotificationCategory category,
    required bool enabled,
  }) async {
    if (category == NotificationCategory.unknown) {
      throw ArgumentError.value(category, "category", "Unsupported notification category");
    }

    if (_cachedPreferences[userId] == null) {
      await _fetch(userId: userId);
    }
    final cacheGeneration = _cacheGeneration(userId: userId);
    final current = _cachedPreferences[userId];
    if (current == null) throw ApiError.notAuthenticated();

    final deviceId = await _deviceIdStorage.getOrCreate();
    _ensureCacheGeneration(userId: userId, expected: cacheGeneration);
    final record = await _api.updatePreference(
      userId: userId,
      deviceId: deviceId,
      request: _patchRequest(category: category, enabled: enabled),
    );
    _ensureCacheGeneration(userId: userId, expected: cacheGeneration);
    _validateDeviceId(record: record, expected: deviceId);

    final confirmed = _preferenceFrom(record.notifications, category: category);
    _cachedPreferences[userId] = Map.unmodifiable({...current, category: confirmed});
    return confirmed;
  }

  Future<Map<NotificationCategory, bool>> getAll({required String userId}) => _fetch(userId: userId);

  Future<Map<NotificationCategory, bool>> _fetch({required String userId}) {
    final activeFetch = _activeFetches[userId];
    if (activeFetch != null) return activeFetch;

    final cacheGeneration = _cacheGeneration(userId: userId);
    late final Future<Map<NotificationCategory, bool>> operation;
    operation = _fetchAndCache(userId: userId, cacheGeneration: cacheGeneration).whenComplete(() {
      if (identical(_activeFetches[userId], operation)) {
        _activeFetches.remove(userId);
      }
    });
    _activeFetches[userId] = operation;
    return operation;
  }

  Future<Map<NotificationCategory, bool>> _fetchAndCache({
    required String userId,
    required int cacheGeneration,
  }) async {
    final deviceId = await _deviceIdStorage.getOrCreate();
    _ensureCacheGeneration(userId: userId, expected: cacheGeneration);
    final record = await _api.getPreferences(userId: userId, deviceId: deviceId);
    _ensureCacheGeneration(userId: userId, expected: cacheGeneration);
    _validateDeviceId(record: record, expected: deviceId);

    final preferences = _preferencesFrom(record.notifications);
    _cachedPreferences[userId] = preferences;
    return preferences;
  }

  void clearCache({required String userId}) {
    _cachedPreferences.remove(userId);
    _activeFetches.remove(userId);
    _cacheGenerations[userId] = _cacheGeneration(userId: userId) + 1;
  }

  int _cacheGeneration({required String userId}) => _cacheGenerations[userId] ?? 0;

  void _ensureCacheGeneration({required String userId, required int expected}) {
    if (_cacheGeneration(userId: userId) != expected) throw ApiError.notAuthenticated();
  }

  void _validateDeviceId({required NotificationPreferencesApiRecord record, required String expected}) {
    if (record.deviceId != expected) {
      throw const FormatException("Invalid notification preferences device ID");
    }
  }

  bool _cachedPreference(
    Map<NotificationCategory, bool> preferences, {
    required NotificationCategory category,
  }) {
    final enabled = preferences[category];
    if (enabled == null) {
      throw const FormatException("Notification preference missing from cache");
    }
    return enabled;
  }

  Map<NotificationCategory, bool> _preferencesFrom(NotificationPreferencesApiNotifications notifications) =>
      Map.unmodifiable({
        NotificationCategory.aiInteraction: notifications.aiInteraction,
        NotificationCategory.sessionMessage: notifications.sessionMessage,
        NotificationCategory.connectionStatus: notifications.connectionStatus,
        NotificationCategory.systemUpdate: notifications.systemUpdate,
      });

  bool _preferenceFrom(
    NotificationPreferencesApiNotifications notifications, {
    required NotificationCategory category,
  }) => switch (category) {
    NotificationCategory.aiInteraction => notifications.aiInteraction,
    NotificationCategory.sessionMessage => notifications.sessionMessage,
    NotificationCategory.connectionStatus => notifications.connectionStatus,
    NotificationCategory.systemUpdate => notifications.systemUpdate,
    NotificationCategory.unknown => throw ArgumentError.value(
      category,
      "category",
      "Unsupported notification category",
    ),
  };

  NotificationPreferencePatchApiRequest _patchRequest({
    required NotificationCategory category,
    required bool enabled,
  }) => switch (category) {
    NotificationCategory.aiInteraction => NotificationPreferencePatchApiRequest.aiInteraction(enabled: enabled),
    NotificationCategory.sessionMessage => NotificationPreferencePatchApiRequest.sessionMessage(enabled: enabled),
    NotificationCategory.connectionStatus => NotificationPreferencePatchApiRequest.connectionStatus(enabled: enabled),
    NotificationCategory.systemUpdate => NotificationPreferencePatchApiRequest.systemUpdate(enabled: enabled),
    NotificationCategory.unknown => throw ArgumentError.value(
      category,
      "category",
      "Unsupported notification category",
    ),
  };
}
