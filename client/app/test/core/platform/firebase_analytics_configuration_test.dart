import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("automatic Firebase screen reporting is disabled on every Firebase-enabled target", () async {
    final androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    final iosInfo = await File("ios/Runner/Info.plist").readAsString();
    final macosInfo = await File("macos/Runner/Info.plist").readAsString();

    expect(
      androidManifest,
      contains(
        'android:name="google_analytics_automatic_screen_reporting_enabled"\n'
        '            android:value="false"',
      ),
    );
    for (final info in [iosInfo, macosInfo]) {
      expect(
        info,
        contains(
          "<key>FirebaseAutomaticScreenReportingEnabled</key>\n"
          "\t\t<false",
        ),
      );
    }
  });
}
