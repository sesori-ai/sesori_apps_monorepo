import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  late String androidManifest;
  late String androidMainActivity;
  late List<String> appleInfoPlists;

  setUpAll(() async {
    androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    androidMainActivity = await File(
      "android/app/src/main/kotlin/com/sesori/app/MainActivity.kt",
    ).readAsString();
    appleInfoPlists = [
      await File("ios/Runner/Info.plist").readAsString(),
      await File("macos/Runner/Info.plist").readAsString(),
    ];
  });

  void expectAndroidMetaDataDisabled({required String name}) => expect(
    androidManifest,
    matches(RegExp('android:name="$name"\\s+android:value="false"')),
    reason: "$name must default to false in the Android manifest",
  );

  void expectAppleKeyDisabled({required String key}) {
    for (final info in appleInfoPlists) {
      expect(
        info,
        matches(RegExp("<key>$key</key>\\s*<false\\s*/>")),
        reason: "$key must default to false on iOS and macOS",
      );
    }
  }

  test("Firebase analytics collection defaults off before Dart startup", () {
    expectAndroidMetaDataDisabled(name: "firebase_analytics_collection_enabled");
    expectAppleKeyDisabled(key: "FIREBASE_ANALYTICS_COLLECTION_ENABLED");
  });

  test("Android uses the official Firebase Test Lab environment signal", () {
    expect(
      androidMainActivity,
      contains('const val FIREBASE_TEST_LAB_CHANNEL_NAME = "com.sesori.app/firebase-test-lab"'),
    );
    expect(androidMainActivity, contains('"isRunning" ->'));
    expect(
      androidMainActivity,
      contains('Settings.System.getString(contentResolver, "firebase.test.lab") == "true"'),
    );
  });

  test("automatic Firebase screen reporting is disabled on every Firebase-enabled target", () {
    expectAndroidMetaDataDisabled(name: "google_analytics_automatic_screen_reporting_enabled");
    expectAppleKeyDisabled(key: "FirebaseAutomaticScreenReportingEnabled");
  });
}
