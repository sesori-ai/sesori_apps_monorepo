import "dart:convert";
import "dart:typed_data";

import "package:cryptography/cryptography.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late DesktopStorageCipher cipher;
  late SecretKey masterKey;

  setUp(() async {
    cipher = DesktopStorageCipher(scope: DesktopStorageScope.development);
    masterKey = await cipher.generateMasterKey();
  });

  test("master keys are 256 bits and preserve native base64 encoding", () async {
    final encoded = await cipher.encodeMasterKey(masterKey: masterKey);
    expect(base64Decode(encoded), hasLength(32));
    final restored = cipher.decodeMasterKey(encoded: encoded);
    expect(await restored.extractBytes(), await masterKey.extractBytes());
  });

  for (final value in ["fixture secret 🔐", ""]) {
    test("versioned AES-GCM envelope roundtrips ${value.isEmpty ? 'empty' : 'UTF-8'} data", () async {
      final envelope = await cipher.encrypt(key: "fixture.key", value: value, masterKey: masterKey);
      expect(envelope.first, 1);
      expect(envelope.length, 1 + 12 + utf8.encode(value).length + 16);
      expect(await cipher.decrypt(key: "fixture.key", envelope: envelope, masterKey: masterKey), value);
    });
  }

  test("repeated encryption uses independent 96-bit nonces", () async {
    final first = await cipher.encrypt(key: "fixture.key", value: "same value", masterKey: masterKey);
    final second = await cipher.encrypt(key: "fixture.key", value: "same value", masterKey: masterKey);
    expect(first.sublist(1, 13), isNot(second.sublist(1, 13)));
    expect(first, isNot(second));
  });

  test("row identity and storage scope are authenticated", () async {
    final envelope = await cipher.encrypt(key: "fixture.first", value: "protected value", masterKey: masterKey);
    await expectLater(
      cipher.decrypt(key: "fixture.second", envelope: envelope, masterKey: masterKey),
      throwsA(isA<DesktopStorageException>()),
    );
    final production = DesktopStorageCipher(scope: DesktopStorageScope.production);
    await expectLater(
      production.decrypt(key: "fixture.first", envelope: envelope, masterKey: masterKey),
      throwsA(isA<DesktopStorageException>()),
    );
  });

  test("a different valid key cannot authenticate a row", () async {
    final envelope = await cipher.encrypt(key: "fixture.key", value: "protected value", masterKey: masterKey);
    await expectLater(
      cipher.decrypt(key: "fixture.key", envelope: envelope, masterKey: await cipher.generateMasterKey()),
      throwsA(isA<DesktopStorageException>()),
    );
  });

  for (final mutation in _EnvelopeMutation.values) {
    test("rejects ${mutation.name} envelope damage without exposing the value", () async {
      const value = "fixture-sensitive-value";
      var envelope = await cipher.encrypt(key: "fixture.key", value: value, masterKey: masterKey);
      switch (mutation) {
        case _EnvelopeMutation.nonce:
          envelope[1] ^= 1;
        case _EnvelopeMutation.ciphertext:
          envelope[13] ^= 1;
        case _EnvelopeMutation.tag:
          envelope[envelope.length - 1] ^= 1;
        case _EnvelopeMutation.version:
          envelope[0] = 2;
        case _EnvelopeMutation.truncated:
          envelope = Uint8List.fromList(envelope.sublist(0, 10));
      }
      await expectLater(
        cipher.decrypt(key: "fixture.key", envelope: envelope, masterKey: masterKey),
        throwsA(
          isA<DesktopStorageException>()
              .having((e) => e.operation, "operation", DesktopStorageOperation.decryptValue)
              .having((e) => e.toString(), "presentation", isNot(contains(value))),
        ),
      );
    });
  }

  for (final bytes in [<int>[], List<int>.filled(16, 1), List<int>.filled(33, 1)]) {
    test("rejects a ${bytes.length}-byte native key", () {
      expect(
        () => cipher.decodeMasterKey(encoded: base64Encode(bytes)),
        throwsA(isA<DesktopStorageException>().having((e) => e.innerError, "cause", isA<FormatException>())),
      );
    });
  }

  test("invalid native-key parser causes remain inspectable but are not rendered", () {
    const encoded = "fixture-private-master!";
    expect(
      () => cipher.decodeMasterKey(encoded: encoded),
      throwsA(
        isA<DesktopStorageException>()
            .having((e) => e.innerError, "cause", isA<FormatException>().having((e) => e.source, "source", encoded))
            .having((e) => e.toString(), "presentation", isNot(contains(encoded))),
      ),
    );
  });
}

enum _EnvelopeMutation() {
  nonce,
  ciphertext,
  tag,
  version,
  truncated,
}
