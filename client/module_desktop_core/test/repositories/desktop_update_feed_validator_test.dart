import "dart:io";
import "dart:typed_data";

import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

/// Signed by `.github/scripts/sign_desktop_update.py` with a discarded key;
/// `.github/scripts/test_sign_desktop_update.py` verifies the same files.
const String _vector = "test/fixtures/desktop_update_feed";

void main() {
  final Uint8List feed = File("$_vector/releases.stable.json").readAsBytesSync();
  final String signature = File("$_vector/releases.stable.json.sig").readAsStringSync().trim();
  final DesktopUpdateFeedValidator validator = DesktopUpdateFeedValidator.forTesting(
    publicKey: File("$_vector/public_key.txt").readAsStringSync().trim(),
  );

  test("accepts the exact signed feed bytes", () async {
    await validator.verify(
      feed: DesktopUpdateFeed(bytes: feed, signature: signature),
    );
  });

  test("refuses a feed changed after signing", () async {
    final Uint8List tampered = Uint8List.fromList(
      String.fromCharCodes(feed).replaceFirst("1.10.1", "1.10.2").codeUnits,
    );
    await expectLater(
      validator.verify(
        feed: DesktopUpdateFeed(bytes: tampered, signature: signature),
      ),
      throwsFormatException,
    );
  });

  test("refuses a feed signed by another key", () async {
    final DesktopUpdateFeedValidator other = DesktopUpdateFeedValidator.forTesting(
      publicKey: "11qYAYKxCrfVS/7TyWQHOg7hcvPapiMlrwIaaPcHURo=",
    );
    await expectLater(
      other.verify(
        feed: DesktopUpdateFeed(bytes: feed, signature: signature),
      ),
      throwsFormatException,
    );
  });
}
