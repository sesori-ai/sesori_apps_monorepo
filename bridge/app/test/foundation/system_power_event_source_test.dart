import "package:sesori_bridge/src/foundation/macos_system_power_observer_api.dart";
import "package:sesori_bridge/src/foundation/system_power_event_source.dart";
import "package:test/test.dart";

class FakeMacosSystemPowerObserverApi() implements MacosSystemPowerObserverApi {
  MacosPowerObserverCallback? callback;
  bool stopped = false;
  bool failStart = false;

  @override
  void start({required MacosPowerObserverCallback callback}) {
    if (failStart) throw StateError("synthetic startup failure");
    this.callback = callback;
  }

  @override
  void stop() {
    stopped = true;
  }
}

void main() {
  test("publishes raw sleep and wake observations without transport involvement", () async {
    final api = FakeMacosSystemPowerObserverApi();
    final source = SystemPowerEventSource.forPlatform(operatingSystem: "macos", macosApi: api);
    final events = <SystemPowerEvent>[];
    final subscription = source.events.listen(events.add);
    source.start();
    api.callback!(1, 0);
    api.callback!(2, 0);
    await Future<void>.delayed(Duration.zero);
    expect(events, [SystemPowerEvent.willSleep, SystemPowerEvent.fullWake]);
    await source.dispose();
    expect(api.stopped, isTrue);
    await subscription.cancel();
  });

  test("startup failure publishes a failed observation and disposal succeeds", () async {
    final api = FakeMacosSystemPowerObserverApi()..failStart = true;
    final source = SystemPowerEventSource.forPlatform(operatingSystem: "macos", macosApi: api);
    final events = <SystemPowerEvent>[];
    final subscription = source.events.listen(events.add);
    source.start();
    await Future<void>.delayed(Duration.zero);
    expect(events, [SystemPowerEvent.observationFailed]);
    await source.dispose();
    await subscription.cancel();
  });
}
