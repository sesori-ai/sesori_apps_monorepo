import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import 'package:sesori_shared/sesori_shared.dart';
import '../../auth/login_email_repository.dart';
import '../../auth/login_oauth_api.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';
import 'terminal_password_reader.dart';

({String email, String password}) promptForEmailCredentials() {
  stdout.write('Email: ');
  final email = stdin.readLineSync();
  if (email == null) {
    throw Exception('EOF reached while reading email');
  }

  stdout.write('Password: ');
  final password = TerminalPasswordReader(stdin: stdin).read();

  return (email: email, password: password);
}

class BridgeRuntimeAuthService {
  final LoginEmailRepository _loginEmailRepository;
  final LoginOAuthApi _loginOAuthApi;

  const BridgeRuntimeAuthService({
    required LoginEmailRepository loginEmailRepository,
    required LoginOAuthApi loginOAuthApi,
  }) : _loginEmailRepository = loginEmailRepository,
       _loginOAuthApi = loginOAuthApi;

  Future<AuthProvider> promptForProvider() async {
    while (true) {
      stdout.writeln('Select login method: [1] GitHub [2] Google [3] Email');
      stdout.write('Enter choice (1-3): ');
      final input = stdin.readLineSync()?.trim();

      if (input == null) {
        throw Exception('EOF reached while reading login provider choice');
      }

      switch (input) {
        case '1':
          return AuthProvider.github;
        case '2':
          return AuthProvider.google;
        case '3':
          return AuthProvider.email;
        default:
          stdout.writeln('Invalid choice. Please enter 1, 2, or 3.');
      }
    }
  }

  Future<TokenData> ensureAuthenticated({required BridgeCliOptions options}) async {
    if (options.forceLogin) {
      await clearTokens();
      final provider = await promptForProvider();
      return _loginAndPersist(
        authBackendUrl: options.authBackendUrl,
        provider: provider,
      );
    }

    try {
      final storedTokens = await loadTokens();
      try {
        final (validatedTokens, ok) = await validateToken(
          authBackendURL: options.authBackendUrl,
          accessToken: storedTokens.accessToken,
          refreshToken: storedTokens.refreshToken,
          lastProvider: storedTokens.lastProvider,
        );
        if (ok) {
          final tokensToSave = TokenData(
            accessToken: validatedTokens.accessToken,
            refreshToken: validatedTokens.refreshToken,
            bridgeToken: storedTokens.bridgeToken,
            lastProvider: storedTokens.lastProvider,
          );
          await saveTokens(tokensToSave);
          return tokensToSave;
        }
      } catch (error) {
        throw Exception('validate stored tokens: $error');
      }
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 2) {
        throw Exception('load stored tokens: $error');
      }
      // Token file not found — fall through to login below
    } on FormatException {
      // Invalid token data (e.g., missing/invalid lastProvider) — treat as no valid tokens
      await clearTokens();
      // Fall through to login below
    }

    AuthProvider provider;
    try {
      final storedTokens = await loadTokens();
      provider = storedTokens.lastProvider;
    } on FileSystemException catch (error) {
      if (error.osError?.errorCode != 2) {
        throw Exception('load stored tokens: $error');
      }
      provider = await promptForProvider();
    } on FormatException {
      provider = await promptForProvider();
    }

    return _loginAndPersist(
      authBackendUrl: options.authBackendUrl,
      provider: provider,
    );
  }

  Future<void> logAuthenticatedUser({
    required String authBackendUrl,
    required String accessToken,
  }) async {
    try {
      final username = await fetchUsername(authBackendUrl, accessToken);
      Log.i('Authenticated as $username');
    } catch (error) {
      Log.w('Authenticated (unable to fetch profile username: $error)');
    }
  }

  Future<TokenData> _loginAndPersist({
    required String authBackendUrl,
    required AuthProvider provider,
  }) async {
    final TokenData tokens = await switch (provider) {
      OAuthProvider() => _loginOAuthApi.performOAuthLogin(provider),
      EmailAuthProvider() => _loginEmailRepository.performEmailLogin(),
    };

    final tokensToSave = TokenData(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      bridgeToken: tokens.bridgeToken,
      lastProvider: provider,
    );
    await saveTokens(tokensToSave);
    return tokensToSave;
  }
}
