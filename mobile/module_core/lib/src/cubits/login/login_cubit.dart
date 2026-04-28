import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../platform/url_launcher.dart";
import "../../routing/app_routes.dart";
import "login_state.dart";

class LoginCubit extends Cubit<LoginState> {
  final OAuthFlowProvider _oAuthFlowProvider;
  final UrlLauncher _urlLauncher;
  final AuthSession _authSession;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  LoginCubit(
    OAuthFlowProvider oAuthFlowProvider,
    UrlLauncher urlLauncher,
    AuthSession authSession,
  ) : _oAuthFlowProvider = oAuthFlowProvider,
      _urlLauncher = urlLauncher,
      _authSession = authSession,
      super(const LoginState.idle());

  Future<bool> loginWithProvider(AuthProvider provider) async {
    if (provider == AuthProvider.email) {
      throw ArgumentError('AuthProvider.email is not supported by loginWithProvider. Use loginWithEmail instead.');
    }
    emit(const LoginState.authenticating());

    try {
      final authUrl = await _oAuthFlowProvider.getAuthorizationUrl(provider, redirectUri);
      if (isClosed) return false;

      logd("Opening ${provider.label} auth URL in browser");

      final launched = await _urlLauncher.launch(Uri.parse(authUrl));

      if (isClosed) return false;

      if (!launched) {
        emit(const LoginState.failed(error: "loginBrowserOpenFailed"));
        return false;
      }

      // Browser opened — OAuth callback will be handled by GoRouter redirect
      emit(const LoginState.awaitingCallback());
      return false; // Don't navigate — GoRouter handles it on callback
    } catch (e, st) {
      loge("${provider.label} login failed", e, st);
      if (isClosed) return false;
      emit(LoginState.failed(error: e.toString()));
      return false;
    }
  }

  Future<bool> loginWithEmail(String email, String password) async {
    if (email.trim().isEmpty) {
      emit(const LoginState.failed(error: "emailRequired"));
      return false;
    }

    if (password.isEmpty) {
      emit(const LoginState.failed(error: "passwordRequired"));
      return false;
    }

    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithEmail(email.trim(), password);
      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Email login failed", e, st);
      if (isClosed) return false;
      emit(LoginState.failed(error: e.toString()));
      return false;
    }
  }
}
