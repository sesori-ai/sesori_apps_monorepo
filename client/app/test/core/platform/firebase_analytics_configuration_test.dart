import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  late String androidManifest;
  late String androidFastfile;
  late List<String> appleInfoPlists;

  setUpAll(() async {
    androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    androidFastfile = await File("android/fastlane/Fastfile").readAsString();
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

  test("the Android release lane stamps the build time the analytics window reads", () {
    // Play's pre-launch crawl only exists on Android, so this is the lane whose
    // stamp actually keeps crawler installs out of the user counts.
    expect(
      androidFastfile,
      contains("--dart-define=SESORI_BUILD_EPOCH_SECONDS=#{Time.now.utc.to_i}"),
      reason: "an unstamped release build reads as outside the window and reports every launch",
    );
  });

  test("automatic Firebase screen reporting is disabled on every Firebase-enabled target", () {
    expectAndroidMetaDataDisabled(name: "google_analytics_automatic_screen_reporting_enabled");
    expectAppleKeyDisabled(key: "FirebaseAutomaticScreenReportingEnabled");
  });
}
