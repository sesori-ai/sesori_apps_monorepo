import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ControlProvisionProgress", () {
    final variants = <String, ControlProvisionProgress>{
      "resolving": const ControlProvisionProgress.resolving(),
      "downloading": const ControlProvisionProgress.downloading(receivedBytes: 512, totalBytes: 2048),
      "extracting": const ControlProvisionProgress.extracting(),
      "verifying": const ControlProvisionProgress.verifying(),
      "notice": const ControlProvisionProgress.notice(message: "using managed runtime"),
      "ready": const ControlProvisionProgress.ready(binaryPath: "/opt/opencode/bin/opencode"),
      "failed": const ControlProvisionProgress.failed(message: "checksum mismatch"),
    };

    variants.forEach((type, original) {
      test("round-trips the $type variant with its discriminator", () {
        final json = original.toJson();

        expect(json["type"], equals(type));
        expect(ControlProvisionProgress.fromJson(json), equals(original));
      });
    });

    test("downloading omits totalBytes when indeterminate", () {
      const original = ControlProvisionProgress.downloading(receivedBytes: 100, totalBytes: null);

      final json = original.toJson();

      expect(json.containsKey("totalBytes"), isFalse);
      expect(json, equals({"type": "downloading", "receivedBytes": 100}));

      final restored = ControlProvisionProgress.fromJson(json);
      expect(restored, equals(original));
      expect((restored as ControlProvisionDownloading).totalBytes, isNull);
    });

    test("parses the concrete variant subtype", () {
      final parsed = ControlProvisionProgress.fromJson({
        "type": "ready",
        "binaryPath": "/usr/local/bin/opencode",
      });

      expect(parsed, isA<ControlProvisionReady>());
      expect((parsed as ControlProvisionReady).binaryPath, equals("/usr/local/bin/opencode"));
    });
  });
}
