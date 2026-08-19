import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("Firebase analytics collection defaults off before Dart startup", () async {
    final androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    final iosInfo = await File("ios/Runner/Info.plist").readAsString();
    final macosInfo = await File("macos/Runner/Info.plist").readAsString();

    expect(
      androidManifest,
      contains(
        'android:name="firebase_analytics_collection_enabled"\n'
        '            android:value="false"',
      ),
    );
    for (final info in [iosInfo, macosInfo]) {
      expect(
        info,
        contains(
          "<key>FIREBASE_ANALYTICS_COLLECTION_ENABLED</key>\n"
          "\t\t<false",
        ),
      );
    }
  });

  test("Android uses the official Firebase Test Lab environment signal", () async {
    final mainActivity = await File(
      "android/app/src/main/kotlin/com/sesori/app/MainActivity.kt",
    ).readAsString();

    expect(mainActivity, contains('Settings.System.getString(contentResolver, "firebase.test.lab")'));
    expect(mainActivity, contains('"com.sesori.app/firebase-test-lab"'));
  });

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
