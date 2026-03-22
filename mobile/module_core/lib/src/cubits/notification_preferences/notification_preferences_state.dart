import "package:freezed_annotation/freezed_annotation.dart";

import "../../capabilities/notifications/notification_preferences_service.dart";

part "notification_preferences_state.freezed.dart";

@Freezed()
sealed class NotificationPreferencesState with _$NotificationPreferencesState {
  const factory NotificationPreferencesState.loading() = NotificationPreferencesLoading;

  const factory NotificationPreferencesState.loaded({
    required Map<NotificationCategoryPreference, bool> preferences,
  }) = NotificationPreferencesLoaded;
}
