import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";
import "dart:typed_data";

import "package:crypto/crypto.dart";
import "package:http/http.dart" as http;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "token.dart";

const int _loginTimeoutSeconds = 120;

class _CallbackData {
  final String code;
  final String state;

  _CallbackData({required this.code, required this.state});
}

Uri _buildUri(String base, String path) {
  final b = base.endsWith("/") ? base.substring(0, base.length - 1) : base;
  return Uri.parse("$b/$path");
}

/// Generates a PKCE verifier and challenge pair.
///
/// Returns `(verifier, challenge)` where:
/// - verifier: 43 random bytes base64url-encoded (no padding)
/// - challenge: SHA-256 of the verifier, base64url-encoded (no padding)
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

/// Opens the default browser to [url].
///
/// Platform-specific:
/// - macOS: `open`
/// - Linux: `xdg-open`
/// - Windows: `cmd /c start`
Future<void> openBrowser(String url) async {
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

Future<AuthUrlResponse> _requestGitHubAuth(
  String authBackendURL,
  String redirectUri,
  String codeChallenge,
) async {
  final uri = _buildUri(authBackendURL, "auth/github").replace(
    queryParameters: {
      "redirect_uri": redirectUri,
      "code_challenge": codeChallenge,
      "code_challenge_method": "S256",
    },
  );

  final response = await http.get(uri);

  if (response.statusCode != 200) {
    throw Exception(
      "init github auth failed: status ${response.statusCode}: ${response.body.trim()}",
    );
  }

  final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
  final initResp = AuthUrlResponse.fromJson(jsonBody);

  if (initResp.authUrl.isEmpty || initResp.state.isEmpty) {
    throw Exception("auth init response missing authUrl/state");
  }

  return initResp;
}

Future<(TokenData, String)> _exchangeCallback(
  String authBackendURL,
  String code,
  String state,
  String codeVerifier,
  String redirectUri,
) async {
  final uri = _buildUri(authBackendURL, "auth/github/callback");

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

  final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
  final authResponse = AuthResponse.fromJson(jsonBody);

  if (authResponse.accessToken.isEmpty || authResponse.refreshToken.isEmpty) {
    throw Exception("callback response missing tokens");
  }

  return (
    TokenData(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    ),
    authResponse.user.providerUsername ?? "",
  );
}

/// Starts the OAuth PKCE login flow.
///
/// 1. Generates a PKCE verifier and challenge.
/// 2. Starts a local HTTP server on `127.0.0.1:0` for the OAuth callback.
/// 3. Requests the GitHub auth URL from the backend.
/// 4. Opens the browser to the auth URL.
/// 5. Waits for the callback (120s timeout).
/// 6. Verifies the state matches.
/// 7. Exchanges the code for tokens.
/// 8. Returns [TokenData].
///
/// If the callback server fails to start, prints the URL for manual copy and
/// throws an exception.
Future<TokenData> login(String authBackendURL) async {
  final (codeVerifier, codeChallenge) = generatePKCE();

  HttpServer server;
  try {
    server = await HttpServer.bind("127.0.0.1", 0);
  } catch (e) {
    Log.e("Failed to start local callback server: $e");
    const fallbackRedirectUri = "http://127.0.0.1/callback";
    try {
      final initResp = await _requestGitHubAuth(
        authBackendURL,
        fallbackRedirectUri,
        codeChallenge,
      );
      Log.i("Open this URL manually:");
      Log.i(initResp.authUrl);
    } catch (_) {}
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
    final initResp = await _requestGitHubAuth(
      authBackendURL,
      redirectUri,
      codeChallenge,
    );

    Log.i("Opening browser for GitHub login...");
    try {
      await openBrowser(initResp.authUrl);
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
      authBackendURL,
      callback.code,
      callback.state,
      codeVerifier,
      redirectUri,
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
