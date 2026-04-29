import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

import 'login_email_api.dart';
import 'token.dart';

class LoginEmailRepository {
  final LoginEmailApi emailAuthApi;
  final ({String email, String password}) Function() promptForCredentials;

  LoginEmailRepository({
    required this.emailAuthApi,
    required this.promptForCredentials,
  });

  Future<TokenData> performEmailLogin() async {
    final credentials = promptForCredentials();

    try {
      final (tokens, username) = await _performEmailLoginInternal(
        email: credentials.email,
        password: credentials.password,
      );
      if (username.isNotEmpty) {
        Log.i('Login successful! Welcome, $username');
      } else {
        Log.i('Login successful!');
      }
      return tokens;
    } on EmailLoginException catch (e) {
      Log.e('Email login failed: ${e.message}');
      rethrow;
    }
  }

  Future<(TokenData, String)> _performEmailLoginInternal({
    required String email,
    required String password,
  }) async {
    final AuthResponse authResponse;
    try {
      authResponse = await emailAuthApi.loginWithEmail(email: email, password: password);
    } on EmailAuthApiException catch (e) {
      if (e.statusCode == 429) {
        throw RateLimitException();
      }
      if (e.statusCode == 401) {
        throw EmailLoginExceptionImpl("invalid email or password");
      }
      throw EmailLoginExceptionImpl(
        "login failed: status ${e.statusCode}: ${e.body.trim()}",
      );
    } catch (e) {
      throw EmailLoginExceptionImpl("network error: $e");
    }

    if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
      throw EmailLoginExceptionImpl("response missing tokens");
    }

    return (
      TokenData(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        lastProvider: AuthProvider.email,
      ),
      authResponse.user.providerUsername ?? "",
    );
  }
}
