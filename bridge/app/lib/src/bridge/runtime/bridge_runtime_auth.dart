import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../auth/auth_provider.dart';
import '../../auth/login.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';

Future<AuthProvider> promptForProvider() async {
  stdout.writeln('Select login method: [1] GitHub [2] Google [3] Email');
  stdout.write('Enter choice (1-3): ');
  final input = stdin.readLineSync()?.trim();

  switch (input) {
    case '1':
      return AuthProvider.github;
    case '2':
      return AuthProvider.google;
    case '3':
      return AuthProvider.email;
    default:
      return AuthProvider.github;
  }
}

Future<(TokenData, String)> promptForEmailCredentials({
  required String authBackendUrl,
}) async {
  stdout.write('Email: ');
  final email = stdin.readLineSync() ?? '';

  stdout.write('Password: ');
  final password = _readPassword();

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

String _readPassword() {
  final buffer = StringBuffer();

  if (Platform.isWindows) {
    try {
      Process.runSync('stty', ['-icanon', 'min', '1']);
      Process.runSync('stty', ['-echo']);
    } catch (_) {}
    int char;
    while ((char = stdin.readByteSync()) != 10 && char != 13) {
      if (buffer.isNotEmpty && (char == 127 || char == 8)) {
        buffer.write('\b \b');
      } else if (char >= 32) {
        buffer.writeCharCode(char);
      }
    }
    try {
      Process.runSync('stty', ['icanon']);
      Process.runSync('stty', ['echo']);
    } catch (_) {}
    stdout.writeln();
    return buffer.toString();
  } else {
    final termios = Process.runSync('stty', ['-g']);
    Process.runSync('stty', ['-echo']);
    int char;
    while ((char = stdin.readByteSync()) != 10 && char != 13) {
      if (buffer.isNotEmpty && (char == 127 || char == 8)) {
        buffer.write('\b \b');
      } else if (char >= 32) {
        buffer.writeCharCode(char);
      }
    }
    try {
      Process.runSync('stty', [termios.stdout.toString().trim()]);
    } catch (_) {}
    stdout.writeln();
    return buffer.toString();
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
      options.authBackendUrl,
      storedTokens.accessToken,
      storedTokens.refreshToken,
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
  } catch (error) {
    throw Exception('validate stored tokens: $error');
  }

  AuthProvider provider;
  try {
    final storedTokens = await loadTokens();
    provider = storedTokens.lastProvider ?? AuthProvider.github;
  } on FileSystemException {
    provider = AuthProvider.github;
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
  final tokens = await performLogin(authBackendUrl, provider: provider);
  final tokensToSave = TokenData(
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    bridgeToken: tokens.bridgeToken,
    lastProvider: provider,
  );
  await saveTokens(tokensToSave);
  return tokensToSave;
}
