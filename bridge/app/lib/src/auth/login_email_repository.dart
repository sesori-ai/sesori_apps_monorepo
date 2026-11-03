import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;
import 'package:sesori_shared/sesori_shared.dart';

import 'login_email_api.dart';
import 'token.dart';

class LoginEmailRepository({
  required final LoginEmailApi emailAuthApi,
  required final ({String email, String password}) Function() promptForCredentials,
}) {
  Future<TokenData> performEmailLogin() async {
    final credentials = promptForCredentials();

    try {
      final (tokens, username) = await _performEmailLoginInternal(
        email: credentials.email,
        password: credentials.password,
      );
      if (username case final name? when name.isNotEmpty) {
        Console.message('Login successful! Welcome, $name');
      } else {
        Console.message('Login successful!');
      }
      return tokens;
    } on EmailLoginException catch (e, stackTrace) {
      Log.e('Email login failed: ${e.message}', e.cause, stackTrace);
      rethrow;
    }
  }

  Future<(TokenData, String?)> _performEmailLoginInternal({
    required String email,
    required String password,
  }) async {
    final AuthResponse authResponse;
    try {
      authResponse = await emailAuthApi.loginWithEmail(email: email, password: password);
    } on EmailAuthApiException catch (error) {
      if (error.statusCode == 429) {
        throw RateLimitException();
      }
      if (error.statusCode == 401) {
        throw EmailLoginExceptionImpl(message: "invalid email or password", cause: error);
      }
      throw EmailLoginExceptionImpl(
        message: "login failed: status ${error.statusCode}: ${error.body.trim()}",
        cause: error,
      );
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(EmailLoginExceptionImpl(message: "network error: $error", cause: error), stackTrace);
    }

    if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
      throw EmailLoginExceptionImpl(message: "response missing tokens", cause: null);
    }

    return (
      TokenData(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        lastProvider: AuthProvider.email,
      ),
      authResponse.user.providerUsername,
    );
  }
}
