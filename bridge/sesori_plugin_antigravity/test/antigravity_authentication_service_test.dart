import "dart:async";

import "package:antigravity_plugin/antigravity_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

Uri authorizationUri({required String query}) => Uri.parse(
  "https://accounts.google.com/o/oauth2/v2/auth?$query",
);

const query = "state=synthetic-state&redirect_uri=http%3A%2F%2F127.0.0.1%3A8765%2F&response_type=code";

class _Repository() implements AntigravityAuthenticationRepository {
  final sent = <Uri>[];
  AntigravityCallbackResult result = const AntigravityCallbackAccepted();
  @override
  Future<AntigravityCallbackResult> forward({
    required Uri callbackUri,
    required AntigravityAuthenticationBudget budget,
  }) async {
    sent.add(callbackUri);
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Repository repository;
  late AntigravityAuthenticationService service;
  setUp(() {
    repository = _Repository();
    service = AntigravityAuthenticationService(repository: repository);
  });

  test("validates only exact Google authorization and explicit loopback root", () {
    final good = authorizationUri(query: query);
    final valid = service.validateAuthorization(authorizationUri: good);
    expect(valid.callbackUri, Uri.parse("http://127.0.0.1:8765/"));
    expect(valid.state, "synthetic-state");
    expect(valid.toString(), isNot(contains("synthetic-state")));
    for (final invalid in [
      good.replace(scheme: "http"),
      good.replace(host: "accounts.google.com.evil.invalid"),
      good.replace(userInfo: "user"),
      good.replace(port: 444),
      good.replace(fragment: ""),
      good.replace(path: "/o/oauth2/auth"),
      Uri.parse("/o/oauth2/v2/auth?$query"),
      authorizationUri(query: "$query&state=other"),
      authorizationUri(query: "$query&redirect_uri=other"),
      authorizationUri(query: "$query&response_type=code"),
      authorizationUri(query: query.replaceFirst("synthetic-state", "")),
      authorizationUri(query: query.replaceFirst("synthetic-state", "a%20b")),
      authorizationUri(query: query.replaceFirst("synthetic-state", "x" * 513)),
      authorizationUri(query: query.replaceFirst("response_type=code", "response_type=token")),
      authorizationUri(query: "$query&padding=${"x" * 16384}"),
      for (final redirect in [
        "http://localhost:8765/",
        "https://127.0.0.1:8765/",
        "http://127.0.0.1/",
        "http://127.0.0.1:80/",
        "http://127.0.0.1:65536/",
        "http://127.0.0.1:08765/",
        "http://127.0.0.1:8765/path",
        "http://127.0.0.1:8765/?x=y",
        "http://127.0.0.1:8765/#",
      ])
        authorizationUri(
          query: "state=synthetic-state&response_type=code&redirect_uri=${Uri.encodeComponent(redirect)}",
        ),
    ]) {
      expect(
        () => service.validateAuthorization(authorizationUri: invalid),
        throwsA(isA<AntigravityAuthenticationException>()),
      );
    }
  });

  test("rejects invalid endpoint, state, code and issuer before any HTTP", () async {
    final issued = service.validateAuthorization(authorizationUri: authorizationUri(query: query));
    final good = Uri.parse("http://127.0.0.1:8765/?state=synthetic-state&code=synthetic-code");
    for (final invalid in [
      good.replace(scheme: "https"),
      good.replace(host: "localhost"),
      good.replace(host: "evil.invalid"),
      good.replace(port: 8766),
      good.replace(path: "/other"),
      good.replace(userInfo: "user"),
      good.replace(fragment: ""),
      good.replace(query: "code=synthetic-code"),
      good.replace(query: "state=wrong&code=synthetic-code"),
      good.replace(query: "state=synthetic-state"),
      good.replace(query: "state=synthetic-state&code="),
      good.replace(query: "state=synthetic-state&code=a%20b"),
      Uri.parse("$good&state=synthetic-state"),
      Uri.parse("$good&code=other"),
      Uri.parse("$good&error=denied"),
      Uri.parse("$good&iss=https://evil.invalid"),
      Uri.parse("$good&iss=https://accounts.google.com&iss=https://accounts.google.com"),
      Uri.parse("$good&padding=${"x" * 4096}"),
    ]) {
      await expectLater(
        service.submitRedirect(
          authorization: issued,
          redirectUri: invalid,
          budget: AntigravityAuthenticationBudget(
            timeout: const Duration(seconds: 2),
            abortSignal: StartAbortSignal.never,
          ),
        ),
        throwsA(isA<AntigravityAuthenticationException>()),
      );
    }
    expect(repository.sent, isEmpty);
    await service.submitRedirect(
      authorization: issued,
      redirectUri: Uri.parse("$good&iss=https://accounts.google.com"),
      budget: AntigravityAuthenticationBudget(timeout: const Duration(seconds: 2), abortSignal: StartAbortSignal.never),
    );
    expect(repository.sent, hasLength(1));
  });

  test("HTTP rejection retains safe status context and expired budgets prevent forwarding", () async {
    final issued = service.validateAuthorization(authorizationUri: authorizationUri(query: query));
    final callback = Uri.parse("http://127.0.0.1:8765/?state=synthetic-state&code=synthetic-code");
    repository.result = const AntigravityCallbackRejected(statusCode: 302);
    await expectLater(
      service.submitRedirect(
        authorization: issued,
        redirectUri: callback,
        budget: AntigravityAuthenticationBudget(
          timeout: const Duration(seconds: 2),
          abortSignal: StartAbortSignal.never,
        ),
      ),
      throwsA(
        isA<AntigravityAuthenticationException>().having((error) => error.toString(), "safe status", contains("302")),
      ),
    );
    await expectLater(
      service.submitRedirect(
        authorization: issued,
        redirectUri: callback,
        budget: AntigravityAuthenticationBudget(timeout: Duration.zero, abortSignal: StartAbortSignal.never),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(repository.sent, hasLength(1));
  });
}
