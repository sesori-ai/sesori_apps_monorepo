import "package:flutter_timezone/flutter_timezone.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Shared adapter for core's device time-zone lookup.
class FlutterDeviceTimeZoneSource() implements DeviceTimeZoneSource {
  @override
  Future<String> currentZoneName() async => (await FlutterTimezone.getLocalTimezone()).identifier;
}
