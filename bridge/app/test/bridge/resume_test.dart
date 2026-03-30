import "dart:convert";

import "package:cryptography/cryptography.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  group("resume framing", () {
    test("valid room key decrypts resume and resume_ack", () async {
      final roomKey = makeRoomKey();
      final crypto = RelayCryptoService();

      final resumeEncryptor = crypto.createSessionEncryptor(
        SecretKey(List<int>.from(roomKey)),
      );
      final resumeFrame = await frame(
        utf8.encode(jsonEncode(const RelayMessage.resume().toJson())),
        encryptor: resumeEncryptor,
      );

      final resumeDecryptor = crypto.createSessionEncryptor(
        SecretKey(List<int>.from(roomKey)),
      );
      final resumeDecrypted = await unframe(resumeFrame, encryptor: resumeDecryptor);
      final resumeMsg = RelayMessage.fromJson(
        jsonDecode(utf8.decode(resumeDecrypted)) as Map<String, dynamic>,
      );
      expect(resumeMsg, isA<RelayResume>());

      final ackEncryptor = crypto.createSessionEncryptor(
        SecretKey(List<int>.from(roomKey)),
      );
      final ackFrame = await frame(
        utf8.encode(jsonEncode(const RelayMessage.resumeAck().toJson())),
        encryptor: ackEncryptor,
      );

      final ackDecryptor = crypto.createSessionEncryptor(
        SecretKey(List<int>.from(roomKey)),
      );
      final ackDecrypted = await unframe(ackFrame, encryptor: ackDecryptor);
      final ackMsg = RelayMessage.fromJson(
        jsonDecode(utf8.decode(ackDecrypted)) as Map<String, dynamic>,
      );
      expect(ackMsg, isA<RelayResumeAck>());
    });

    test("stale room key fails decryption", () async {
      final goodKey = makeRoomKey();
      final staleKey = makeRoomKey();
      final crypto = RelayCryptoService();

      final staleEncryptor = crypto.createSessionEncryptor(SecretKey(staleKey));
      final framed = await frame(
        utf8.encode(jsonEncode(const RelayMessage.resume().toJson())),
        encryptor: staleEncryptor,
      );

      final goodDecryptor = crypto.createSessionEncryptor(SecretKey(goodKey));
      expect(() => unframe(framed, encryptor: goodDecryptor), throwsA(isA<Object>()));
    });

    test("frame starts with protocol version byte", () async {
      final roomKey = makeRoomKey();
      final encryptor = RelayCryptoService().createSessionEncryptor(
        SecretKey(roomKey),
      );

      final framed = await frame(
        utf8.encode(jsonEncode(const RelayMessage.resume().toJson())),
        encryptor: encryptor,
      );

      expect(framed[0], equals(protocolVersion));
    });
  });
}
