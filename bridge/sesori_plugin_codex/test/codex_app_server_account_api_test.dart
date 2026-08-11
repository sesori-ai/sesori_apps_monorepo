import "dart:async";

import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/models/codex_account_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:test/test.dart";

void main() {
  group("CodexAppServerApi account operations", () {
    test("starts device login with a typed response", () async {
      final transport = _FakeTransport(
        responses: [
          {
            "type": "chatgptDeviceCode",
            "loginId": "login-private",
            "verificationUrl": "https://auth.example/device",
            "userCode": "CODE-PRIVATE",
          },
        ],
      );

      final response = await CodexAppServerApi(
        client: transport,
      ).startDeviceLogin();

      expect(response.type, CodexAccountLoginType.chatgptDeviceCode);
      expect(response.loginId, "login-private");
      expect(response.verificationUrl, "https://auth.example/device");
      expect(response.userCode, "CODE-PRIVATE");
      expect(transport.calls, hasLength(1));
      expect(transport.calls.single.method, "account/login/start");
      expect(transport.calls.single.params, {
        "type": "chatgptDeviceCode",
      });
    });

    test("rejects an unknown device login response type", () async {
      final api = CodexAppServerApi(
        client: _FakeTransport(
          responses: [
            {
              "type": "browser",
              "loginId": "login-private",
              "verificationUrl": "https://auth.example/device",
              "userCode": "CODE-PRIVATE",
            },
          ],
        ),
      );

      await expectLater(api.startDeviceLogin(), throwsA(isA<ArgumentError>()));
    });

    test("cancels by private login id and preserves unknown statuses", () async {
      final transport = _FakeTransport(
        responses: [
          {"status": "notFound"},
          {"status": "futureStatus"},
        ],
      );
      final api = CodexAppServerApi(client: transport);

      final missing = await api.cancelLogin(loginId: "login-private");
      final future = await api.cancelLogin(loginId: "login-private");

      expect(missing.status, CodexAccountLoginCancelStatus.notFound);
      expect(future.status, CodexAccountLoginCancelStatus.unknown);
      expect(
        transport.calls.map((call) => call.params),
        everyElement(<String, dynamic>{"loginId": "login-private"}),
      );
    });

    test("decodes only account login completion notifications", () async {
      final transport = _FakeTransport(responses: const []);
      final completions = CodexAppServerApi(
        client: transport,
      ).accountLoginCompletions;
      final completionFuture = completions.first;

      transport.notificationsController.add(
        const CodexServerNotification(method: "account/updated", params: {}),
      );
      transport.notificationsController.add(
        const CodexServerNotification(
          method: "account/login/completed",
          params: {
            "loginId": "login-private",
            "success": false,
            "error": "private upstream error",
          },
        ),
      );

      final completion = await completionFuture;
      expect(completion.loginId, "login-private");
      expect(completion.success, isFalse);
      expect(completion.error, "private upstream error");
      await transport.dispose();
    });

    test("rejects malformed completion payloads", () async {
      final transport = _FakeTransport(responses: const []);
      final completionFuture = CodexAppServerApi(
        client: transport,
      ).accountLoginCompletions.first;

      transport.notificationsController.add(
        const CodexServerNotification(
          method: "account/login/completed",
          params: {"loginId": null, "success": "yes", "error": null},
        ),
      );

      await expectLater(completionFuture, throwsA(isA<TypeError>()));
      await transport.dispose();
    });
  });
}

typedef _TransportCall = ({String method, Object? params});

class _FakeTransport implements CodexAppServerTransport {
  _FakeTransport({required List<Object?> responses}) : _responses = List<Object?>.of(responses);

  final List<Object?> _responses;
  final List<_TransportCall> calls = <_TransportCall>[];
  final StreamController<CodexServerNotification> notificationsController =
      StreamController<CodexServerNotification>.broadcast();

  @override
  Stream<CodexServerNotification> get notifications => notificationsController.stream;

  @override
  Future<dynamic> request({
    required String method,
    Object? params,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    calls.add((method: method, params: params));
    return _responses.removeAt(0);
  }

  Future<void> dispose() => notificationsController.close();
}
