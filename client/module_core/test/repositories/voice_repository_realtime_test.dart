import "dart:async";
import "dart:io" show WebSocketException;

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_client.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_protocol.dart";
import "package:test/test.dart";
import "package:web_socket_channel/web_socket_channel.dart";

import "../capabilities/voice/fake_realtime_voice_channel.dart";

class _MockVoiceApi() extends Mock implements VoiceApi;

class _ThrowingTokenProvider({required final Exception failure}) implements AuthTokenProvider {
  @override
  Future<String?> getFreshAccessToken({
    Duration minTtl = const Duration(seconds: 30),
    bool forceRefresh = false,
  }) async => throw failure;
}

void main() {
  late FakeRealtimeVoiceChannel channel;

  Future<VoiceRealtimeConnection> open({required String? token}) => VoiceRepository(
    api: _MockVoiceApi(),
    realtimeClient: RealtimeVoiceClient.withChannelConnector(
      tokenProvider: FakeRealtimeVoiceTokenProvider(token: token),
      channelConnector: ({required uri, required headers}) => channel,
    ),
  ).openRealtime(sampleRate: VoiceRealtimeSampleRate.hz16000, projectKey: null);

  Future<VoiceRealtimeConnection> openUpgraded() {
    channel.upgrade.complete();
    return open(token: "token");
  }

  /// Runs a connection through [frames] and returns everything it reported.
  Future<List<VoiceRealtimeEvent>> eventsFrom({required List<String> frames}) async {
    channel = FakeRealtimeVoiceChannel();
    final connection = await openUpgraded();
    final eventsDone = connection.events.toList();
    frames.forEach(channel.inbound.add);
    return await eventsDone;
  }

  setUp(() {
    channel = FakeRealtimeVoiceChannel();
  });

  group("open failures keep the original as the cause", () {
    /// Fails the upgrade the way `IOWebSocketChannel` does, with `open` already waiting.
    Future<Object> failureFrom({required Object upgradeError}) async {
      final opening = open(token: "token");
      await pumpEventQueue();
      channel.upgrade.completeError(upgradeError);
      try {
        await opening;
      } on Object catch (error) {
        return error;
      }
      fail("Expected openRealtime to throw");
    }

    Object rejection({required int status}) =>
        WebSocketChannelException.from(WebSocketException("Not upgraded", status));

    final rejected = isA<RealtimeVoiceUpgradeRejectedException>();

    test("no token is not authenticated", () async {
      await expectLater(
        open(token: null),
        throwsA(
          isA<NotAuthenticatedVoiceError>().having(
            (error) => error.innerError,
            "innerError",
            isA<RealtimeVoiceNotAuthenticatedException>(),
          ),
        ),
      );
    });

    test("a failed token read is a network error that keeps its cause", () async {
      final failure = Exception("storage locked");
      final repository = VoiceRepository(
        api: _MockVoiceApi(),
        realtimeClient: RealtimeVoiceClient(tokenProvider: _ThrowingTokenProvider(failure: failure)),
      );

      await expectLater(
        repository.openRealtime(sampleRate: VoiceRealtimeSampleRate.hz16000, projectKey: null),
        throwsA(
          isA<NetworkVoiceError>().having(
            (error) => error.innerError,
            "innerError",
            isA<RealtimeVoiceConnectionException>().having((exception) => exception.cause, "cause", failure),
          ),
        ),
      );
    });

    test("401 is not authenticated", () async {
      expect(
        await failureFrom(upgradeError: rejection(status: 401)),
        isA<NotAuthenticatedVoiceError>().having((error) => error.innerError, "innerError", rejected),
      );
    });

    test("404, which a disabled server answers, is a server error", () async {
      expect(
        await failureFrom(upgradeError: rejection(status: 404)),
        isA<ServerVoiceError>()
            .having((error) => error.statusCode, "statusCode", 404)
            .having((error) => error.innerError, "innerError", rejected),
      );
    });

    for (final status in [429, 503]) {
      test("$status is retryable", () async {
        expect(
          await failureFrom(upgradeError: rejection(status: status)),
          isA<RetryableServerVoiceError>()
              .having((error) => error.statusCode, "statusCode", status)
              .having((error) => error.innerError, "innerError", rejected),
        );
      });
    }

    test("a network failure is a network error", () async {
      final cause = WebSocketChannelException("offline");

      expect(
        await failureFrom(upgradeError: cause),
        isA<NetworkVoiceError>().having(
          (error) => error.innerError,
          "innerError",
          isA<RealtimeVoiceConnectionException>().having((exception) => exception.cause, "cause", same(cause)),
        ),
      );
    });
  });

  group("events", () {
    test("words pass through, and each complete reason maps to its outcome", () async {
      final cases = {
        "finished": VoiceDictationOutcome.finished,
        "session_limit": VoiceDictationOutcome.limitReached,
        "quota_limit": VoiceDictationOutcome.limitReached,
      };

      for (final MapEntry(key: reason, value: outcome) in cases.entries) {
        final events = await eventsFrom(
          frames: [
            '{"type":"ready","protocolVersion":1,"maxSessionSeconds":900,"dailySecondsRemaining":420}',
            '{"type":"transcript","confirmedDelta":"hello ","provisional":"wor"}',
            '{"type":"complete","reason":"$reason","dailySecondsRemaining":1}',
          ],
        );

        expect(events, [
          isA<VoiceRealtimeReady>(),
          isA<VoiceRealtimeWords>()
              .having((event) => event.confirmedDelta, "confirmedDelta", "hello ")
              .having((event) => event.provisional, "provisional", "wor"),
          isA<VoiceRealtimeCompleted>().having((event) => event.outcome, "outcome", outcome),
        ], reason: reason);
      }
    });

    test("every error code maps by its retryability, keeping the code as the cause", () async {
      for (final code in RealtimeVoiceErrorCode.values) {
        final events = await eventsFrom(
          frames: ['{"type":"error","code":"${code.wireName}","retryable":${code.retryable.toString()}}'],
        );

        final hasCode = isA<RealtimeVoiceErrorEvent>().having((event) => event.code, "code", code);
        expect(
          (events.single as VoiceRealtimeFailed).error,
          code.retryable
              ? isA<RetryableServerVoiceError>()
                    .having((error) => error.statusCode, "statusCode", code.closeCode)
                    .having((error) => error.innerError, "innerError", hasCode)
              : isA<ServerVoiceError>()
                    .having((error) => error.statusCode, "statusCode", code.closeCode)
                    .having((error) => error.innerError, "innerError", hasCode),
          reason: code.wireName,
        );
      }
    });

    test("a close without a terminal event is a network error, keeping the close code", () async {
      final connection = await openUpgraded();
      final eventsDone = connection.events.toList();

      channel.serverCloseCode = 1006;
      unawaited(channel.inbound.close());

      expect(
        ((await eventsDone).single as VoiceRealtimeFailed).error,
        isA<NetworkVoiceError>().having(
          (error) => error.innerError,
          "innerError",
          isA<RealtimeVoiceConnectionException>().having((exception) => exception.closeCode, "closeCode", 1006),
        ),
      );
    });

    test("a protocol violation is a server error, keeping the violation", () async {
      final events = await eventsFrom(frames: ['{"type":"paused"}']);

      expect(
        (events.single as VoiceRealtimeFailed).error,
        isA<ServerVoiceError>()
            .having((error) => error.statusCode, "statusCode", realtimeVoiceProtocolViolationCode)
            .having((error) => error.innerError, "innerError", isA<RealtimeVoiceProtocolException>()),
      );
    });
  });
}
