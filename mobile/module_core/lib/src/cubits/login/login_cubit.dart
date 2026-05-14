import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../platform/url_launcher.dart";
import "login_failed_reason.dart";
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

  Future<bool> loginWithProvider(OAuthProvider provider) async {
    emit(const LoginState.authenticating());

    try {
      final initResponse = await _oAuthFlowProvider.startOAuthFlow(provider: provider);
      if (isClosed) return false;

      emit(LoginState.awaitingConfirmation(userCode: initResponse.userCode));

      logd("Opening ${provider.label} auth URL in browser");

      final launched = await _urlLauncher.launch(Uri.parse(initResponse.authUrl));

      if (isClosed) return false;

      if (!launched) {
        emit(const LoginState.failed(reason: LoginFailedReason.browserOpenFailed));
        return false;
      }

      emit(const LoginState.polling());
      await _oAuthFlowProvider.pollForResult();

      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } on TimeoutException catch (e, st) {
      loge("${provider.label} login timed out", e, st);
      if (isClosed) return false;
      emit(const LoginState.timeout());
      return false;
    } catch (e, st) {
      loge("${provider.label} login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }

  void onMissingFormKey() {
    emit(const LoginState.failed(reason: LoginFailedReason.unknown));
  }

  void onMissingAppleIdToken() {
    emit(const LoginState.failed(reason: LoginFailedReason.appleIdTokenMissing));
  }

  void onAppleSignInError() {
    emit(const LoginState.failed(reason: LoginFailedReason.unknown));
  }

  Future<bool> loginWithApple({
    required String idToken,
    required String nonce,
  }) async {
    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithApple(idToken: idToken, nonce: nonce);
      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Apple login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }

  Future<bool> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) {
      emit(const LoginState.failed(reason: LoginFailedReason.emailRequired));
      return false;
    }

    if (password.isEmpty) {
      emit(const LoginState.failed(reason: LoginFailedReason.passwordRequired));
      return false;
    }

    emit(const LoginState.authenticating());

    try {
      await _authSession.loginWithEmail(email: email.trim(), password: password);
      if (isClosed) return false;
      emit(const LoginState.success());
      return true;
    } catch (e, st) {
      loge("Email login failed", e, st);
      if (isClosed) return false;
      emit(const LoginState.failed(reason: LoginFailedReason.unknown));
      return false;
    }
  }
}
