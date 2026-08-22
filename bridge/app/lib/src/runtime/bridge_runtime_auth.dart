import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Console, Log;

import 'package:sesori_shared/sesori_shared.dart';

import '../auth/auth_repository.dart';
import '../auth/login_email_repository.dart';
import '../auth/login_oauth_service.dart';
import '../auth/token.dart';
import '../foundation/legacy_post_update_relaunch.dart';
import 'bridge_cli_options.dart';

const Duration _oAuthAckTimeout = Duration(seconds: 5);

class const BridgeRuntimeAuthService({
  required final LoginEmailRepository _loginEmailRepository,
  required final LoginOAuthService _loginOAuthService,
  required final AuthRepository _authRepository,
  required final Map<String, String> _environment,
  required final Future<TokenData> Function() _loadTokens,
  required final Future<void> Function(TokenData tokens) _saveTokens,
  required final Future<void> Function() _clearTokens,
}) {
  Future<AuthProvider> promptForProvider() async {
    if (_environment[sesoriPostUpdateRestartEnvVar] == '1') {
      // Legacy upgrade: an old binary relaunched us (possibly non-interactively)
      // after applying an update, and there are no usable stored tokens. Don't
      // block on an unanswerable prompt — tell the user to start again from a
      // terminal.
      throw Exception(
        'Login required, but this bridge was relaunched non-interactively after an auto-update. '
        'Run sesori-bridge again from a terminal to log in.',
      );
    }

    while (true) {
      stdout.writeln('Select login method: [1] GitHub [2] Google [3] Apple [4] Email');
      stdout.write('Enter choice (1-4): ');
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
          return AuthProvider.apple;
        case '4':
          return AuthProvider.email;
        default:
          stdout.writeln('Invalid choice. Please enter 1, 2, 3, or 4.');
      }
    }
  }

  Future<TokenData> ensureAuthenticated({required BridgeCliOptions options}) async {
    TokenData? storedTokens;
    try {
      storedTokens = await _loadTokens();
      try {
        final lookup = await _authRepository.lookupCurrentUser(accessToken: storedTokens.accessToken);
        switch (lookup) {
          case AuthUserFound():
            final tokensToSave = TokenData(
              accessToken: storedTokens.accessToken,
              refreshToken: storedTokens.refreshToken,
              lastProvider: storedTokens.lastProvider,
            );
            await _saveTokens(tokensToSave);
            return tokensToSave;
          case AuthUserRejected(statusCode: 401):
            final refresh = await _authRepository.refreshToken(refreshToken: storedTokens.refreshToken);
            switch (refresh) {
              case AuthTokenRefreshed(:final response):
                final tokensToSave = TokenData(
                  accessToken: response.accessToken,
                  refreshToken: response.refreshToken,
                  lastProvider: storedTokens.lastProvider,
                );
                await _saveTokens(tokensToSave);
                return tokensToSave;
              case AuthTokenRefreshRejected():
                break;
            }
          case AuthUserRejected():
            break;
        }
      } catch (error) {
        throw Exception('validate stored tokens: $error');
      }
    } on PathNotFoundException {
      // Token file or its parent directory does not exist — fall through to
      // login below. PathNotFoundException is the portable "missing path"
      // signal: POSIX ENOENT, Windows ERROR_FILE_NOT_FOUND (errno 2), and
      // Windows ERROR_PATH_NOT_FOUND (errno 3, e.g. the %LOCALAPPDATA%\sesori
      // directory missing on first run) all surface as this type.
    } on FileSystemException catch (error) {
      throw Exception('load stored tokens: $error');
    } on FormatException {
      // Invalid token data (e.g., missing/invalid lastProvider) — treat as no valid tokens
      await _clearTokens();
      storedTokens = null;
      // Fall through to login below
    }

    final provider = storedTokens?.lastProvider ?? await promptForProvider();

    return await _loginAndPersist(
      authBackendUrl: options.authBackendUrl,
      provider: provider,
    );
  }

  Future<void> logAuthenticatedUser({
    required String accessToken,
  }) async {
    try {
      final username = await _authRepository.fetchUsername(accessToken: accessToken);
      Console.message('Authenticated as $username');
    } catch (error) {
      Log.w('Authenticated (unable to fetch profile username: $error)');
    }
  }

  Future<TokenData> _loginAndPersist({
    required String authBackendUrl,
    required AuthProvider provider,
  }) async {
    final TokenData tokens;
    final String? oAuthSessionToken;
    switch (provider) {
      case OAuthProvider():
        final result = await _loginOAuthService.performOAuthLogin(provider);
        tokens = result.tokens;
        oAuthSessionToken = result.sessionToken;
      case EmailAuthProvider():
        tokens = await _loginEmailRepository.performEmailLogin();
        oAuthSessionToken = null;
    }

    final tokensToSave = TokenData(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      lastProvider: provider,
    );
    await _saveTokens(tokensToSave);
    if (oAuthSessionToken != null) {
      try {
        await _loginOAuthService.ackOAuthSessionCompletion(sessionToken: oAuthSessionToken).timeout(_oAuthAckTimeout);
      } catch (error) {
        Log.w('Failed to acknowledge OAuth session completion; server will expire it: $error');
      }
    }
    return tokensToSave;
  }
}
