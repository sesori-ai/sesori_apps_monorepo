import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";
import "../repositories/message_image_repository.dart";

@lazySingleton
class MessageThumbnailCacheService({
  required final MessageImageRepository repository,
  required final AuthSession authSession,
}) {
  final MessageImageRepository _repository = repository;
  StreamSubscription<AuthState>? _authSubscription;
  Future<void> _authHandling = Future.value();
  late String? _accountId = _authenticatedAccountId(state: authSession.currentState);

  this {
    _authSubscription = authSession.authStateStream.listen(_handleAuthState);
  }

  void _handleAuthState(AuthState state) {
    final nextAccountId = _authenticatedAccountId(state: state);
    final previousAccountId = _accountId;
    _accountId = nextAccountId;
    if (previousAccountId != null && previousAccountId != nextAccountId) {
      final cleanup = _repository.retireAccountThumbnailCache(accountId: previousAccountId);
      _authHandling = _authHandling.then((_) => cleanup).onError((cause, stackTrace) {
        logw("Failed to clean retired account thumbnail cache", cause, stackTrace);
      });
    }
  }

  static String? _authenticatedAccountId({required AuthState state}) => switch (state) {
    AuthAuthenticated(:final user) => user.id,
    AuthInitial() || AuthUnauthenticated() || AuthAuthenticating() || AuthFailed() => null,
  };

  @disposeMethod
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
    await _authHandling;
    await _repository.waitForThumbnailCacheCleanup();
  }
}
