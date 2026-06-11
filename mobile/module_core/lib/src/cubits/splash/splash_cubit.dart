import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "../../routing/app_routes.dart";
import "splash_state.dart";

/// Resolves the startup route from local token storage only.
///
/// Splash stays intentionally lightweight: it never calls the auth server and
/// never validates tokens over the network. Downstream screens and services
/// own real connection/auth validation.
class SplashCubit extends Cubit<SplashState> {
  final AuthSession _authSession;

  SplashCubit(AuthSession authSession) : _authSession = authSession, super(const SplashState.initializing()) {
    _resolveInitialRoute().catchError((Object err) {
      loge("Splash: local session check failed", err);
      if (isClosed) return;
      emit(const SplashState.ready(route: AppRoute.login()));
    }).ignore();
  }

  Future<void> _resolveInitialRoute() async {
    try {
      final hasSession = await _authSession.hasLocallyValidSession();
      if (isClosed) return;
      if (hasSession) {
        // Best-effort, network-free rehydrate of the in-memory auth state so
        // downstream screens (e.g. onboarding) know the signed-in account
        // after a restart. Never affects routing.
        await _authSession.restoreLocalSession();
        if (isClosed) return;
      }
      emit(
        SplashState.ready(
          route: hasSession ? const AppRoute.projects() : const AppRoute.login(),
        ),
      );
    } catch (e, st) {
      loge("Splash: local session check failed", e, st);
      if (isClosed) return;
      emit(const SplashState.ready(route: AppRoute.login()));
    }
  }
}
