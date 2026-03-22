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
  group("SSEManager", () {
    test("subscribe registers subscribers", () {
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
      );

      manager.subscribePath(1, "/global/event", relayClient);
      manager.subscribePath(2, "/global/event", relayClient);
      addTearDown(manager.stop);

      expect(manager.subscriberCount, equals(2));
    });

    test("enqueueEvent with no subscribers does nothing", () async {
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      final client = _RecordingRelayClient();
      manager.setRoomKey(makeRoomKey());

      manager.enqueueEvent(_event("none"));
      await _pumpEventLoop();

      expect(client.sentConnIDs, isEmpty);
    });

    test("enqueueEvent delivers typed payload envelope to all subscribers", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribePath(1, "/global/event", client);
      manager.subscribePath(2, "/global/event", client);

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
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      addTearDown(manager.stop);

      manager.subscribePath(7, "/global/event", client);
      manager.enqueueEvent(_event("repo-x"));
      await _pumpEventLoop();

      expect(client.sentConnIDs, isEmpty);
    });

    test("non-last unsubscribe creates orphan queue", () {
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
      );
      addTearDown(manager.stop);

      manager.subscribePath(1, "/global/event", relayClient);
      manager.subscribePath(2, "/global/event", relayClient);
      manager.unsubscribe(1);

      expect(manager.subscriberCount, equals(1));
      expect(manager.pendingReplayCount, equals(1));
    });

    test("orphan queue replays to next subscriber within replay window", () async {
      final roomKey = makeRoomKey();
      final client = _RecordingRelayClient();
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      manager.setRoomKey(roomKey);
      addTearDown(manager.stop);

      manager.subscribePath(1, "/global/event", client);
      manager.subscribePath(2, "/global/event", client);

      manager.enqueueEvent(_event("event-a"));
      await _waitForSendCount(client, 2);

      manager.unsubscribe(1);
      manager.enqueueEvent(_event("event-b"));
      await _waitForSendCount(client, 3);

      manager.subscribePath(3, "/global/event", client);
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
        final manager = SSEManager(replayWindow: const Duration(seconds: 30));
        manager.setRoomKey(roomKey);
        addTearDown(manager.stop);

        manager.subscribePath(1, "/global/event", client);
        manager.subscribePath(2, "/global/event", client);

        manager.unsubscribe(1);
        manager.enqueueEvent(_event("queued-for-orphan"));
        await _waitForSendCount(client, 1);

        now = now.add(const Duration(seconds: 31));
        final sendsBefore = client.sentConnIDs.length;

        manager.subscribePath(3, "/global/event", client);
        await _pumpEventLoop();

        expect(client.sentConnIDs.length, equals(sendsBefore));
        expect(manager.pendingReplayCount, equals(0));
      });
    });

    test("stop clears subscribers and orphan queues", () {
      final manager = SSEManager(replayWindow: const Duration(seconds: 30));
      final relayClient = RelayClient(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
      );

      manager.subscribePath(1, "/global/event", relayClient);
      manager.subscribePath(2, "/global/event", relayClient);
      manager.unsubscribe(1);

      manager.stop();

      expect(manager.subscriberCount, equals(0));
      expect(manager.pendingReplayCount, equals(0));
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
  final decrypted = await unframe(framed, decryptor);
  return jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
}

Future<void> _waitForSendCount(_RecordingRelayClient client, int count) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(deadline)) {
    if (client.sentConnIDs.length >= count) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw TimeoutException(
    "Timed out waiting for $count sends (got ${client.sentConnIDs.length})",
  );
}

Future<void> _pumpEventLoop() => Future<void>.delayed(const Duration(milliseconds: 30));

class _RecordingRelayClient extends RelayClient {
  final List<int> sentConnIDs = <int>[];
  final List<List<int>> sentPayloads = <List<int>>[];

  _RecordingRelayClient()
    : super(
        relayURL: "ws://127.0.0.1:1",
        accessTokenProvider: FakeAccessTokenProvider(""),
      );

  @override
  void send(int connID, List<int> payload) {
    sentConnIDs.add(connID);
    sentPayloads.add(List<int>.from(payload));
  }
}
