import "dart:io";

import "package:sesori_bridge/src/foundation/macos_system_power_observer_api.dart";
import "package:sesori_bridge/src/foundation/system_power_event_source.dart";
import "package:test/test.dart";

void main() {
  test("native macOS power observer starts and disposes without sleeping", () async {
    if (!Platform.isMacOS) return;
    final source = SystemPowerEventSource.forPlatform(
      operatingSystem: Platform.operatingSystem,
      macosApi: MacosSystemPowerObserverApi(),
    );
    source.start();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await source.dispose();
  });
}
