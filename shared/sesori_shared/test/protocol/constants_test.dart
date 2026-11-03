import "package:cryptography/cryptography.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("relay plaintext limit reserves exactly the framing and encryption overhead", () async {
    final encryptor = RelayCryptoService().createSessionEncryptor(SecretKey(List<int>.filled(32, 1)));
    final plaintext = List<int>.filled(100, 7);

    final framed = await frame(plaintext, encryptor: encryptor);

    expect(framed.length - plaintext.length, RelayProtocol.encryptedMessageOverheadBytes);
    expect(
      RelayProtocol.maxPlaintextMessageBytes + RelayProtocol.encryptedMessageOverheadBytes,
      RelayProtocol.maxMessageBytes,
    );
  });
}
