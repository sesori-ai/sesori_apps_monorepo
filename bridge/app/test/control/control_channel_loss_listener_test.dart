import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:sesori_bridge/src/control/control_channel_loss_listener.dart";
import "package:sesori_bridge/src/foundation/control_channel_client.dart";
import "package:test/test.dart";

void main() {
  group("ControlChannelLossListener", () {
    test("exits after the grace period when the channel stays disconnected", () {
      fakeAsync((async) {
        final controller = StreamController<ControlChannelConnectionState>();
        final exitCodes = <int>[];
        ControlChannelLossListener(
          connectionState: controller.stream,
          exitProcess: exitCodes.add,
          gracePeriod: const Duration(seconds: 5),
        ).start();

        controller.add(ControlChannelConnectionState.disconnected);
        async.elapse(const Duration(seconds: 4));
        expect(exitCodes, isEmpty, reason: "grace period has not elapsed yet");

        async.elapse(const Duration(seconds: 2));
        expect(exitCodes, equals([controlChannelLostExitCode]));
      });
    });

    test("does not exit when the channel reconnects within the grace period", () {
      fakeAsync((async) {
        final controller = StreamController<ControlChannelConnectionState>();
        final exitCodes = <int>[];
        ControlChannelLossListener(
          connectionState: controller.stream,
          exitProcess: exitCodes.add,
          gracePeriod: const Duration(seconds: 5),
        ).start();

        controller.add(ControlChannelConnectionState.disconnected);
        async.elapse(const Duration(seconds: 2));
        controller.add(ControlChannelConnectionState.connected);
        async.elapse(const Duration(seconds: 10));

        expect(exitCodes, isEmpty);
      });
    });

    test("re-arms the grace timer on a subsequent disconnect", () {
      fakeAsync((async) {
        final controller = StreamController<ControlChannelConnectionState>();
        final exitCodes = <int>[];
        ControlChannelLossListener(
          connectionState: controller.stream,
          exitProcess: exitCodes.add,
          gracePeriod: const Duration(seconds: 5),
        ).start();

        controller.add(ControlChannelConnectionState.disconnected);
        async.elapse(const Duration(seconds: 2));
        controller.add(ControlChannelConnectionState.connected);
        async.elapse(const Duration(seconds: 10));
        expect(exitCodes, isEmpty);

        controller.add(ControlChannelConnectionState.disconnected);
        async.elapse(const Duration(seconds: 5));
        expect(exitCodes, equals([controlChannelLostExitCode]));
      });
    });

    test("does not exit after dispose, even once the grace period elapses", () {
      fakeAsync((async) {
        final controller = StreamController<ControlChannelConnectionState>();
        final exitCodes = <int>[];
        final listener = ControlChannelLossListener(
          connectionState: controller.stream,
          exitProcess: exitCodes.add,
          gracePeriod: const Duration(seconds: 5),
        )..start();

        controller.add(ControlChannelConnectionState.disconnected);
        async.elapse(const Duration(seconds: 2));
        unawaited(listener.dispose());
        async.elapse(const Duration(seconds: 10));

        expect(exitCodes, isEmpty);
      });
    });

    test("ignores a clean stream close (client dispose) without exiting", () {
      fakeAsync((async) {
        final controller = StreamController<ControlChannelConnectionState>();
        final exitCodes = <int>[];
        ControlChannelLossListener(
          connectionState: controller.stream,
          exitProcess: exitCodes.add,
          gracePeriod: const Duration(seconds: 5),
        ).start();

        // A clean ControlChannelClient.dispose() closes the stream (done)
        // WITHOUT a disconnected event — that must never trigger an exit.
        unawaited(controller.close());
        async.elapse(const Duration(seconds: 10));

        expect(exitCodes, isEmpty);
      });
    });
  });
}
