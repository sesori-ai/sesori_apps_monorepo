import "dart:async";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "login_oauth_api.dart";
import "token.dart";

const int _loginTimeoutSeconds = 120;
const Duration _defaultPollInterval = Duration(milliseconds: 250);
const Duration _defaultPollTimeout = Duration(seconds: _loginTimeoutSeconds);

/// Opens the default browser to [url].
///
/// Platform-specific:
/// - macOS: `open`
/// - Linux: `xdg-open`
/// - Windows: `cmd /c start`
Future<void> openOAuthBrowser(String url) async {
  if (Platform.isMacOS) {
    await Process.run("open", [url]);
  } else if (Platform.isLinux) {
    await Process.run("xdg-open", [url]);
  } else if (Platform.isWindows) {
    await Process.run("cmd", ["/c", "start", url]);
  } else {
    throw UnsupportedError("Unsupported platform: ${Platform.operatingSystem}");
  }
}

class LoginOAuthService {
  final LoginOAuthApi _api;
  final Future<void> Function(String url) _browserLauncher;
  final Duration _pollInterval;
  final Duration _pollTimeout;
  final Future<void> Function(Duration duration) _delay;

  LoginOAuthService({
    required LoginOAuthApi api,
    required Future<void> Function(String url) browserLauncher,
    @visibleForTesting Duration pollInterval = _defaultPollInterval,
    @visibleForTesting Duration pollTimeout = _defaultPollTimeout,
    @visibleForTesting Future<void> Function(Duration duration)? delay,
  }) : _api = api,
       _browserLauncher = browserLauncher,
       _pollInterval = pollInterval,
       _pollTimeout = pollTimeout,
       _delay = delay ?? Future<void>.delayed;

  /// Starts the OAuth login flow through the auth backend's pending-session API.
  ///
  /// The temporary session token is generated in memory, sent only through the
  /// `X-Sesori-Session-Token` header, and never persisted or placed in URLs.
  Future<TokenData> performOAuthLogin(OAuthProvider provider) async {
    final sessionToken = _generateSessionToken();
    final initResp = await _api.initOAuthSession(
      provider: provider,
      sessionToken: sessionToken,
    );

    Log.i("Opening browser for ${provider.label} login...");
    try {
      await _browserLauncher(initResp.authUrl);
    } catch (e) {
      Log.w("Could not open browser automatically: $e");
      Log.i("Open this URL manually:\n${initResp.authUrl}");
    }

    Log.i("Waiting for authorization...");
    return _pollForCompletion(provider: provider, sessionToken: sessionToken);
  }

  Future<TokenData> _pollForCompletion({
    required OAuthProvider provider,
    required String sessionToken,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      while (stopwatch.elapsed < _pollTimeout) {
        final remaining = _pollTimeout - stopwatch.elapsed;
        final status = await _api.getOAuthSessionStatus(sessionToken: sessionToken).timeout(remaining);

        switch (status) {
          case AuthSessionStatusResponsePending():
            final delay = _pollInterval < remaining ? _pollInterval : remaining;
            if (delay > Duration.zero) {
              await _delay(delay);
            }
          case AuthSessionStatusResponseComplete(:final accessToken, :final refreshToken, :final user):
            if (accessToken.isEmpty || refreshToken.isEmpty) {
              throw Exception("auth session response missing tokens");
            }
            final username = user.providerUsername ?? "";
            if (username.isNotEmpty) {
              Log.i("Login successful! Welcome, $username");
            } else {
              Log.i("Login successful!");
            }
            return TokenData(
              accessToken: accessToken,
              refreshToken: refreshToken,
              lastProvider: provider,
            );
          case AuthSessionStatusResponseDenied():
            throw Exception("authorization denied");
          case AuthSessionStatusResponseExpired():
            throw Exception("authorization expired");
          case AuthSessionStatusResponseError(:final message):
            throw Exception("authorization failed: $message");
        }
      }

      throw TimeoutException("timed out waiting for authorization", _pollTimeout);
    } finally {
      stopwatch.stop();
    }
  }

  String _generateSessionToken() {
    final random = Random.secure();
    final bytes = Uint8List(32);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }

    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, "0")).join();
  }
}
