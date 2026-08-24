import "package:sesori_bridge/src/control/control_provision_notifier.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/fake_control_channel_client.dart";

void main() {
  group("ControlProvisionNotifier", () {
    late FakeControlChannelClient client;
    late ControlProvisionNotifier notifier;

    setUp(() {
      client = FakeControlChannelClient();
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

    test("coalesces known-size downloads by integer percentage and sends completion", () {
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 100, totalBytes: 10000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 199, totalBytes: 10000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 200, totalBytes: 10000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 9999, totalBytes: 10000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 10000, totalBytes: 10000),
      );

      expect(
        _sentProgress(client),
        equals(const <ControlProvisionProgress>[
          ControlProvisionProgress.downloading(receivedBytes: 100, totalBytes: 10000),
          ControlProvisionProgress.downloading(receivedBytes: 200, totalBytes: 10000),
          ControlProvisionProgress.downloading(receivedBytes: 9999, totalBytes: 10000),
          ControlProvisionProgress.downloading(receivedBytes: 10000, totalBytes: 10000),
        ]),
      );
    });

    for (final totalBytes in <int?>[null, 0]) {
      test("coalesces ${totalBytes == null ? "unknown" : "non-positive"}-size downloads by 512 KiB", () {
        const stepBytes = 512 * 1024;
        notifier.handleProvisionProgress(
          event: ProvisionDownloading(receivedBytes: 0, totalBytes: totalBytes),
        );
        notifier.handleProvisionProgress(
          event: ProvisionDownloading(receivedBytes: stepBytes - 1, totalBytes: totalBytes),
        );
        notifier.handleProvisionProgress(
          event: ProvisionDownloading(receivedBytes: stepBytes, totalBytes: totalBytes),
        );
        notifier.handleProvisionProgress(
          event: ProvisionDownloading(receivedBytes: stepBytes + 1, totalBytes: totalBytes),
        );

        expect(
          _sentProgress(client),
          equals(<ControlProvisionProgress>[
            ControlProvisionProgress.downloading(receivedBytes: 0, totalBytes: totalBytes),
            ControlProvisionProgress.downloading(receivedBytes: stepBytes, totalBytes: totalBytes),
          ]),
        );
      });
    }

    test("a changed total or regressed byte count starts a new download", () {
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 500, totalBytes: 1000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 505, totalBytes: 1000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 100, totalBytes: 2000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 50, totalBytes: 2000),
      );

      expect(
        _sentProgress(client),
        equals(const <ControlProvisionProgress>[
          ControlProvisionProgress.downloading(receivedBytes: 500, totalBytes: 1000),
          ControlProvisionProgress.downloading(receivedBytes: 100, totalBytes: 2000),
          ControlProvisionProgress.downloading(receivedBytes: 50, totalBytes: 2000),
        ]),
      );
    });

    test("phase changes reset download coalescing and remain ordered", () {
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 100, totalBytes: 1000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 105, totalBytes: 1000),
      );
      notifier.handleProvisionProgress(event: const ProvisionVerifying());
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 105, totalBytes: 1000),
      );

      expect(
        _sentProgress(client),
        equals(const <ControlProvisionProgress>[
          ControlProvisionProgress.downloading(receivedBytes: 100, totalBytes: 1000),
          ControlProvisionProgress.verifying(),
          ControlProvisionProgress.downloading(receivedBytes: 105, totalBytes: 1000),
        ]),
      );
    });

    test("sends every non-download phase in order", () {
      notifier.handleProvisionProgress(event: const ProvisionResolving());
      notifier.handleProvisionProgress(event: const ProvisionExtracting());
      notifier.handleProvisionProgress(event: const ProvisionVerifying());

      expect(
        _sentProgress(client),
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

    test("a dropped download bucket is still coalesced", () {
      client.throwOnSend = true;
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 100, totalBytes: 10000),
      );

      client.throwOnSend = false;
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 199, totalBytes: 10000),
      );
      notifier.handleProvisionProgress(
        event: const ProvisionDownloading(receivedBytes: 200, totalBytes: 10000),
      );

      expect(
        _sentProgress(client),
        equals(const <ControlProvisionProgress>[
          ControlProvisionProgress.downloading(receivedBytes: 200, totalBytes: 10000),
        ]),
      );
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

Iterable<ControlProvisionProgress> _sentProgress(FakeControlChannelClient client) =>
    client.sentMessages.map((message) => (message as ControlProvisionProgressMessage).progress);
