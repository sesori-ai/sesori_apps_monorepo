import "dart:convert";
import "dart:typed_data";

import "package:sesori_dart_core/src/platform/media_picker.dart";
import "package:sesori_dart_core/src/repositories/mappers/prompt_part_mapper.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("PickedMediaToPromptPart", () {
    test("maps to a fileData prompt part with base64-encoded bytes", () {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 250]);
      final media = PickedMedia(bytes: bytes, mimeType: "image/png", filename: "shot.png");

      final part = media.toPromptPart();

      expect(part, isA<PromptPartFileData>());
      final fileData = part as PromptPartFileData;
      expect(fileData.mime, equals("image/png"));
      expect(fileData.base64, equals(base64Encode(bytes)));
      expect(fileData.filename, equals("shot.png"));
    });

    test("preserves a null filename", () {
      final media = PickedMedia(bytes: Uint8List.fromList([0]), mimeType: "image/jpeg", filename: null);

      final part = media.toPromptPart() as PromptPartFileData;

      expect(part.filename, isNull);
      expect(part.mime, equals("image/jpeg"));
    });
  });
}
