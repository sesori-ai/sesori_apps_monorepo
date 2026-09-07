import "dart:convert";

import "package:acp_plugin/acp_plugin.dart";
import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:test/test.dart";

void main() {
  const mapper = AntigravityStderrMapper();

  test("consumes OAuth URLs, callback access logs, credential fields and bearer values", () {
    for (final line in [
      "opening https://accounts.google.com/o/oauth2/v2/auth?state=synthetic",
      "redirect http://127.0.0.1:4321/?code=synthetic",
      'GET /?state=synthetic&code=synthetic HTTP/1.1',
      "Request body code=synthetic",
      '  "code": "synthetic",',
      "{'state': 'synthetic'}",
      '  "refresh_token": "synthetic",',
      "{'access_token': 'synthetic'}",
      "id_token=synthetic",
      '  "token": "synthetic",',
      "Token=synthetic",
      "token: synthetic",
      "code_verifier=synthetic",
      "client_secret=synthetic",
      "Authorization: Bearer synthetic",
      "authorization_response=https://example.invalid",
      "state%3Dsynthetic",
      "Open the following link to authenticate the ACP server: malformed",
      "token endpoint https://oauth2.googleapis.com/token?client_id=synthetic",
      "refresh-token: synthetic-secret",
    ]) {
      expect(mapper.consumeLine(line: utf8.encode(line)), isTrue, reason: line);
    }
  });

  test("retains useful non-sensitive auth, path, stack and process diagnostics", () {
    for (final line in [
      "Runtime failed at /opt/antigravity/localharness_external: permission denied",
      "Traceback (most recent call last):",
      '  File "/agent/oauth.py", line 123, in refresh',
      "Failed to refresh token. Interactive login required.",
      "Refusing to persist credentials without a refresh token; keeping any existing stored token.",
      "Credentials missing or invalid. Launching browser login flow...",
      "Could not open a browser automatically; open the URL manually.",
      "OAuth granted scopes are missing requested scopes",
      "process exited with code 1",
      "process exit code: 23",
      "connection state: failed",
      "DNS lookup failed for accounts.google.com",
      "TLS certificate error connecting to https://oauth2.googleapis.com/token",
      "Proxy connection refused for accounts.google.com",
      "HTTP 503 from https://oauth2.googleapis.com/token",
      "token endpoint https://oauth2.googleapis.com/token",
      "state changed",
    ]) {
      expect(mapper.consumeLine(line: utf8.encode(line)), isFalse, reason: line);
    }
  });

  test("chunk splitting, CRLF and final partial lines cannot leak OAuth fields", () async {
    final interceptor = AcpOutputInterceptor(maxLineBytes: 4096, consumeLine: mapper.consumeLine);
    final bytes = utf8.encode("useful\r\nstate=synthetic\r\nTraceback\ntoken=synthetic\nrefresh_token=synthetic");
    final output = await interceptor
        .intercept(bytes: Stream.fromIterable(bytes.map((byte) => [byte])))
        .transform(utf8.decoder)
        .join();
    expect(output, "useful\r\nTraceback\n");
  });

  test("oversize OAuth output fails without echoing payload", () async {
    final interceptor = AcpOutputInterceptor(maxLineBytes: 16, consumeLine: mapper.consumeLine);
    await expectLater(
      interceptor.intercept(bytes: Stream.value(utf8.encode("state=synthetic-secret-long"))).drain<void>(),
      throwsA(
        isA<AcpOutputInterceptionException>().having(
          (error) => error.toString(),
          "presentation",
          isNot(contains("synthetic")),
        ),
      ),
    );
  });
}
