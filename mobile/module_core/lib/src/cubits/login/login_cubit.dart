import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";
import "../../platform/url_launcher.dart";
import "../../routing/app_routes.dart";
import "login_state.dart";

class LoginCubit extends Cubit<LoginState> {
  final OAuthFlowProvider _oAuthFlowProvider;
  final UrlLauncher _urlLauncher;

  // ignore: no_slop_linter/prefer_required_named_parameters, public cubit constructor API
  LoginCubit(
    OAuthFlowProvider oAuthFlowProvider,
    UrlLauncher urlLauncher,
  ) : _oAuthFlowProvider = oAuthFlowProvider,
      _urlLauncher = urlLauncher,
      super(const LoginState.idle());

  Future<bool> loginWithProvider(OAuthProvider provider) async {
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
}
