import 'dart:io';

import 'package:sesori_plugin_interface/sesori_plugin_interface.dart' show Log;

import '../../auth/login.dart';
import '../../auth/profile.dart';
import '../../auth/token.dart';
import '../../auth/validate.dart';
import 'bridge_cli_options.dart';

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
  final tokens = await login(authBackendUrl);
  await saveTokens(tokens);
  return tokens;
}
