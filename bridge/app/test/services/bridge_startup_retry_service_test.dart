import "dart:async";
import "dart:io";

import "package:fake_async/fake_async.dart";
import "package:http/http.dart" as http;
import "package:sesori_bridge/src/auth/auth_api.dart";
import "package:sesori_bridge/src/auth/token_refresher.dart";
import "package:sesori_bridge/src/services/bridge_startup_retry_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

void main() {
  test("retries every minute without a limit and resumes when the server returns", () {
    fakeAsync((time) {
      final service = BridgeStartupRetryService();
      var attempts = 0;
      String? result;
      service
          .run(
            operation: () async {
              if (++attempts <= 12) throw http.ClientException("Failed host lookup");
              return "online";
            },
          )
          .then((value) => result = value);
      time.flushMicrotasks();
      expect(service.states.value, ControlStartupState.waitingForServer);
      for (var i = 0; i < 12; i++) {
        time.elapse(const Duration(seconds: 59));
        expect(attempts, i + 1);
        time.elapse(const Duration(seconds: 1));
        expect(attempts, i + 2);
      }
      expect(result, "online");
      expect(service.states.value, ControlStartupState.starting);
      service.markReady();
      expect(service.states.value, ControlStartupState.ready);
      unawaited(service.dispose());
      time.flushMicrotasks();
      expect(time.pendingTimers, isEmpty);
    });
  });

  test("cancellation wakes the retry immediately and removes its timer", () {
    fakeAsync((time) {
      final service = BridgeStartupRetryService();
      Object? failure;
      var attempts = 0;
      service
          .run<void>(
            operation: () async {
              attempts++;
              throw const SocketException("offline");
            },
          )
          .then<void>(
            (_) {},
            onError: (Object error) {
              failure = error;
            },
          );
      time.flushMicrotasks();
      service.cancel();
      time.flushMicrotasks();
      expect(failure, isA<PluginStartAbortedException>());
      expect(time.pendingTimers, isEmpty);
      time.elapse(const Duration(minutes: 5));
      expect(attempts, 1);
      unawaited(service.dispose());
      time.flushMicrotasks();
    });
  });

  for (final error in <Object>[
    TimeoutException("deadline"),
    http.RequestAbortedException(Uri.parse("https://auth.test")),
    WebSocketChannelException.from(const SocketException("offline")),
    WebSocketChannelException.from(const WebSocketException("Service unavailable", 503)),
    const ControlTokenRetryLaterException(innerError: null),
    AuthApiException(method: "GET", uri: Uri.parse("https://auth.test"), statusCode: 503, body: ""),
    BridgeRegistrationException(statusCode: 429, body: ""),
  ]) {
    test("waits for transient ${error.runtimeType}", () {
      fakeAsync((time) {
        final service = BridgeStartupRetryService();
        var attempts = 0;
        service.run<void>(
          operation: () async {
            if (++attempts == 1) throw error;
          },
        );
        time.flushMicrotasks();
        expect(
          service.states.value,
          error is ControlTokenRetryLaterException
              ? ControlStartupState.waitingForAuthentication
              : ControlStartupState.waitingForServer,
        );
        time.elapse(const Duration(minutes: 1));
        expect(attempts, 2);
        unawaited(service.dispose());
        time.flushMicrotasks();
      });
    });
  }

  for (final error in <Object>[
    StateError("configuration"),
    const FormatException("malformed response"),
    const WebSocketException("Not found", 404),
    const WebSocketException("Invalid upgrade"),
    const HandshakeException("Certificate verification failed"),
    const FileSystemException("permission denied"),
    const ControlTokenUnavailableException("signed out"),
    AuthApiException(method: "GET", uri: Uri.parse("https://auth.test"), statusCode: 401, body: ""),
  ]) {
    test("preserves non-network ${error.runtimeType} failures", () async {
      final service = BridgeStartupRetryService();
      addTearDown(service.dispose);
      await expectLater(service.run<void>(operation: () async => throw error), throwsA(same(error)));
    });
  }
}
