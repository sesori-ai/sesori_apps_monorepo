import "dart:async";
import "dart:convert";

import "package:clock/clock.dart";
import "package:cryptography/cryptography.dart";
import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/bridge/sse/sse_manager.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late TestRelayServer connectionServer;
  late RelayClient connectionOwner;

  setUpAll(() async {
    connectionServer = await TestRelayServer.start();
    connectionOwner = RelayClient(
      relayURL: "ws://127.0.0.1:${connectionServer.port}",
      accessTokenProvider: FakeAccessTokenProvider(""),
      bridgeIdProvider: FakeBridgeIdProvider(),
    );
    _testRelayConnection = await connectionOwner.connect();
    await connectionServer.nextClient();
  });

  tearDownAll(() async {
    await connectionOwner.closeIfCurrent(connection: _testRelayConnection);
    await connectionServer.close();
  });

  group("SSEManager", () {
    test("subscribe registers subscribers", () {
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

      manager.subscribeForTest(1, relayClient);
      manager.subscribeForTest(2, relayClient);
      addTearDown(manager.stop);

      expect(manager.subscriberCount, equals(2));
    });

    test("enqueueEvent with no subscribers does nothing", () async {
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      final client = _RecordingRelayClient();
      manager.setRoomKey(makeRoomKey());

      manager.enqueueEvent(_event("none"));
      await _pumpEventLoop();

      expect(client.sentConnIDs, isEmpty);
    });

    test("enqueueEvent delivers typed payload envelope to all subscribers", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribeForTest(1, client);
      manager.subscribeForTest(2, client);

      final event = _event("repo-a");
      manager.enqueueEvent(event);

      await _waitForSendCount(client, 2);

      expect(client.sentConnIDs, containsAll([1, 2]));

      final firstEnvelope = await _decryptEnvelope(client.sentPayloads.first, roomKey);
      final secondEnvelope = await _decryptEnvelope(client.sentPayloads.last, roomKey);

      // Wire format: RelayMessage.sseEvent wrapping the serialized SSE payload.
      final firstMsg = RelayMessage.fromJson(firstEnvelope);
      final secondMsg = RelayMessage.fromJson(secondEnvelope);
      expect(firstMsg, isA<RelaySseEvent>());
      expect(secondMsg, isA<RelaySseEvent>());

      // Wire format: OpenCode envelope {"payload":{"type":"...","properties":{...}}}
      // so the mobile's _onSseData can extract properties and call SseEventData.fromJson.
      final eventJson = event.toJson();
      final expectedData = jsonEncode({
        'payload': {
          'type': eventJson['type'],
          'properties': (Map<String, dynamic>.from(eventJson)..remove('type')),
        },
      });
      expect((firstMsg as RelaySseEvent).data, equals(expectedData));
      expect((secondMsg as RelaySseEvent).data, equals(expectedData));
    });

    test("without room key events are not sent", () async {
      final client = _RecordingRelayClient();
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      addTearDown(manager.stop);

      manager.subscribeForTest(7, client);
      manager.enqueueEvent(_event("repo-x"));
      await _pumpEventLoop();

      expect(client.sentConnIDs, isEmpty);
    });

    test("non-last unsubscribe creates orphan queue", () {
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      addTearDown(manager.stop);

      manager.subscribeForTest(1, relayClient);
      manager.subscribeForTest(2, relayClient);
      manager.unsubscribe(1);

      expect(manager.subscriberCount, equals(1));
      expect(manager.pendingReplayCount, equals(1));
    });

    test("last unsubscribe creates orphan queue", () {
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );
      addTearDown(manager.stop);

      manager.subscribeForTest(1, relayClient);
      manager.unsubscribe(1);

      expect(manager.subscriberCount, equals(0));
      expect(manager.pendingReplayCount, equals(1));
    });

    test("single subscriber reconnect replays buffered events", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      // Phone connects and receives one event.
      manager.subscribeForTest(1, client);
      manager.enqueueEvent(_event("event-a"));
      await _waitForSendCount(client, 1);
      expect(client.sentConnIDs, [1]);

      // Phone disconnects — only subscriber, queue should become orphan.
      manager.unsubscribe(1);
      expect(manager.pendingReplayCount, equals(1));

      // Events arriving while phone is away are buffered in the orphan queue.
      manager.enqueueEvent(_event("event-b"));
      manager.enqueueEvent(_event("event-c"));

      // Phone reconnects with a new connID (relay assigns fresh IDs).
      manager.subscribeForTest(5, client);
      await _waitForSendCount(client, 3);

      // The two buffered events were replayed to the new connID.
      expect(client.sentConnIDs[1], equals(5));
      expect(client.sentConnIDs[2], equals(5));
      expect(manager.pendingReplayCount, equals(0));
    });

    test("orphan queue replays to next subscriber within replay window", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribeForTest(1, client);
      manager.subscribeForTest(2, client);

      manager.enqueueEvent(_event("event-a"));
      await _waitForSendCount(client, 2);

      manager.unsubscribe(1);
      manager.enqueueEvent(_event("event-b"));
      await _waitForSendCount(client, 3);

      manager.subscribeForTest(3, client);
      await _waitForSendCount(client, 4);

      expect(client.sentConnIDs[3], equals(3));
      expect(manager.pendingReplayCount, equals(0));
    });

    test("expired orphan queue is discarded on subscribe", () async {
      var now = DateTime(2025, 1, 1);
      final fakeClock = Clock(() => now);

      await withClock(fakeClock, () async {
        final roomKey = makeRoomKey();
        final client = _RecordingRelayClient();
        final manager = SSEManager(
          replayWindow: SSEManager.defaultReplayWindow,
          onBytesSent: (_) {},
          failureReporter: FakeFailureReporter(),
        );
        manager.setRoomKey(roomKey);
        addTearDown(manager.stop);

        manager.subscribeForTest(1, client);
        manager.subscribeForTest(2, client);

        manager.unsubscribe(1);
        manager.enqueueEvent(_event("queued-for-orphan"));
        await _waitForSendCount(client, 1);

        now = now.add(SSEManager.defaultReplayWindow + const Duration(seconds: 1));
        final sendsBefore = client.sentConnIDs.length;

        manager.subscribeForTest(3, client);
        await _pumpEventLoop();

        expect(client.sentConnIDs.length, equals(sendsBefore));
        expect(manager.pendingReplayCount, equals(0));
      });
    });

    test("orphanAll moves all subscribers to orphan state", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribeForTest(1, client);
      manager.subscribeForTest(2, client);

      manager.enqueueEvent(_event("before-orphan"));
      await _waitForSendCount(client, 2);

      // Simulate relay disconnect — all subscribers become orphans.
      manager.orphanAll();
      expect(manager.subscriberCount, equals(0));
      expect(manager.pendingReplayCount, equals(2));

      // Events arriving during relay reconnect are buffered.
      manager.enqueueEvent(_event("during-reconnect"));

      // First phone reconnects — picks up orphan with buffered event.
      manager.subscribeForTest(3, client);
      await _waitForSendCount(client, 3);
      expect(client.sentConnIDs[2], equals(3));
      expect(manager.pendingReplayCount, equals(1));

      // Second phone reconnects.
      manager.subscribeForTest(4, client);
      await _waitForSendCount(client, 4);
      expect(client.sentConnIDs[3], equals(4));
      expect(manager.pendingReplayCount, equals(0));
    });

    test("stale relay delivery remains buffered for replay", () async {
      final client = _RecordingRelayClient()..nextOutcome = RelaySendOutcome.stale;
      final reporter = CapturingFailureReporter();
      final sentByteCounts = <int>[];
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: sentByteCounts.add,
        failureReporter: reporter,
      );
      manager.setRoomKey(makeRoomKey());
      addTearDown(manager.stop);

      manager.subscribeForTest(1, client);
      manager.enqueueEvent(_event("relay-turnover"));
      await _waitForSendCount(client, 1);
      expect(manager.subscriberCount, 0);
      expect(manager.pendingReplayCount, 1);

      for (var index = 0; index < 5; index++) {
        manager.enqueueEvent(_event("buffered-$index"));
      }

      client.nextOutcome = RelaySendOutcome.sent;
      manager.subscribeForTest(2, client);
      await _waitForSendCount(client, 7);

      expect(client.sentConnIDs, [1, 2, 2, 2, 2, 2, 2]);
      expect(sentByteCounts, hasLength(6), reason: "the rejected stale attempt must not count bandwidth");
      expect(reporter.recordedIdentifiers, isEmpty);
    });

    test("stale callback cannot unsubscribe a successor reusing the connection id", () async {
      final client = _RecordingRelayClient()..nextOutcome = RelaySendOutcome.stale;
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      manager.setRoomKey(makeRoomKey());
      addTearDown(manager.stop);

      manager.subscribeForTest(1, client);
      client.onNextSend = () {
        client.onNextSend = null;
        manager.orphanAll();
        manager.subscribeForTest(1, client);
        client.nextOutcome = RelaySendOutcome.sent;
      };
      manager.enqueueEvent(_event("reused-connection-id"));
      await _waitForSendCount(client, 2);

      expect(manager.subscriberCount, 1);
      expect(manager.pendingReplayCount, 0);
      expect(client.sentConnIDs, [1, 1]);
    });

    test("stop clears subscribers and orphan queues", () {
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: FakeFailureReporter(),
      );
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

      manager.subscribeForTest(1, relayClient);
      manager.subscribeForTest(2, relayClient);
      manager.unsubscribe(1);

      manager.stop();

      expect(manager.subscriberCount, equals(0));
      expect(manager.pendingReplayCount, equals(0));
    });

    test("EventQueue onError callback reports failure when send function throws", () async {
      final roomKey = makeRoomKey();
      final throwingClient = _ThrowingRelayClient();
      final failureReported = Completer<void>();
      final capturingReporter = _CompletingFailureReporter(reported: failureReported);
      final manager = SSEManager(
        replayWindow: SSEManager.defaultReplayWindow,
        onBytesSent: (_) {},
        failureReporter: capturingReporter,
      );
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribeForTest(42, throwingClient);
      manager.enqueueEvent(_event("repo-err"));

      // Wait for the send function to throw and the onError callback to fire.
      await failureReported.future.timeout(const Duration(seconds: 5));

      expect(
        capturingReporter.recordedIdentifiers,
        contains("sse_send_failure:42"),
      );
    });
  });
}

SesoriSseEvent _event(String worktree) {
  return SesoriSseEvent.projectsSummary(
    projects: [
      ProjectActivitySummary(
        id: worktree,
        activeSessions: [const ActiveSession(id: "s1", mainAgentRunning: false, childSessionIds: [])],
      ),
    ],
  );
}

Future<Map<String, dynamic>> _decryptEnvelope(
  List<int> framed,
  List<int> roomKey,
) async {
  final crypto = RelayCryptoService();
  final decryptor = crypto.createSessionEncryptor(SecretKey(roomKey));
  final decrypted = await unframe(framed, encryptor: decryptor);
  return jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
}

Future<void> _waitForSendCount(_RecordingRelayClient client, int count) async {
  if (client.sentConnIDs.length >= count) return;
  // The recording client emits per recorded send, so the wait is event-driven
  // instead of polling on a real clock.
  final reached = Completer<void>();
  late final StreamSubscription<int> sub;
  sub = client.sends.listen((recorded) {
    if (!reached.isCompleted && recorded >= count) {
      reached.complete();
    }
  });
  try {
    await reached.future.timeout(const Duration(seconds: 5));
  } on TimeoutException catch (error) {
    fail(
      "Timed out waiting for $count sends "
      "(got ${client.sentConnIDs.length}): $error",
    );
  } finally {
    await sub.cancel();
  }
}

Future<void> _pumpEventLoop() => Future<void>.delayed(const Duration(milliseconds: 30));

class _RecordingRelayClient extends RelayClient {
  final List<int> sentConnIDs = <int>[];
  final List<List<int>> sentPayloads = <List<int>>[];
  RelaySendOutcome nextOutcome = RelaySendOutcome.sent;
  void Function()? onNextSend;
  final StreamController<int> _sends = StreamController<int>.broadcast();

  /// Emits the recorded send count after every send, so tests can await
  /// sends without polling.
  Stream<int> get sends => _sends.stream;

  _RecordingRelayClient()
    : super(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

  @override
  RelaySendOutcome sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required List<int> payload,
  }) {
    sentConnIDs.add(connID);
    sentPayloads.add(List<int>.from(payload));
    _sends.add(sentConnIDs.length);
    final outcome = nextOutcome;
    onNextSend?.call();
    return outcome;
  }
}

class _ThrowingRelayClient extends RelayClient {
  _ThrowingRelayClient()
    : super(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
        bridgeIdProvider: FakeBridgeIdProvider(),
      );

  @override
  RelaySendOutcome sendIfCurrent({
    required RelayConnection connection,
    required int connID,
    required List<int> payload,
  }) {
    throw Exception("send failed intentionally");
  }
}

/// A [CapturingFailureReporter] that completes a completer on the first
/// recorded failure, so tests await the report instead of polling.
class _CompletingFailureReporter extends CapturingFailureReporter {
  _CompletingFailureReporter({required Completer<void> reported})
    : _reported = reported;

  final Completer<void> _reported;

  @override
  Future<void> recordFailure({
    required Object error,
    required StackTrace stackTrace,
    required String uniqueIdentifier,
    required bool fatal,
    required String? reason,
    required Iterable<Object> information,
  }) async {
    await super.recordFailure(
      error: error,
      stackTrace: stackTrace,
      uniqueIdentifier: uniqueIdentifier,
      fatal: fatal,
      reason: reason,
      information: information,
    );
    if (!_reported.isCompleted) {
      _reported.complete();
    }
  }
}

extension on SSEManager {
  void subscribeForTest(int connID, RelayClient client) {
    subscribePath(
      connID: connID,
      path: "/global/event",
      client: client,
      connection: _testRelayConnection,
    );
  }
}

late RelayConnection _testRelayConnection;
