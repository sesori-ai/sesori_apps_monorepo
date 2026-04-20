import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

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
    await _repository.setEnabled(category: category, enabled: enabled);

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
