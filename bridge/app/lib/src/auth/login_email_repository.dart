import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;
import 'package:sesori_shared/sesori_shared.dart';

import '../bridge/runtime/terminal_password_reader.dart';
import 'login_email_api.dart';
import 'token.dart';

({String email, String password}) _promptForEmailCredentials() {
  stdout.write('Email: ');
  final email = stdin.readLineSync() ?? '';

  stdout.write('Password: ');
  final password = TerminalPasswordReader(stdin: stdin).read();

  return (email: email, password: password);
}

class LoginEmailRepository {
  final LoginEmailApi emailAuthApi;
  final ({String email, String password}) Function() promptForCredentials;

  LoginEmailRepository({
    required this.emailAuthApi,
    this.promptForCredentials = _promptForEmailCredentials,
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
