import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import 'package:sesori_shared/sesori_shared.dart';
import '../../auth/login.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';
import 'terminal_password_reader.dart';

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

Future<(TokenData, String)> promptForEmailCredentials({
  required String authBackendUrl,
}) async {
  stdout.write('Email: ');
  final email = stdin.readLineSync() ?? '';

  stdout.write('Password: ');
  final password = TerminalPasswordReader(stdin: stdin).read();

  try {
    final (tokens, username) = await performEmailLogin(
      authBackendUrl,
      email,
      password,
    );
    if (username.isNotEmpty) {
      Log.i('Login successful! Welcome, $username');
    } else {
      Log.i('Login successful!');
    }
    return (tokens, username);
  } on EmailLoginException catch (e) {
    Log.e('Email login failed: ${e.message}');
    rethrow;
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
  } on FileSystemException catch (error) {
    if (error.osError?.errorCode != 2) {
      throw Exception('load stored tokens: $error');
    }
  } on FormatException {
    // Invalid token data (e.g., missing/invalid lastProvider) — treat as no valid tokens
    await clearTokens();
  } catch (error) {
    throw Exception('validate stored tokens: $error');
  }

  AuthProvider provider;
  try {
    final storedTokens = await loadTokens();
    provider = storedTokens.lastProvider;
  } on FileSystemException {
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
  final TokenData tokens;
  if (provider == AuthProvider.email) {
    final (emailTokens, _) = await promptForEmailCredentials(
      authBackendUrl: authBackendUrl,
    );
    tokens = emailTokens;
  } else {
    tokens = await performLogin(authBackendUrl, provider: provider);
  }
  final tokensToSave = TokenData(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    bridgeToken: tokens.bridgeToken,
    lastProvider: provider,
  );
  await saveTokens(tokensToSave);
  return tokensToSave;
}
