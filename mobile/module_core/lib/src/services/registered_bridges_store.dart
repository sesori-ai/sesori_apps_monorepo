import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../logging/logging.dart";

/// Remembers the one-way "this account has registered at least one bridge"
/// latch, so the bridge-disconnected flow doesn't re-query the auth server on
/// every transition.
///
/// An account never goes from *has a registered bridge* back to *none*: a
/// bridge that is offline is still registered. The bridge-disconnected state
/// only needs that boolean to pick the recovery flow (set up a bridge vs. turn
/// the existing one on), so once the answer is known to be positive it never
/// has to be fetched again. The lookup is resolved in three tiers:
///
///  1. an in-memory flag answers instantly for the rest of the app run;
///  2. a persisted flag survives an app restart, so a returning user skips the
///     network on the first bridge-disconnected transition;
///  3. only when neither is set does the caller fall back to the network, and
///     a positive result is latched here via [markRegistered].
///
/// Only the positive answer is ever stored. A freshly set-up account (no
/// bridges yet) keeps looking up until it first succeeds — at which point it
/// latches and moves to the "turn your bridge on" flow for good.
///
/// ## Per-account isolation
///
/// The persisted latch is keyed by the signed-in account's id, and the
/// in-memory flag is dropped whenever the signed-in account changes (logout, or
/// a different account signing in — the store listens to
/// [AuthSession.authStateStream]). Scoping the key by account means one account
/// can never read another's answer, so even a logout `delete` that fails to
/// land cannot leak across accounts: the stale key belongs to the account that
/// owned it, and only that account would ever read it back (correctly — it
/// really does have a registered bridge).
@lazySingleton
class RegisteredBridgesStore {
  static const _keyPrefix = "has_registered_bridges";
  static const _storedValue = "true";

  final SecureStorage _storage;
  StreamSubscription<AuthState>? _authSubscription;

  /// Id of the signed-in account, or null when signed out. Seeded from the
  /// current auth state and kept current by the auth-state subscription so the
  /// first lookup after construction is already correctly scoped.
  String? _accountId;

  /// In-memory mirror of the latch for [_accountId]. `true` once that account
  /// is known to have a registered bridge; `false` means "not yet known" —
  /// never "no bridges".
  bool _knownRegistered = false;

  RegisteredBridgesStore({
    required SecureStorage secureStorage,
    required AuthSession authSession,
  }) : _storage = secureStorage {
    _accountId = _accountIdOf(authSession.authStateStream.valueOrNull);
    _authSubscription = authSession.authStateStream.listen((state) {
      switch (state) {
        case AuthAuthenticated(:final user):
          if (user.id == _accountId) return;
          // A different account signed in: drop the previous account's
          // in-memory latch and bind to the new one.
          _accountId = user.id;
          _knownRegistered = false;
        case AuthUnauthenticated():
          // Logout: drop the in-memory latch and best-effort delete the
          // persisted one. clear() handles its own errors, so fire-and-forget.
          unawaited(clear());
        case AuthInitial():
        case AuthAuthenticating():
        case AuthFailed():
          break;
      }
    });
  }

  static String? _accountIdOf(AuthState? state) => state is AuthAuthenticated ? state.user.id : null;

  String _storageKeyFor(String accountId) => "$_keyPrefix.$accountId";

  /// Whether the current account is already known to have a registered bridge,
  /// from the in-memory flag or persisted storage. Reads storage at most once
  /// per app run for the positive answer; the in-memory flag short-circuits
  /// after that. Returns `false` while signed out.
  Future<bool> hasRegisteredBridges() async {
    if (_knownRegistered) return true;
    final accountId = _accountId;
    if (accountId == null) return false;
    try {
      if (await _storage.read(key: _storageKeyFor(accountId)) == _storedValue) {
        _knownRegistered = true;
      }
    } catch (error, stackTrace) {
      loge("Failed to read the registered-bridges latch", error, stackTrace);
    }
    return _knownRegistered;
  }

  /// Latches the positive answer in memory and under the current account's key.
  /// A no-op once already latched, or while signed out.
  Future<void> markRegistered() async {
    if (_knownRegistered) return;
    final accountId = _accountId;
    if (accountId == null) return;
    _knownRegistered = true;
    try {
      await _storage.write(key: _storageKeyFor(accountId), value: _storedValue);
    } catch (error, stackTrace) {
      loge("Failed to persist the registered-bridges latch", error, stackTrace);
    }
  }

  /// Drops the in-memory flag and best-effort deletes the signing-out account's
  /// persisted key. Invoked on logout. Because keys are account-scoped, a delete
  /// that fails here is harmless — the lingering key can only ever be read back
  /// by the same account, for which the answer is still correct.
  Future<void> clear() async {
    _knownRegistered = false;
    final accountId = _accountId;
    _accountId = null;
    if (accountId == null) return;
    try {
      await _storage.delete(key: _storageKeyFor(accountId));
    } catch (error, stackTrace) {
      loge("Failed to clear the registered-bridges latch", error, stackTrace);
    }
  }

  @disposeMethod
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
