import "dart:async";

import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/repositories/codex_authentication_repository.dart";
import "package:test/test.dart";

void main() {
  group("CodexAuthenticationRepository", () {
    test("retains the login id and ignores unrelated completions", () async {
      final transport = _AuthenticationTransport();
      final repository = CodexAuthenticationRepository(
        appServerApi: CodexAppServerApi(client: transport),
        requestTimeout: const Duration(seconds: 2),
      );

      final challenge = await repository.start();
      expect(challenge.verificationUri, Uri.https("auth.example", "/device"));
      expect(challenge.userCode, "PRIVATE-CODE");

      var completed = false;
      unawaited(
        repository.waitForCompletion().then((_) {
          completed = true;
        }),
      );
      transport.complete(loginId: "stale-login", success: true);
      await _eventLoop();
      expect(completed, isFalse);

      transport.complete(loginId: "private-login", success: true);
      await repository.waitForCompletion();
      expect(completed, isTrue);
      await repository.dispose();
    });

    test("preserves an upstream completion failure as the cause", () async {
      final transport = _AuthenticationTransport();
      final repository = CodexAuthenticationRepository(
        appServerApi: CodexAppServerApi(client: transport),
        requestTimeout: const Duration(seconds: 2),
      );
      await repository.start();

      transport.complete(
        loginId: "private-login",
        success: false,
        error: "private workspace policy detail",
      );

      await expectLater(
        repository.waitForCompletion(),
        throwsA(
          isA<CodexAuthenticationException>().having(
            (error) => error.cause,
            "cause",
            "private workspace policy detail",
          ),
        ),
      );
      await repository.dispose();
    });

    test("cancels only with the retained private login id", () async {
      final transport = _AuthenticationTransport();
      final repository = CodexAuthenticationRepository(
        appServerApi: CodexAppServerApi(client: transport),
        requestTimeout: const Duration(seconds: 2),
      );

      await repository.cancel();
      await repository.start();
      await repository.cancel();

      expect(transport.cancelLoginIds, ["private-login"]);
      expect(transport.timeouts, everyElement(const Duration(seconds: 2)));
      await repository.dispose();
    });

    test("rejects a non-HTTPS verification URL", () async {
      final transport = _AuthenticationTransport(
        verificationUrl: "http://auth.example/device",
      );
      final repository = CodexAuthenticationRepository(
        appServerApi: CodexAppServerApi(client: transport),
        requestTimeout: const Duration(seconds: 2),
      );

      await expectLater(
        repository.start(),
        throwsA(isA<CodexAuthenticationException>()),
      );
      await repository.dispose();
    });
  });
}

Future<void> _eventLoop() => Future<void>.delayed(Duration.zero);

class _AuthenticationTransport implements CodexAppServerTransport {
  _AuthenticationTransport({
    this.verificationUrl = "https://auth.example/device",
  });

  final String verificationUrl;
  final StreamController<CodexServerNotification> _notifications =
      StreamController<CodexServerNotification>.broadcast();
  final List<String> cancelLoginIds = <String>[];
  final List<Duration> timeouts = <Duration>[];

  @override
  Stream<CodexServerNotification> get notifications => _notifications.stream;

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    timeouts.add(timeout);
    if (method == "account/login/start") {
      return {
        "type": "chatgptDeviceCode",
        "loginId": "private-login",
        "verificationUrl": verificationUrl,
        "userCode": "PRIVATE-CODE",
      };
    }
    cancelLoginIds.add((params! as Map<String, dynamic>)["loginId"]! as String);
    return {"status": "canceled"};
  }

  void complete({
    required String loginId,
    required bool success,
    String? error,
  }) {
    _notifications.add(
      CodexServerNotification(
        method: "account/login/completed",
        params: {"loginId": loginId, "success": success, "error": error},
      ),
    );
  }
}
