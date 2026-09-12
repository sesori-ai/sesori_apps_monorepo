import "package:sesori_bridge/src/foundation/macos_system_power_observer_api.dart";
import "package:sesori_bridge/src/foundation/system_power_event_source.dart";
import "package:sesori_bridge/src/services/connection_notification_policy_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class FakeMacosSystemPowerObserverApi() implements MacosSystemPowerObserverApi {
  MacosPowerObserverCallback? callback;
  bool stopped = false;

  @override
  void start({required MacosPowerObserverCallback callback}) {
    this.callback = callback;
  }

  @override
  void stop() {
    stopped = true;
  }
}

void main() {
  test("maps raw power observations to deduplicated connection-notification policy", () async {
    final api = FakeMacosSystemPowerObserverApi();
    final service = ConnectionNotificationPolicyService(
      powerEventSource: SystemPowerEventSource.forPlatform(operatingSystem: "macos", macosApi: api),
    );
    final policies = <BridgeConnectionNotificationPolicy>[];
    final subscription = service.policies.listen(policies.add);

    service.start();
    api.callback!(1, 0);
    api.callback!(1, 0);
    api.callback!(2, 0);
    api.callback!(3, -1);
    await Future<void>.delayed(Duration.zero);

    expect(policies, [
      BridgeConnectionNotificationPolicy.suppress,
      BridgeConnectionNotificationPolicy.normal,
      BridgeConnectionNotificationPolicy.conservative,
    ]);

    await service.dispose();
    expect(api.stopped, isTrue);
    await subscription.cancel();
  });
}
