import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  late String androidManifest;
  late String androidBuildFile;
  late String androidProguardRules;
  late String androidFastfile;
  late String iosProject;
  late String iosReleaseWorkflow;

  setUpAll(() async {
    androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    androidBuildFile = await File("android/app/build.gradle.kts").readAsString();
    androidProguardRules = await File("android/app/proguard-rules.pro").readAsString();
    androidFastfile = await File("android/fastlane/Fastfile").readAsString();
    iosProject = await File("ios/Runner.xcodeproj/project.pbxproj").readAsString();
    iosReleaseWorkflow = await File("../../.github/workflows/_reusable-ios-testflight.yml").readAsString();
  });

  test("Android keeps Singular attribution prerequisites without AD_ID", () {
    for (final permission in [
      "android.permission.INTERNET",
      "android.permission.ACCESS_NETWORK_STATE",
      "com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE",
      "com.android.vending.CHECK_LICENSE",
    ]) {
      expect(androidManifest, contains('android:name="$permission"'));
    }
    for (final advertisingIdPermission in [
      "com.google.android.gms.permission.AD_ID",
      "android.permission.ACCESS_ADSERVICES_AD_ID",
    ]) {
      expect(
        androidManifest,
        contains('<uses-permission android:name="$advertisingIdPermission" tools:node="remove" />'),
      );
    }
  });

  test("Android release minification preserves Singular and install referrer", () {
    expect(androidBuildFile, contains('proguardFiles.add(file("proguard-rules.pro"))'));
    expect(androidProguardRules, contains("-keep class com.singular.sdk.** { *; }"));
    expect(androidProguardRules, contains("-keep public class com.android.installreferrer.** { *; }"));
  });

  test("iOS weak-links AdServices", () {
    expect(iosProject, contains("AdServices.framework in Frameworks"));
    expect(iosProject, contains("ATTRIBUTES = (Weak, );"));
  });

  test("release lanes inject Singular credentials without command-line values", () {
    for (final source in [androidFastfile, iosReleaseWorkflow]) {
      expect(source, contains("SINGULAR_SDK_KEY"));
      expect(source, contains("SINGULAR_SDK_SECRET"));
      expect(source, contains("--dart-define-from-file="));
      expect(source, contains("::add-mask::"));
      expect(source, isNot(contains("--dart-define=SESORI_SINGULAR_SDK_SECRET=")));
    }
  });
}
