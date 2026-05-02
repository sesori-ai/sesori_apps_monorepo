import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "../../routing/app_routes.dart";
import "splash_state.dart";

/// Resolves the startup route by asking [AuthSession] whether a previous
/// session can be restored, with a hard timeout so a stuck SecureStorage
/// read or slow `/auth/me` call can never leave the user on a blank splash.
///
/// The cubit does not touch the relay — relay auto-connect is owned by
/// [ConnectionService], which listens to [AuthSession.authStateStream] and
/// reacts symmetrically to `AuthAuthenticated` and `AuthUnauthenticated`.
class SplashCubit extends Cubit<SplashState> {
  static const Duration _restoreTimeout = Duration(seconds: 5);

  final AuthSession _authSession;

  SplashCubit(AuthSession authSession) : _authSession = authSession, super(const SplashState.initializing()) {
    _resolveInitialRoute().catchError((Object err) {
      loge("Splash: session restore failed", err);
      if (isClosed) return;
      emit(const SplashState.ready(route: AppRoute.login()));
    }).ignore();
  }

  Future<void> _resolveInitialRoute() async {
    try {
      final restored = await _authSession.restoreSession().timeout(_restoreTimeout);
      if (isClosed) return;
      emit(
        SplashState.ready(
          route: restored ? const AppRoute.projects() : const AppRoute.login(),
        ),
      );
    } on TimeoutException catch (e, st) {
      loge("Splash: session restore timed out after $_restoreTimeout", e, st);
      if (isClosed) return;
      emit(const SplashState.ready(route: AppRoute.login()));
    } catch (e, st) {
      loge("Splash: session restore failed", e, st);
      if (isClosed) return;
      emit(const SplashState.ready(route: AppRoute.login()));
    }
  }
}
