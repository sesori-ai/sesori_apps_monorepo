import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "../repositories/notification_preferences_repository.dart";

const _foregroundPreferenceDeadline = Duration(seconds: 2);

enum NotificationPreferencesAccountStatus { unavailable, available }

typedef _AccountOperation = ({int generation, String userId});

@lazySingleton
class NotificationPreferencesService {
  final AuthSession _authSession;
  final NotificationPreferencesRepository _repository;
  late final BehaviorSubject<NotificationPreferencesAccountStatus> _accountStatus;
  late final StreamSubscription<AuthState> _authSubscription;

  String? _currentUserId;
  int _accountGeneration = 0;

  NotificationPreferencesService({
    required AuthSession authSession,
    required NotificationPreferencesRepository repository,
  }) : _authSession = authSession,
       _repository = repository {
    _currentUserId = _userIdFrom(state: authSession.currentState);
    _accountStatus = BehaviorSubject.seeded(_statusFor(userId: _currentUserId));
    _authSubscription = _authSession.authStateStream.listen(
      // ignore: no_slop_linter/prefer_required_named_parameters, Stream callback
      (state) => _onAuthStateChanged(state: state),
      // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, Stream callback
      onError: (Object error, StackTrace stackTrace) => _onAuthStateError(
        error: error,
        stackTrace: stackTrace,
      ),
    );
  }

  Stream<NotificationPreferencesAccountStatus> get accountStatusStream => _accountStatus.stream;

  Future<Map<NotificationCategory, bool>> getAll() async {
    final operation = _captureAccount();
    final preferences = await _repository.getAll(userId: operation.userId);
    _ensureCurrent(operation: operation);
    return preferences;
  }

  Future<bool> setEnabled({required NotificationCategory category, required bool enabled}) async {
    final operation = _captureAccount();
    final confirmed = await _repository.setEnabled(
      userId: operation.userId,
      category: category,
      enabled: enabled,
    );
    _ensureCurrent(operation: operation);
    return confirmed;
  }

  Future<bool> isEnabled({required NotificationCategory category}) async {
    final operation = _currentOperation();
    if (operation == null) return false;
    if (category == NotificationCategory.unknown) return true;

    try {
      final enabled = await _repository
          .isEnabled(userId: operation.userId, category: category)
          .timeout(_foregroundPreferenceDeadline);
      if (!_isCurrent(operation: operation)) return false;
      return enabled;
    } on Object catch (error, stackTrace) {
      if (!_isCurrent(operation: operation)) return false;
      if (error is TimeoutException) {
        _repository.clearCache(userId: operation.userId);
      }
      logw(
        "Failed to load notification preferences; defaulting ${category.name} to enabled",
        error,
        stackTrace,
      );
      return true;
    }
  }

  void _onAuthStateChanged({required AuthState state}) {
    final nextUserId = _userIdFrom(state: state);
    if (nextUserId == _currentUserId) return;

    final previousUserId = _currentUserId;
    _currentUserId = nextUserId;
    _accountGeneration++;
    if (previousUserId != null) {
      _repository.clearCache(userId: previousUserId);
    }
    _accountStatus.add(_statusFor(userId: nextUserId));
  }

  // ignore: no_slop_linter/prefer_specific_type, Stream error values are untyped
  void _onAuthStateError({required Object error, required StackTrace stackTrace}) {
    loge("Notification preferences auth stream failed", error, stackTrace);
  }

  _AccountOperation _captureAccount() {
    final operation = _currentOperation();
    if (operation == null) throw ApiError.notAuthenticated();
    return operation;
  }

  void _ensureCurrent({required _AccountOperation operation}) {
    if (!_isCurrent(operation: operation)) throw ApiError.notAuthenticated();
  }

  _AccountOperation? _currentOperation() => switch (_currentUserId) {
    final String userId => (generation: _accountGeneration, userId: userId),
    null => null,
  };

  bool _isCurrent({required _AccountOperation operation}) =>
      operation.generation == _accountGeneration && operation.userId == _currentUserId;

  static String? _userIdFrom({required AuthState state}) => switch (state) {
    AuthAuthenticated(:final user) => user.id,
    AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
  };

  static NotificationPreferencesAccountStatus _statusFor({required String? userId}) => userId == null
      ? NotificationPreferencesAccountStatus.unavailable
      : NotificationPreferencesAccountStatus.available;

  @disposeMethod
  Future<void> dispose() async {
    await _authSubscription.cancel();
    await _accountStatus.close();
  }
}
