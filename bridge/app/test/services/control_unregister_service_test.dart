import "dart:async";

import "package:sesori_bridge/src/auth/bridge_registration_service.dart";
import "package:sesori_bridge/src/services/control_unregister_service.dart";
import "package:test/test.dart";

void main() {
  group("ControlUnregisterService", () {
    test("unregisters then terminates, in that order", () async {
      final events = <String>[];
      final registrationService = _FakeRegistrationService(
        onUnregister: () async => events.add("unregister"),
      );
      final service = ControlUnregisterService(
        registrationService: registrationService,
        terminate: () async => events.add("terminate"),
      );

      await service.handleUnregisterAndExit();

      expect(events, equals(["unregister", "terminate"]));
    });

    test("terminates even when unregister fails, so logout is never blocked", () async {
      var terminated = false;
      final registrationService = _FakeRegistrationService(
        onUnregister: () async => throw StateError("auth server unreachable"),
      );
      final service = ControlUnregisterService(
        registrationService: registrationService,
        terminate: () async => terminated = true,
      );

      await service.handleUnregisterAndExit();

      expect(terminated, isTrue);
    });

    test("terminates when a stalled unregister exceeds the timeout", () async {
      var terminated = false;
      final registrationService = _FakeRegistrationService(
        // Never completes — a blackholed network would hang logout forever
        // without the bounding timeout.
        onUnregister: () => Completer<void>().future,
      );
      final service = ControlUnregisterService(
        registrationService: registrationService,
        terminate: () async => terminated = true,
        unregisterTimeout: const Duration(milliseconds: 20),
      );

      await service.handleUnregisterAndExit();

      expect(terminated, isTrue);
    });
  });
}

class _FakeRegistrationService implements BridgeRegistrationService {
  final Future<void> Function() _onUnregister;

  _FakeRegistrationService({required Future<void> Function() onUnregister}) : _onUnregister = onUnregister;

  @override
  Future<void> unregister() => _onUnregister();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
