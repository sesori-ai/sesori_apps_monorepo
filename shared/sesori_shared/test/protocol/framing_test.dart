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

    test("frame() prepends version byte 0x01", () async {
      final plaintext = [1, 2, 3, 4, 5];
      final framed = await frame(plaintext, encryptor: encryptor);

      expect(framed[0], equals(0x01));
      expect(framed.length, greaterThan(1));
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
