import "package:flutter_test/flutter_test.dart";
import "package:sesori_shared/sesori_shared.dart";

void main() {
  group("RelayMessage JSON serialization", () {
    test("key_exchange serialization has type=key_exchange and publicKey", () {
      const msg = RelayMessage.keyExchange(publicKey: "base64urlPublicKey");
      final json = msg.toJson();

      expect(json["type"], equals("key_exchange"));
      expect(json["publicKey"], equals("base64urlPublicKey"));
    });

    test("key_exchange deserialization restores fields", () {
      final json = {"type": "key_exchange", "publicKey": "abc123"};
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<RelayKeyExchange>());
      final ke = msg as RelayKeyExchange;
      expect(ke.publicKey, equals("abc123"));
    });

    test("ready deserialization includes publicKey and roomKey fields", () {
      final json = {
        "type": "ready",
        "publicKey": "bridgePublicKeyBase64",
        "roomKey": "roomKeyBase64url",
      };
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<RelayReady>());
      final ready = msg as RelayReady;
      expect(ready.publicKey, equals("bridgePublicKeyBase64"));
      expect(ready.roomKey, equals("roomKeyBase64url"));
    });

    test("ready serialization round-trips all fields", () {
      const msg = RelayMessage.ready(
        publicKey: "bridgePubKey",
        roomKey: "roomKeyEncoded",
      );
      final json = msg.toJson();
      final restored = RelayMessage.fromJson(json);

      expect(restored, isA<RelayReady>());
      final ready = restored as RelayReady;
      expect(ready.publicKey, equals("bridgePubKey"));
      expect(ready.roomKey, equals("roomKeyEncoded"));
    });

    test("resume serialization has type=resume", () {
      const msg = RelayMessage.resume();
      final json = msg.toJson();

      expect(json["type"], equals("resume"));
    });

    test("resume deserialization produces RelayResume", () {
      final json = {"type": "resume"};
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<RelayResume>());
    });

    test("resume_ack deserialization produces RelayResumeAck", () {
      final json = {"type": "resume_ack"};
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<RelayResumeAck>());
    });

    test("resume_ack serialization has type=resume_ack", () {
      const msg = RelayMessage.resumeAck();
      final json = msg.toJson();

      expect(json["type"], equals("resume_ack"));
    });

    test("rekey_required deserialization produces RelayRekeyRequired", () {
      final json = {"type": "rekey_required"};
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<RelayRekeyRequired>());
    });

    test("rekey_required serialization has type=rekey_required", () {
      const msg = RelayMessage.rekeyRequired();
      final json = msg.toJson();

      expect(json["type"], equals("rekey_required"));
    });

    test("auth message serialization includes type, token, and role fields", () {
      const msg = RelayMessage.auth(token: "jwt_bearer_token", role: "phone");
      final json = msg.toJson();

      expect(json["type"], equals("auth"));
      expect(json["token"], equals("jwt_bearer_token"));
      expect(json["role"], equals("phone"));
    });

    test("auth message deserialization restores token and role", () {
      final json = {"type": "auth", "token": "my_token_value", "role": "phone"};
      final msg = RelayMessage.fromJson(json);

      expect(msg, isA<AuthRelayMessage>());
      final auth = msg as AuthRelayMessage;
      expect(auth.token, equals("my_token_value"));
      expect(auth.role, equals("phone"));
    });

    test("fromJson throws on unknown type", () {
      final json = {"type": "unknown_type"};

      expect(() => RelayMessage.fromJson(json), throwsA(anything));
    });

    test("request serialization round-trips all fields", () {
      const msg = RelayMessage.request(
        id: "req-001",
        method: "GET",
        path: "/project",
        headers: {"Authorization": "Bearer token"},
        body: null,
      );
      final json = msg.toJson();
      final restored = RelayMessage.fromJson(json);

      expect(restored, isA<RelayRequest>());
      final req = restored as RelayRequest;
      expect(req.id, equals("req-001"));
      expect(req.method, equals("GET"));
      expect(req.path, equals("/project"));
      expect(req.headers["Authorization"], equals("Bearer token"));
      expect(req.body, isNull);
    });

    test("response serialization round-trips all fields", () {
      const msg = RelayMessage.response(
        id: "req-001",
        status: 200,
        headers: {"Content-Type": "application/json"},
        body: '{"ok":true}',
      );
      final json = msg.toJson();
      final restored = RelayMessage.fromJson(json);

      expect(restored, isA<RelayResponse>());
      final resp = restored as RelayResponse;
      expect(resp.id, equals("req-001"));
      expect(resp.status, equals(200));
      expect(resp.body, equals('{"ok":true}'));
    });
  });
}
