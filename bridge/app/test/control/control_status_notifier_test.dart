import "dart:async";

import "package:sesori_bridge/src/bridge/relay_client.dart";
import "package:sesori_bridge/src/control/control_status_notifier.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late _FakeControlChannelClient client;
  late StreamController<List<PluginMetadata>> pluginMetadata;
  late StreamController<RelayConnectionState> relayState;
  late StreamController<String> registrations;
  late ControlStatusNotifier notifier;

  setUp(() {
    client = _FakeControlChannelClient();
    pluginMetadata = StreamController<List<PluginMetadata>>.broadcast();
    relayState = StreamController<RelayConnectionState>.broadcast();
    registrations = StreamController<String>.broadcast();
    notifier = ControlStatusNotifier(
      client: client,
      pluginMetadata: pluginMetadata.stream,
      relayConnectionState: relayState.stream,
      registrations: registrations.stream,
    );
    notifier.start();
  });

  tearDown(() async {
    await notifier.dispose();
    await pluginMetadata.close();
    await relayState.close();
    await registrations.close();
    await client.dispose();
  });

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  void emitPluginState(PluginLifecycleState state) {
    pluginMetadata.add([
      PluginMetadata(id: "plugin", displayName: "Plugin", isDefault: true, state: state, actionHint: null),
    ]);
  }

  group("status pushes", () {
    test("a plugin status change pushes a status with the mapped health", () async {
      emitPluginState(PluginLifecycleState.ready);
      await pump();

      expect(client.sentMessages, hasLength(1));
      final status = client.sentMessages.single as ControlStatus;
      expect(status.plugin, ControlPluginHealthState.healthy);
      expect(status.relay, ControlRelayConnectionState.disconnected);
      expect(status.activeSessionCount, 0);
    });

    test("plugin lifecycle states map to the wire health enum", () async {
      emitPluginState(PluginLifecycleState.ready);
      emitPluginState(PluginLifecycleState.degraded);
      emitPluginState(PluginLifecycleState.failed);
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().map((s) => s.plugin).toList(),
        equals([
          ControlPluginHealthState.healthy,
          ControlPluginHealthState.degraded,
          ControlPluginHealthState.unavailable,
        ]),
      );
    });

    test("relay connection transitions push mapped statuses", () async {
      relayState.add(const RelayConnecting());
      relayState.add(const RelayConnected());
      relayState.add(const RelayDisconnected(closeCode: 4006, closeReason: null));
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().map((s) => s.relay).toList(),
        equals([
          ControlRelayConnectionState.connecting,
          ControlRelayConnectionState.connected,
          ControlRelayConnectionState.disconnected,
        ]),
      );
    });

    test("a bridge-replaced close (4007) maps to takenOver", () async {
      relayState.add(const RelayConnected());
      relayState.add(
        const RelayDisconnected(closeCode: RelayCloseCodes.bridgeReplaced, closeReason: null),
      );
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().map((s) => s.relay).toList(),
        equals([
          ControlRelayConnectionState.connected,
          ControlRelayConnectionState.takenOver,
        ]),
      );
    });

    test("the 1000/replaced rollout fallback also maps to takenOver", () async {
      relayState.add(const RelayConnected());
      relayState.add(const RelayDisconnected(closeCode: 1000, closeReason: "replaced"));
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().last.relay,
        ControlRelayConnectionState.takenOver,
      );
    });

    test("a plain 1000 close (no replaced reason) stays disconnected", () async {
      relayState.add(const RelayConnected());
      relayState.add(const RelayDisconnected(closeCode: 1000, closeReason: null));
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().last.relay,
        ControlRelayConnectionState.disconnected,
      );
    });

    test("a status combines the latest of every dimension", () async {
      emitPluginState(PluginLifecycleState.ready);
      relayState.add(const RelayConnected());
      notifier.handleProjectsSummary(summary: _summaryWithSessionCount(2));
      await pump();

      final last = client.sentMessages.last as ControlStatus;
      expect(last.relay, ControlRelayConnectionState.connected);
      expect(last.plugin, ControlPluginHealthState.healthy);
      expect(last.activeSessionCount, 2);
    });

    test("identical consecutive states are deduped", () async {
      emitPluginState(PluginLifecycleState.ready);
      emitPluginState(PluginLifecycleState.ready);
      // Restarting maps to degraded...
      emitPluginState(PluginLifecycleState.degraded);
      // ...and Degraded maps to degraded too: no second frame.
      emitPluginState(PluginLifecycleState.degraded);
      await pump();

      expect(
        client.sentMessages.whereType<ControlStatus>().map((s) => s.plugin).toList(),
        equals([ControlPluginHealthState.healthy, ControlPluginHealthState.degraded]),
      );
    });

    test("an unchanged active-session count pushes nothing", () async {
      notifier.handleProjectsSummary(summary: _summaryWithSessionCount(3));
      notifier.handleProjectsSummary(summary: _summaryWithSessionCount(3));
      await pump();

      expect(client.sentMessages, hasLength(1));
      final status = client.sentMessages.single as ControlStatus;
      expect(status.activeSessionCount, 3);
    });

    test("the count sums active sessions across projects", () async {
      notifier.handleProjectsSummary(
        summary:
            SesoriSseEvent.projectsSummary(
                  projects: [
                    ProjectActivitySummary(id: "p1", activeSessions: [_session("a"), _session("b")]),
                    ProjectActivitySummary(id: "p2", activeSessions: [_session("c")]),
                    const ProjectActivitySummary(id: "p3", activeSessions: []),
                  ],
                )
                as SesoriProjectsSummary,
      );
      await pump();

      final status = client.sentMessages.single as ControlStatus;
      expect(status.activeSessionCount, 3);
    });
  });

  group("registered pushes", () {
    test("a registration success pushes registered with the bridge id", () async {
      registrations.add("br_test1234");
      await pump();

      expect(client.sentMessages, hasLength(1));
      final registered = client.sentMessages.single as ControlRegistered;
      expect(registered.bridgeId, "br_test1234");
    });

    test("a re-registration after revocation pushes the fresh id", () async {
      registrations.add("br_old");
      registrations.add("br_fresh5678");
      await pump();

      expect(
        client.sentMessages.whereType<ControlRegistered>().map((r) => r.bridgeId).toList(),
        equals(["br_old", "br_fresh5678"]),
      );
    });
  });

  group("control-channel resilience", () {
    test("a send failure while the channel is down is swallowed and later sends recover", () async {
      client.throwOnSend = true;
      emitPluginState(PluginLifecycleState.ready);
      await pump();
      expect(client.sentMessages, isEmpty);

      client.throwOnSend = false;
      relayState.add(const RelayConnected());
      await pump();

      expect(client.sentMessages, hasLength(1));
    });

    test("a control-channel reconnect re-sends registered and the status snapshot", () async {
      emitPluginState(PluginLifecycleState.ready);
      registrations.add("br_test1234");
      await pump();
      client.sentFrames.clear();

      client.emitConnectionState(ControlChannelConnectionState.connected);
      await pump();

      expect(client.sentMessages, hasLength(2));
      final registered = client.sentMessages[0] as ControlRegistered;
      expect(registered.bridgeId, "br_test1234");
      final status = client.sentMessages[1] as ControlStatus;
      expect(status.plugin, ControlPluginHealthState.healthy);
    });

    test("a reconnect before any registration re-sends only the status snapshot", () async {
      client.emitConnectionState(ControlChannelConnectionState.connected);
      await pump();

      expect(client.sentMessages, hasLength(1));
      expect(client.sentMessages.single, isA<ControlStatus>());
    });

    test("a control-channel disconnect event alone pushes nothing", () async {
      client.emitConnectionState(ControlChannelConnectionState.disconnected);
      await pump();

      expect(client.sentMessages, isEmpty);
    });
  });

  group("lifecycle", () {
    test("start is idempotent — a second start does not double-subscribe", () async {
      notifier.start();
      emitPluginState(PluginLifecycleState.ready);
      await pump();

      expect(client.sentMessages, hasLength(1));
    });

    test("dispose cancels the subscriptions — later events push nothing", () async {
      await notifier.dispose();

      emitPluginState(PluginLifecycleState.ready);
      relayState.add(const RelayConnected());
      registrations.add("br_test1234");
      await pump();

      expect(client.sentMessages, isEmpty);
    });
  });
}

ActiveSession _session(String id) => ActiveSession(id: id);

SesoriProjectsSummary _summaryWithSessionCount(int count) {
  return SesoriSseEvent.projectsSummary(
        projects: [
          ProjectActivitySummary(
            id: "project-1",
            activeSessions: List<ActiveSession>.generate(count, (i) => _session("session-$i")),
          ),
        ],
      )
      as SesoriProjectsSummary;
}

class _FakeControlChannelClient implements ControlChannelClient {
  final StreamController<ControlChannelConnectionState> _connectionState =
      StreamController<ControlChannelConnectionState>.broadcast();
  final List<String> sentFrames = <String>[];

  /// Mimics [ControlChannelClient.send] throwing when the channel is down.
  bool throwOnSend = false;

  List<ControlMessage> get sentMessages =>
      sentFrames.map((frame) => ControlMessage.fromJson(jsonDecodeMap(frame))).toList();

  void emitConnectionState(ControlChannelConnectionState state) => _connectionState.add(state);

  @override
  Stream<String> get inbound => const Stream<String>.empty();

  @override
  Stream<ControlChannelConnectionState> get connectionState => _connectionState.stream;

  @override
  void send(String frame) {
    if (throwOnSend) {
      throw const ControlChannelNotConnectedException("Control channel is not connected");
    }
    sentFrames.add(frame);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {
    await _connectionState.close();
  }
}
