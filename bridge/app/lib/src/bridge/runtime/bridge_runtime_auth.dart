import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../auth/login.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';

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
    return _loginAndPersist(authBackendUrl: options.authBackendUrl);
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

  return _loginAndPersist(authBackendUrl: options.authBackendUrl);
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

Future<TokenData> _loginAndPersist({required String authBackendUrl}) async {
  final tokens = await performLogin(authBackendUrl);
  await saveTokens(tokens);
  return tokens;
}
