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
/// Both the in-memory flag and the persisted flag are cleared on logout (this
/// store listens to [AuthSession.authStateStream]) so a different account
/// signing in on the same device never inherits this one's answer.
@lazySingleton
class RegisteredBridgesStore {
  static const _storageKey = "has_registered_bridges";
  static const _storedValue = "true";

  final SecureStorage _storage;
  StreamSubscription<AuthState>? _authSubscription;

  /// In-memory mirror of the latch. `true` once the account is known to have a
  /// registered bridge; `false` means "not yet known" — never "no bridges".
  bool _knownRegistered = false;

  RegisteredBridgesStore({
    required SecureStorage secureStorage,
    required AuthSession authSession,
  }) : _storage = secureStorage {
    _authSubscription = authSession.authStateStream.listen((state) {
      // Logout: drop the latch so the next account starts from scratch.
      // clear() handles its own errors, so this stays fire-and-forget.
      if (state is AuthUnauthenticated) unawaited(clear());
    });
  }

  /// Whether the account is already known to have a registered bridge, from the
  /// in-memory flag or persisted storage. Reads storage at most once per app
  /// run for the positive answer; the in-memory flag short-circuits after that.
  Future<bool> hasRegisteredBridges() async {
    if (_knownRegistered) return true;
    try {
      if (await _storage.read(key: _storageKey) == _storedValue) {
        _knownRegistered = true;
      }
    } catch (error, stackTrace) {
      loge("Failed to read registered-bridges latch", error, stackTrace);
    }
    return _knownRegistered;
  }

  /// Latches the positive answer in memory and in persistent storage. A no-op
  /// once already latched, so repeat calls cost nothing.
  Future<void> markRegistered() async {
    if (_knownRegistered) return;
    _knownRegistered = true;
    try {
      await _storage.write(key: _storageKey, value: _storedValue);
    } catch (error, stackTrace) {
      loge("Failed to persist registered-bridges latch", error, stackTrace);
    }
  }

  /// Clears both the persisted latch and the in-memory flag. Invoked on logout
  /// so a different account signing in on the same device never inherits this
  /// one's answer.
  ///
  /// The persisted flag is deleted first, and the in-memory flag is dropped
  /// only after that succeeds: clearing memory first would let a concurrent
  /// [hasRegisteredBridges] read re-hydrate the in-memory flag from the
  /// not-yet-deleted storage value. A storage failure is logged and leaves the
  /// flags untouched (consistent with each other) rather than throwing into the
  /// logout listener.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _storageKey);
      _knownRegistered = false;
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
