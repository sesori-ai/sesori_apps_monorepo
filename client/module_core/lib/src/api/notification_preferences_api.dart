import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";
import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonCastMap;

part "notification_preferences_api.freezed.dart";
part "notification_preferences_api.g.dart";

@Freezed(fromJson: true, toJson: false)
sealed class NotificationPreferencesApiRecord with _$NotificationPreferencesApiRecord {
  const factory NotificationPreferencesApiRecord({
    required String deviceId,
    required NotificationPreferencesApiNotifications notifications,
    required DateTime? updatedAt,
  }) = _NotificationPreferencesApiRecord;

  factory NotificationPreferencesApiRecord.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesApiRecordFromJson(json);
}

@Freezed(fromJson: true, toJson: false)
sealed class NotificationPreferencesApiNotifications with _$NotificationPreferencesApiNotifications {
  const factory NotificationPreferencesApiNotifications({
    required bool aiInteraction,
    required bool sessionMessage,
    required bool connectionStatus,
    required bool systemUpdate,
  }) = _NotificationPreferencesApiNotifications;

  factory NotificationPreferencesApiNotifications.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesApiNotificationsFromJson(json);
}

@Freezed(fromJson: false, toJson: false)
sealed class NotificationPreferencePatchApiRequest with _$NotificationPreferencePatchApiRequest {
  const NotificationPreferencePatchApiRequest._();

  const factory NotificationPreferencePatchApiRequest.aiInteraction({required bool enabled}) =
      NotificationPreferencePatchAiInteraction;
  const factory NotificationPreferencePatchApiRequest.sessionMessage({required bool enabled}) =
      NotificationPreferencePatchSessionMessage;
  const factory NotificationPreferencePatchApiRequest.connectionStatus({required bool enabled}) =
      NotificationPreferencePatchConnectionStatus;
  const factory NotificationPreferencePatchApiRequest.systemUpdate({required bool enabled}) =
      NotificationPreferencePatchSystemUpdate;

  Map<String, Map<String, bool>> toJson() => {
    "notifications": switch (this) {
      NotificationPreferencePatchAiInteraction(:final enabled) => {"aiInteraction": enabled},
      NotificationPreferencePatchSessionMessage(:final enabled) => {"sessionMessage": enabled},
      NotificationPreferencePatchConnectionStatus(:final enabled) => {"connectionStatus": enabled},
      NotificationPreferencePatchSystemUpdate(:final enabled) => {"systemUpdate": enabled},
    },
  };
}

@lazySingleton
class NotificationPreferencesApi {
  final AuthenticatedHttpApiClient _client;

  NotificationPreferencesApi({required AuthenticatedHttpApiClient client}) : _client = client;

  Future<NotificationPreferencesApiRecord> getPreferences({
    required String userId,
    required String deviceId,
  }) async {
    final response = await _client.getForUser<NotificationPreferencesApiRecord>(
      url: _settingsUrl(deviceId: deviceId),
      userId: userId,
      fromJson: (dynamic json) => NotificationPreferencesApiRecord.fromJson(jsonCastMap(json)),
    );
    return _dataOrThrow(response);
  }

  Future<NotificationPreferencesApiRecord> updatePreference({
    required String userId,
    required String deviceId,
    required NotificationPreferencePatchApiRequest request,
  }) async {
    final response = await _client.patchForUser<NotificationPreferencesApiRecord>(
      url: _settingsUrl(deviceId: deviceId),
      userId: userId,
      fromJson: (dynamic json) => NotificationPreferencesApiRecord.fromJson(jsonCastMap(json)),
      body: jsonEncode(request.toJson()),
    );
    return _dataOrThrow(response);
  }

  Uri _settingsUrl({required String deviceId}) => Uri.parse("$authBaseUrl/auth/settings/$deviceId");

  NotificationPreferencesApiRecord _dataOrThrow(ApiResponse<NotificationPreferencesApiRecord> response) =>
      switch (response) {
        SuccessResponse(:final data) => data,
        ErrorResponse(:final error) => throw error,
      };
}
