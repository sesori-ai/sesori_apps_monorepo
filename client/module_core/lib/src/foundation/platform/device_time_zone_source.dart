/// The device's time zone, for the wall-clock times a scheduled task keeps.
abstract interface class DeviceTimeZoneSource() {
  /// The zone's IANA name, such as `Europe/Bucharest`. Throws when the
  /// platform cannot report it.
  Future<String> currentZoneName();
}
