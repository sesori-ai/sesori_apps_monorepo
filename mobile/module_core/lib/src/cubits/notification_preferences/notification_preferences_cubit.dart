import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/notifications/notification_preferences_service.dart";
import "notification_preferences_state.dart";

class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  final NotificationPreferencesService _service;

  NotificationPreferencesCubit(NotificationPreferencesService service)
    : _service = service,
      super(const NotificationPreferencesState.loading()) {
    _load();
  }

  Future<void> _load() async {
    final preferences = await _service.getAll();
    if (isClosed) return;
    emit(NotificationPreferencesState.loaded(preferences: preferences));
  }

  Future<void> toggle(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    await _service.setEnabled(category, enabled: enabled);

    final currentState = state;
    if (currentState is! NotificationPreferencesLoaded || isClosed) return;

    emit(
      NotificationPreferencesState.loaded(
        preferences: {
          ...currentState.preferences,
          category: enabled,
        },
      ),
    );
  }
}
