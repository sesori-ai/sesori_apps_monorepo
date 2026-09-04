import "dart:async";
import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_desktop/core/platform/flutter_desktop_application_support_directory.dart";

void main() {
  group("FlutterDesktopApplicationSupportDirectory", () {
    test("shares one successful lookup across callers", () async {
      final Completer<Directory> lookup = Completer<Directory>();
      int attempts = 0;
      final FlutterDesktopApplicationSupportDirectory directory = FlutterDesktopApplicationSupportDirectory.forTesting(
        load: () {
          attempts++;
          return lookup.future;
        },
      );

      final Future<Directory> first = directory.resolve();
      final Future<Directory> second = directory.resolve();
      expect(second, same(first));

      final Directory expected = Directory("/tmp/sesori-application-support");
      lookup.complete(expected);

      expect(await first, same(expected));
      expect(await directory.resolve(), same(expected));
      expect(attempts, 1);
    });

    test("evicts a failed lookup so a later write can retry", () async {
      int attempts = 0;
      final Directory expected = Directory("/tmp/sesori-application-support");
      final FlutterDesktopApplicationSupportDirectory directory = FlutterDesktopApplicationSupportDirectory.forTesting(
        load: () async {
          attempts++;
          if (attempts == 1) {
            throw StateError("path provider unavailable");
          }
          return expected;
        },
      );

      await expectLater(directory.resolve(), throwsA(isA<StateError>()));

      expect(await directory.resolve(), same(expected));
      expect(attempts, 2);
    });
  });
}
