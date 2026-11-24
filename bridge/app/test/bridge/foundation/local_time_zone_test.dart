import "dart:io";

import "package:sesori_bridge/src/foundation/local_time_zone.dart";
import "package:test/test.dart";

void main() {
  test("TZ naming a zone wins, with or without the POSIX colon", () {
    expect(readLocalTimeZone(environment: {"TZ": "Europe/Bucharest"}), "Europe/Bucharest");
    expect(readLocalTimeZone(environment: {"TZ": ":America/New_York"}), "America/New_York");
  });

  test("a TZ path reads the zone after zoneinfo, and a missing one reads null", () {
    final root = Directory.systemTemp.createTempSync("zoneinfo_test_");
    addTearDown(() => root.deleteSync(recursive: true));
    final zone = File("${root.path}/zoneinfo/Asia/Tokyo")..createSync(recursive: true);
    final link = Link("${root.path}/localtime")..createSync(zone.path);

    expect(readLocalTimeZone(environment: {"TZ": link.path}), "Asia/Tokyo");
    expect(readLocalTimeZone(environment: {"TZ": "${root.path}/missing"}), isNull);
  }, testOn: "!windows");
}
