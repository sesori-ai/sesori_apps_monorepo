import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("relay plaintext limit reserves encryption and version overhead", () {
    expect(
      RelayProtocol.canEncryptMessage(
        plaintextBytes: RelayProtocol.maxPlaintextMessageBytes,
      ),
      isTrue,
    );
    expect(
      RelayProtocol.canEncryptMessage(
        plaintextBytes: RelayProtocol.maxPlaintextMessageBytes + 1,
      ),
      isFalse,
    );
  });
}
