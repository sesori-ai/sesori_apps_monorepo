import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";
import "token.dart";

const int _loginTimeoutSeconds = 120;

class _CallbackData {
  final String code;
  final String state;

  _CallbackData({required this.code, required this.state});
}

Uri _buildUri({required String base, required String path}) {
  final b = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
  return Uri.parse("$b/$path");
}

/// Opens the default browser to [url].
///
/// Platform-specific:
/// - macOS: `open`
/// - Linux: `xdg-open`
/// - Windows: `cmd /c start`
Future<void> _openBrowser(String url) async {
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

class LoginOAuthApi {
  final String authBackendUrl;
  final Future<void> Function(String url) browserLauncher;

  LoginOAuthApi({
    required this.authBackendUrl,
    this.browserLauncher = _openBrowser,
  });

  /// Generates a PKCE verifier and challenge pair.
  ///
  /// Returns `(verifier, challenge)` where:
  /// - verifier: 43 random bytes base64url-encoded (no padding)
  /// - challenge: SHA-256 of the verifier, base64url-encoded (no padding)
  @visibleForTesting
  (String, String) generatePKCE() {
    final random = Random.secure();
    final verifierBytes = Uint8List(43);
    for (var i = 0; i < 43; i++) {
      verifierBytes[i] = random.nextInt(256);
    }

    final verifier = base64Url.encode(verifierBytes).replaceAll("=", "");
    final challengeBytes = sha256.convert(utf8.encode(verifier)).bytes;
    final challenge = base64Url.encode(challengeBytes).replaceAll("=", "");

    return (verifier, challenge);
  }

  Future<AuthUrlResponse> _requestAuth({
    required AuthProvider provider,
    required String redirectUri,
    required String codeChallenge,
  }) async {
    final uri = _buildUri(base: authBackendUrl, path: provider.apiAuthPath).replace(
      queryParameters: {
        "redirect_uri": redirectUri,
        "code_challenge": codeChallenge,
        "code_challenge_method": "S256",
      },
    );

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        "init ${provider.label} auth failed: status ${response.statusCode}: ${response.body.trim()}",
      );
    }

    final initResp = AuthUrlResponse.fromJson(jsonDecodeMap(response.body));

    if (initResp.authUrl.isEmpty || initResp.state.isEmpty) {
      throw Exception("auth init response missing authUrl/state");
    }

    return initResp;
  }

  Future<(TokenData, String)> _exchangeCallback({
    required OAuthProvider provider,
    required String code,
    required String state,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final uri = _buildUri(base: authBackendUrl, path: provider.apiCallbackPath);

    final body = jsonEncode({
      "code": code,
      "codeVerifier": codeVerifier,
      "state": state,
      "redirectUri": redirectUri,
    });

    final response = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception(
        "callback exchange failed: status ${response.statusCode}: ${response.body.trim()}",
      );
    }

    final authResponse = AuthResponse.fromJson(jsonDecodeMap(response.body));

    if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
      throw Exception("callback response missing tokens");
    }

    return (
      TokenData(
        accessToken: authResponse.accessToken,
        refreshToken: authResponse.refreshToken,
        lastProvider: provider,
      ),
      authResponse.user.providerUsername ?? "",
    );
  }

  /// Starts the OAuth PKCE login flow.
  ///
  /// 1. Generates a PKCE verifier and challenge.
  /// 2. Starts a local HTTP server on `127.0.0.1:0` for the OAuth callback.
  /// 3. Requests the auth URL from the backend for the specified [provider].
  /// 4. Opens the browser to the auth URL.
  /// 5. Waits for the callback (120s timeout).
  /// 6. Verifies the state matches.
  /// 7. Exchanges the code for tokens.
  /// 8. Returns [TokenData].
  ///
  /// If the callback server fails to start, prints the URL for manual copy and
  /// throws an exception.
  ///
  Future<TokenData> performOAuthLogin(OAuthProvider provider) async {
    final (codeVerifier, codeChallenge) = generatePKCE();

    HttpServer server;
    try {
      server = await HttpServer.bind("127.0.0.1", 0);
    } catch (e) {
      Log.e("Failed to start local callback server: $e");
      const fallbackRedirectUri = "http://127.0.0.1/callback";
      try {
        final initResp = await _requestAuth(
          provider: provider,
          redirectUri: fallbackRedirectUri,
          codeChallenge: codeChallenge,
        );
        Log.i("Open this URL manually:");
        Log.i(initResp.authUrl);
      } catch (e) {
        Log.w("Failed to request fallback auth URL: $e");
      }
      Log.e(
        "Cannot complete browser login automatically without callback server.",
      );
      throw Exception("start callback server: $e");
    }

    final callbackCompleter = Completer<_CallbackData>();
    final port = server.port;
    final redirectUri = "http://127.0.0.1:$port/callback";

    server.listen((HttpRequest request) async {
      if (request.uri.path != "/callback") {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final code = request.uri.queryParameters["code"] ?? "";
      final state = request.uri.queryParameters["state"] ?? "";

      if (code.isEmpty || state.isEmpty) {
        request.response
          ..statusCode = HttpStatus.badRequest
          ..write("missing code or state");
        await request.response.close();
        return;
      }

      if (!callbackCompleter.isCompleted) {
        callbackCompleter.complete(_CallbackData(code: code, state: state));
      }

      request.response.headers.contentType = ContentType(
        "text",
        "html",
        charset: "utf-8",
      );
      request.response.write(
        "<html><body><h3>Login successful.</h3><p>You can close this tab and return to the CLI.</p></body></html>",
      );
      await request.response.close();
    });

    try {
      final initResp = await _requestAuth(
        provider: provider,
        redirectUri: redirectUri,
        codeChallenge: codeChallenge,
      );

      Log.i("Opening browser for ${provider.label} login...");
      try {
        await browserLauncher(initResp.authUrl);
      } catch (e) {
        Log.w("Could not open browser automatically: $e");
        Log.i("Open this URL manually:\n${initResp.authUrl}");
      }

      Log.i("Waiting for authorization...");

      final callback = await callbackCompleter.future.timeout(
        const Duration(seconds: _loginTimeoutSeconds),
        onTimeout: () => throw Exception("timed out waiting for authorization"),
      );

      if (callback.state != initResp.state) {
        throw Exception("oauth state mismatch");
      }

      final (tokens, username) = await _exchangeCallback(
        provider: provider,
        code: callback.code,
        state: callback.state,
        codeVerifier: codeVerifier,
        redirectUri: redirectUri,
      );

      if (username.isNotEmpty) {
        Log.i("Login successful! Welcome, $username");
      } else {
        Log.i("Login successful!");
      }

      return tokens;
    } finally {
      await server.close(force: true);
    }
  }
}
