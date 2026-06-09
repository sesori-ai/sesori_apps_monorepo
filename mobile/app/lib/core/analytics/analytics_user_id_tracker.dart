import "dart:async";
import "dart:convert";

import "package:crypto/crypto.dart";
import "package:firebase_analytics/firebase_analytics.dart";
import "package:sesori_auth/sesori_auth.dart";

/// Hashes the current user's ID and forwards it to Firebase Analytics so
/// events from the same account are grouped across devices.
///
/// The raw user ID is never sent to Firebase — only a SHA-256 hash of the
/// internal [AuthUser.id], making the identifier anonymous yet deterministic.
class AnalyticsUserIdTracker {
  final AuthSession _authSession;
  final FirebaseAnalytics _analytics;
  StreamSubscription<AuthState>? _subscription;

  AnalyticsUserIdTracker({
    required AuthSession authSession,
    required FirebaseAnalytics analytics,
  }) : _authSession = authSession,
       _analytics = analytics {
    _subscription = _authSession.authStateStream.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(AuthState state) async {
    switch (state) {
      case AuthAuthenticated(:final user):
        final hashedId = sha256.convert(utf8.encode(user.id)).toString();
        await _analytics.setUserId(id: hashedId);
      case AuthUnauthenticated():
        await _analytics.setUserId(id: null);
      case AuthInitial():
      case AuthAuthenticating():
      case AuthFailed():
        // No clear user identity in these states — leave the ID unchanged.
        break;
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
