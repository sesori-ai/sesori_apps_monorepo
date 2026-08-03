import "dart:async";

import "package:injectable/injectable.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../logging/logging.dart";
import "../repositories/notification_preferences_repository.dart";

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
    _currentUserId = _userIdFrom(authSession.currentState);
    _accountStatus = BehaviorSubject.seeded(_statusFor(userId: _currentUserId));
    _authSubscription = _authSession.authStateStream.listen(
      _onAuthStateChanged,
      onError: _onAuthStateError,
    );
  }

  Stream<NotificationPreferencesAccountStatus> get accountStatusStream => _accountStatus.stream;

  Future<Map<NotificationCategory, bool>> getAll() async {
    final operation = _captureAccount();
    final preferences = await _repository.getAll(userId: operation.userId);
    _ensureCurrent(operation);
    return preferences;
  }

  Future<bool> setEnabled({required NotificationCategory category, required bool enabled}) async {
    final operation = _captureAccount();
    final confirmed = await _repository.setEnabled(
      userId: operation.userId,
      category: category,
      enabled: enabled,
    );
    _ensureCurrent(operation);
    return confirmed;
  }

  Future<bool> isEnabled({required NotificationCategory category}) async {
    if (category == NotificationCategory.unknown) return true;

    try {
      final operation = _captureAccount();
      final enabled = await _repository.isEnabled(userId: operation.userId, category: category);
      _ensureCurrent(operation);
      return enabled;
    } on Object catch (error, stackTrace) {
      logw(
        "Failed to load notification preferences; defaulting ${category.name} to enabled",
        error,
        stackTrace,
      );
      return true;
    }
  }

  void _onAuthStateChanged(AuthState state) {
    final nextUserId = _userIdFrom(state);
    if (nextUserId == _currentUserId) return;

    final previousUserId = _currentUserId;
    _currentUserId = nextUserId;
    _accountGeneration++;
    if (previousUserId != null) {
      _repository.clearCache(userId: previousUserId);
    }
    _accountStatus.add(_statusFor(userId: nextUserId));
  }

  // ignore: no_slop_linter/prefer_specific_type, no_slop_linter/prefer_required_named_parameters, stream callback
  void _onAuthStateError(Object error, StackTrace stackTrace) {
    loge("Notification preferences auth stream failed", error, stackTrace);
  }

  _AccountOperation _captureAccount() {
    final userId = _currentUserId;
    if (userId == null) throw ApiError.notAuthenticated();
    return (generation: _accountGeneration, userId: userId);
  }

  void _ensureCurrent(_AccountOperation operation) {
    if (operation.generation != _accountGeneration || operation.userId != _currentUserId) {
      throw ApiError.notAuthenticated();
    }
  }

  static String? _userIdFrom(AuthState state) => switch (state) {
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
