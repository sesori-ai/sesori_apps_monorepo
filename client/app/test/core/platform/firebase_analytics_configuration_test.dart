import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  late String androidManifest;
  late String iosInfoPlist;

  setUpAll(() async {
    androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    iosInfoPlist = await File("ios/Runner/Info.plist").readAsString();
  });

  void expectAndroidMetaDataDisabled({required String name}) => expect(
    androidManifest,
    matches(RegExp('android:name="$name"\\s+android:value="false"')),
    reason: "$name must default to false in the Android manifest",
  );

  void expectIosKeyDisabled({required String key}) => expect(
    iosInfoPlist,
    matches(RegExp("<key>$key</key>\\s*<false\\s*/>")),
    reason: "$key must default to false on iOS",
  );

  test("Firebase analytics collection defaults off before Dart startup", () {
    expectAndroidMetaDataDisabled(name: "firebase_analytics_collection_enabled");
    expectIosKeyDisabled(key: "FIREBASE_ANALYTICS_COLLECTION_ENABLED");
  });

  test("automatic Firebase screen reporting is disabled on every Firebase-enabled target", () {
    expectAndroidMetaDataDisabled(name: "google_analytics_automatic_screen_reporting_enabled");
    expectIosKeyDisabled(key: "FirebaseAutomaticScreenReportingEnabled");
  });
}
