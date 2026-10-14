import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/mcp_api.dart";
import "package:sesori_dart_core/src/repositories/mcp_repository.dart";
import "package:sesori_dart_core/src/repositories/models/mcp_authentication_response.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const _attempt = McpAuthenticationAttempt(
  attemptId: "fixture",
  pluginId: "fixture",
  target: McpServerTarget(
    scope: McpSessionScope(sessionId: "session"),
    serverKey: "server",
  ),
  cancellation: McpAuthenticationCancellation.cancelable,
);

class _Api({required ApiResponse<McpAuthenticationResult> response}) implements McpApi {
  ApiResponse<McpAuthenticationResult> response = response;
  @override
  Future<ApiResponse<McpAuthenticationResult>> getAuthentication() async => response;
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test("authentication keeps unknown native results and original request errors distinct", () async {
    final api = _Api(response: SuccessResponse(const McpAuthenticationResultUnknown()));
    final repository = McpRepository(api: api);
    expect(
      (await repository.getAuthentication() as McpAuthenticationReceived).result,
      isA<McpAuthenticationResultUnknown>(),
    );
    final missing = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Missing route");
    api.response = ErrorResponse(missing);
    expect((await repository.getAuthentication() as McpAuthenticationRouteMissing).cause, same(missing));
    final failure = ApiError.generic();
    api.response = ErrorResponse(failure);
    expect((await repository.getAuthentication() as McpAuthenticationRequestFailed).cause, same(failure));
  });
  test("browser destinations require HTTPS and exact loopback HTTP callbacks", () {
    final repository = McpRepository(api: _Api(response: SuccessResponse(const McpAuthenticationResultUnknown())));
    for (final authorization in [
      "/relative",
      "http://fixture.example/authorize",
      "file:///fixture",
      "javascript:fixture",
      "https://user@fixture.example/authorize",
    ]) {
      expect(
        repository.browserChallenge(
          state: McpAuthenticationCallbackChallenge(
            attempt: _attempt,
            authorizationUrl: authorization,
            expectedCallbackUrl: "http://127.0.0.1:43120/callback",
          ),
        ),
        isNull,
        reason: authorization,
      );
    }
    for (final callback in [
      "/callback",
      "https://127.0.0.1/callback",
      "http://fixture.example/callback",
      "http://user@127.0.0.1/callback",
      "http://127.0.0.1/callback#fragment",
      "http://127.0.0.1:0/callback",
    ]) {
      expect(
        repository.browserChallenge(
          state: McpAuthenticationCallbackChallenge(
            attempt: _attempt,
            authorizationUrl: "https://fixture.example/authorize",
            expectedCallbackUrl: callback,
          ),
        ),
        isNull,
        reason: callback,
      );
    }
    for (final host in ["127.0.0.1", "localhost", "[::1]"]) {
      final challenge = repository.browserChallenge(
        state: McpAuthenticationCallbackChallenge(
          attempt: _attempt,
          authorizationUrl: "https://fixture.example/authorize",
          expectedCallbackUrl: "http://$host:43120/callback",
        ),
      );
      expect(challenge, isNotNull, reason: host);
      expect(challenge.toString(), isNot(contains("fixture.example")));
    }
  });
}
