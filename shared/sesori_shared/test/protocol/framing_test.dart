import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("framing", () {
    late SessionEncryptor encryptor;

    setUp(() async {
      final cryptoService = RelayCryptoService();
      final rawKey = List<int>.generate(32, (i) => i + 1);
      final secretKey = SecretKey(rawKey);
      encryptor = cryptoService.createSessionEncryptor(secretKey);
    });

    test("frame() preserves exact version and encrypted layout in typed bytes", () async {
      final framed = await frame([1, 2, 3], encryptor: _FakeSessionEncryptor());

      expect(framed, isA<Uint8List>());
      expect(framed, equals([protocolVersion, 1, 2, 3]));
    });

    test("frame() keeps a maximum-sized attachment payload typed", () async {
      final plaintext = Uint8List(maxInlineMessageAttachmentBytes);
      plaintext[0] = 1;
      plaintext[plaintext.length - 1] = 2;

      final framed = await frame(plaintext, encryptor: _FakeSessionEncryptor());

      expect(framed, isA<Uint8List>());
      expect(framed, hasLength(1 + plaintext.length));
      expect(framed[1], 1);
      expect(framed[framed.length - 1], 2);
    });

    test("unframe(frame(plaintext)) round-trips correctly", () async {
      final plaintext = [10, 20, 30, 40, 50, 60, 70, 80];
      final framed = await frame(plaintext, encryptor: encryptor);
      final recovered = await unframe(framed, encryptor: encryptor);

      expect(recovered, equals(plaintext));
    });

    test("unframe() throws on empty data", () async {
      expect(() => unframe([], encryptor: encryptor), throwsA(isA<FormatException>()));
    });

    test("unframe() throws on wrong version byte", () async {
      final plaintext = [1, 2, 3];
      final framed = await frame(plaintext, encryptor: encryptor);
      final badVersionFrame = [0x02, ...framed.sublist(1)];

      expect(
        () => unframe(badVersionFrame, encryptor: encryptor),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

class _FakeSessionEncryptor() implements SessionEncryptor {
  @override
  Future<Uint8List> encrypt(List<int> plaintext) async =>
      plaintext is Uint8List ? plaintext : Uint8List.fromList(plaintext);

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async => ciphertext;
}
