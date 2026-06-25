import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_shared/sesori_shared.dart";

part "notification_preferences_state.freezed.dart";

@Freezed()
sealed class NotificationPreferencesState with _$NotificationPreferencesState {
  const factory NotificationPreferencesState.loading() = NotificationPreferencesLoading;

  const factory NotificationPreferencesState.loaded({
    required Map<NotificationCategory, bool> preferences,
  }) = NotificationPreferencesLoaded;
}
