import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import 'package:sesori_shared/sesori_shared.dart';
import '../../auth/login_email_repository.dart';
import '../../auth/login_oauth_service.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';

class BridgeRuntimeAuthService {
  final LoginEmailRepository _loginEmailRepository;
  final LoginOAuthService _loginOAuthService;

  const BridgeRuntimeAuthService({
    required LoginEmailRepository loginEmailRepository,
    required LoginOAuthService loginOAuthService,
  }) : _loginEmailRepository = loginEmailRepository,
       _loginOAuthService = loginOAuthService;

  Future<AuthProvider> promptForProvider() async {
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
            bridgeId: storedTokens.bridgeId,
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
      OAuthProvider() => _loginOAuthService.performOAuthLogin(provider),
      EmailAuthProvider() => _loginEmailRepository.performEmailLogin(),
    };

    // A fresh login response never carries a bridge id, so carry over the one
    // persisted by a previous registration. Otherwise an interactive re-login
    // (e.g. expired refresh token) would wipe it and the next registration
    // would mint a duplicate bridge entry. Carrying it across an account
    // switch is safe: registration is idempotent on (userId, bridgeId), and a
    // bridge id not owned by the new account just gets a fresh mint.
    String? existingBridgeId;
    try {
      final existingTokens = await loadTokens();
      existingBridgeId = existingTokens.bridgeId;
    } on Object {
      // Token file missing or corrupt — no previous bridge id to carry over.
      existingBridgeId = null;
    }

    final tokensToSave = TokenData(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      bridgeId: tokens.bridgeId ?? existingBridgeId,
      lastProvider: provider,
    );
    await saveTokens(tokensToSave);
    return tokensToSave;
  }
}
