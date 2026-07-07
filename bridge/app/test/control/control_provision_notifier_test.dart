import "dart:async";

import "package:sesori_bridge/src/control/control_provision_notifier.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlProvisionNotifier", () {
    late _FakeControlChannelClient client;
    late ControlProvisionNotifier notifier;

    setUp(() {
      client = _FakeControlChannelClient();
      notifier = ControlProvisionNotifier(client: client);
    });

    tearDown(() async {
      await client.dispose();
    });

    test("maps a progress event to a provision_progress control message", () {
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 128, totalBytes: 512),
      );

      expect(client.sentMessages, hasLength(1));
      final message = client.sentMessages.single as ControlProvisionProgressMessage;
      expect(
        message.progress,
        equals(const ControlProvisionProgress.downloading(receivedBytes: 128, totalBytes: 512)),
      );
    });

    test("conveys the ProvisionReady terminal event with its binary path", () {
      notifier.handleProvisionProgress(event: const ProvisionReady(binaryPath: "/bin/opencode"));

      final message = client.sentMessages.single as ControlProvisionProgressMessage;
      expect(message.progress, equals(const ControlProvisionProgress.ready(binaryPath: "/bin/opencode")));
    });

    test("conveys the ProvisionFailed terminal event with its message", () {
      notifier.handleProvisionProgress(event: const ProvisionFailed(message: "checksum mismatch"));

      final message = client.sentMessages.single as ControlProvisionProgressMessage;
      expect(message.progress, equals(const ControlProvisionProgress.failed(message: "checksum mismatch")));
    });

    test("sends one frame per event, in order", () {
      notifier.handleProvisionProgress(event: const ProvisionResolving());
      notifier.handleProvisionProgress(event: const ProvisionExtracting());
      notifier.handleProvisionProgress(event: const ProvisionVerifying());

      expect(
        client.sentMessages.map((message) => (message as ControlProvisionProgressMessage).progress),
        equals(const <ControlProvisionProgress>[
          ControlProvisionProgress.resolving(),
          ControlProvisionProgress.extracting(),
          ControlProvisionProgress.verifying(),
        ]),
      );
    });

    test("a channel-down send is swallowed (best-effort — no throw)", () {
      client.throwOnSend = true;

      expect(
        () => notifier.handleProvisionProgress(event: const ProvisionExtracting()),
        returnsNormally,
      );
      expect(client.sentFrames, isEmpty);
    });

    test("an unexpected send error is swallowed (best-effort — no throw)", () {
      client.sendError = StateError("sink is closed");

      expect(
        () => notifier.handleProvisionProgress(event: const ProvisionExtracting()),
        returnsNormally,
      );
      expect(client.sentFrames, isEmpty);
    });
  });
}

class _FakeControlChannelClient implements ControlChannelClient {
  final List<String> sentFrames = <String>[];

  /// Mimics [ControlChannelClient.send] throwing when the channel is down.
  bool throwOnSend = false;

  /// An arbitrary send failure (exercises the catch-all path).
  Object? sendError;

  List<ControlMessage> get sentMessages =>
      sentFrames.map((frame) => ControlMessage.fromJson(jsonDecodeMap(frame))).toList();

  @override
  Stream<String> get inbound => const Stream<String>.empty();

  @override
  Stream<ControlChannelConnectionState> get connectionState => const Stream<ControlChannelConnectionState>.empty();

  @override
  void send(String frame) {
    if (throwOnSend) {
      throw const ControlChannelNotConnectedException("Control channel is not connected");
    }
    final error = sendError;
    if (error != null) {
      throw error;
    }
    sentFrames.add(frame);
  }

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}
