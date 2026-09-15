import "dart:io";

import "package:flutter_test/flutter_test.dart";

void main() {
  test("Sesori custom scheme is registered on supported mobile-app runners", () async {
    final androidManifest = await File("android/app/src/main/AndroidManifest.xml").readAsString();
    final iosInfo = await File("ios/Runner/Info.plist").readAsString();
    final macosInfo = await File("macos/Runner/Info.plist").readAsString();

    expect(androidManifest, contains('android:scheme="com.sesori.app"'));
    final androidActivity = RegExp(r"<activity\b[\s\S]*?</activity>").firstMatch(androidManifest)?.group(0);
    expect(androidActivity, isNotNull);
    expect(
      androidActivity,
      matches(
        RegExp(
          r'<meta-data\b(?=[^>]*android:name="flutter_deeplinking_enabled")(?=[^>]*android:value="false")[^>]*/>',
        ),
      ),
    );
    expect(iosInfo, contains("<string>com.sesori.app</string>"));
    expect(
      iosInfo,
      matches(RegExp(r"<key>\s*FlutterDeepLinkingEnabled\s*</key>\s*<false\s*/>")),
    );
    expect(macosInfo, contains("<string>com.sesori.app</string>"));
    expect(
      macosInfo,
      matches(RegExp(r"<key>\s*FlutterDeepLinkingEnabled\s*</key>\s*<false\s*/>")),
    );
  });
}
