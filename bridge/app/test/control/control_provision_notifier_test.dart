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

    ControlProvisionProgress progressOf(ControlMessage message) {
      final provision = message as ControlProvisionProgressMessage;
      return provision.progress;
    }

    test("maps each RuntimeProvisionProgress variant onto the wire mirror", () {
      notifier.notify(const ProvisionResolving());
      notifier.notify(const ProvisionDownloading(receivedBytes: 10, totalBytes: 100));
      notifier.notify(const ProvisionDownloading(receivedBytes: 5, totalBytes: null));
      notifier.notify(const ProvisionExtracting());
      notifier.notify(const ProvisionVerifying());
      notifier.notify(const ProvisionNotice(message: "using managed runtime"));
      notifier.notify(const ProvisionReady(binaryPath: "/opt/opencode"));
      notifier.notify(const ProvisionFailed(message: "network down"));

      final sent = client.sentMessages.map(progressOf).toList();
      expect(sent, <ControlProvisionProgress>[
        const ControlProvisionProgress.resolving(),
        const ControlProvisionProgress.downloading(receivedBytes: 10, totalBytes: 100),
        const ControlProvisionProgress.downloading(receivedBytes: 5, totalBytes: null),
        const ControlProvisionProgress.extracting(),
        const ControlProvisionProgress.verifying(),
        const ControlProvisionProgress.notice(message: "using managed runtime"),
        const ControlProvisionProgress.ready(binaryPath: "/opt/opencode"),
        const ControlProvisionProgress.failed(message: "network down"),
      ]);
    });

    test("round-trips through JSON as a provision_progress control message", () {
      notifier.notify(const ProvisionDownloading(receivedBytes: 42, totalBytes: 84));

      final message = client.sentMessages.single;
      expect(
        message,
        const ControlMessage.provisionProgress(
          progress: ControlProvisionProgress.downloading(receivedBytes: 42, totalBytes: 84),
        ),
      );
    });

    test("swallows a not-connected channel so provisioning is never blocked", () {
      client.throwOnSend = const ControlChannelNotConnectedException("down");

      expect(() => notifier.notify(const ProvisionExtracting()), returnsNormally);
      expect(client.sentFrames, isEmpty);
    });

    test("swallows any other send failure so provisioning is never blocked", () {
      client.throwOnSend = StateError("boom");

      expect(() => notifier.notify(const ProvisionReady(binaryPath: "/x")), returnsNormally);
      expect(client.sentFrames, isEmpty);
    });
  });
}

class _FakeControlChannelClient implements ControlChannelClient {
  final List<String> sentFrames = <String>[];

  /// When set, [send] throws this instead of recording the frame, mimicking a
  /// down channel or an unexpected transport error.
  Object? throwOnSend;

  List<ControlMessage> get sentMessages =>
      sentFrames.map((frame) => ControlMessage.fromJson(jsonDecodeMap(frame))).toList();

  @override
  Stream<String> get inbound => const Stream<String>.empty();

  @override
  Stream<ControlChannelConnectionState> get connectionState =>
      const Stream<ControlChannelConnectionState>.empty();

  @override
  void send(String frame) {
    final error = throwOnSend;
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
