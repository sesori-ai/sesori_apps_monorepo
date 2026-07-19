import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/notification_preferences_repository.dart";
import "notification_preferences_state.dart";

class NotificationPreferencesCubit extends Cubit<NotificationPreferencesState> {
  final NotificationPreferencesRepository _repository;

  NotificationPreferencesCubit(NotificationPreferencesRepository repository)
    : _repository = repository,
      super(const NotificationPreferencesState.loading()) {
    _load();
  }

  Future<void> _load() async {
    final preferences = await _repository.getAll();
    if (isClosed) return;
    emit(NotificationPreferencesState.loaded(preferences: preferences));
  }

  Future<void> toggle(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    try {
      await _repository.setEnabled(category: category, enabled: enabled);
    } catch (error, stackTrace) {
      // Skip the emit so the switch keeps showing the persisted value.
      loge("Failed to persist notification preference ${category.name}", error, stackTrace);
      return;
    }

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
