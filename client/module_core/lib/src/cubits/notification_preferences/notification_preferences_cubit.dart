import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../services/notification_preferences_service.dart";
import "notification_preferences_state.dart";

class NotificationPreferencesCubit({required NotificationPreferencesService service}) extends Cubit<NotificationPreferencesState> {
  final NotificationPreferencesService _service;
  late final StreamSubscription<NotificationPreferencesAccountStatus> _accountSubscription;

  NotificationPreferencesAccountStatus _accountStatus = NotificationPreferencesAccountStatus.unavailable;
  int _accountGeneration = 0;
  int _loadGeneration = 0;

  this
    : _service = service,
      super(const NotificationPreferencesState.loading()) {
    _accountSubscription = _service.accountStatusStream.listen(
      // ignore: no_slop_linter/prefer_required_named_parameters, Stream callback
      (status) => _onAccountStatus(status: status),
      // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, Stream callback
      onError: (Object error, StackTrace stackTrace) => _onAccountStatusError(
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<void> _load({required int generation}) async {
    try {
      final preferences = await _service.getAll();
      if (isClosed || generation != _loadGeneration) return;
      emit(
        NotificationPreferencesState.loaded(
          preferences: preferences,
          updatingCategories: const {},
        ),
      );
    } on Object catch (error, stackTrace) {
      if (isClosed || generation != _loadGeneration) return;
      loge("Failed to load notification preferences", error, stackTrace);
      emit(const NotificationPreferencesState.loadFailed());
    }
  }

  Future<void> retry() {
    if (_accountStatus == NotificationPreferencesAccountStatus.unavailable || state is NotificationPreferencesLoading) {
      return Future.value();
    }
    emit(const NotificationPreferencesState.loading());
    final generation = ++_loadGeneration;
    return _load(generation: generation);
  }

  Future<void> toggle(
    NotificationCategory category, {
    required bool enabled,
  }) async {
    final initialState = state;
    if (initialState is! NotificationPreferencesLoaded || initialState.updatingCategories.contains(category)) {
      return;
    }
    final accountGeneration = _accountGeneration;

    emit(
      initialState.copyWith(
        updatingCategories: {...initialState.updatingCategories, category},
      ),
    );

    final bool confirmed;
    try {
      confirmed = await _service.setEnabled(category: category, enabled: enabled);
    } catch (error, stackTrace) {
      if (isClosed || accountGeneration != _accountGeneration) return;
      loge("Failed to persist notification preference ${category.name}", error, stackTrace);
      final currentState = state;
      if (currentState is! NotificationPreferencesLoaded) return;
      final updatingCategories = {...currentState.updatingCategories}..remove(category);
      emit(currentState.copyWith(updatingCategories: updatingCategories));
      return;
    }

    final currentState = state;
    if (currentState is! NotificationPreferencesLoaded || isClosed || accountGeneration != _accountGeneration) {
      return;
    }
    final updatingCategories = {...currentState.updatingCategories}..remove(category);
    emit(
      currentState.copyWith(
        preferences: {...currentState.preferences, category: confirmed},
        updatingCategories: updatingCategories,
      ),
    );
  }

  void _onAccountStatus({required NotificationPreferencesAccountStatus status}) {
    if (isClosed) return;
    _accountStatus = status;
    _accountGeneration++;
    final loadGeneration = ++_loadGeneration;
    if (status == NotificationPreferencesAccountStatus.unavailable) {
      if (state is! NotificationPreferencesAccountUnavailable) {
        emit(const NotificationPreferencesState.accountUnavailable());
      }
      return;
    }
    if (state is! NotificationPreferencesLoading) {
      emit(const NotificationPreferencesState.loading());
    }
    unawaited(_load(generation: loadGeneration));
  }

  // ignore: no_slop_linter/prefer_specific_type, Stream error values are untyped
  void _onAccountStatusError({required Object error, required StackTrace stackTrace}) {
    loge("Notification preferences account stream failed", error, stackTrace);
    if (isClosed) return;
    emit(const NotificationPreferencesState.loadFailed());
  }

  @override
  Future<void> close() async {
    await _accountSubscription.cancel();
    return super.close();
  }
}
