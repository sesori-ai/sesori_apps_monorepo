import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("ReplyToPermissionRequest", () {
    test("constructs with required named parameters", () {
      const request = ReplyToPermissionRequest(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      expect(request.requestId, "perm-123");
      expect(request.sessionId, "ses-456");
      expect(request.reply, PermissionReply.once);
    });

    test("toJson produces correct JSON", () {
      const request = ReplyToPermissionRequest(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      final json = request.toJson();

      expect(json["requestId"], "perm-123");
      expect(json["sessionId"], "ses-456");
      expect(json["reply"], "once");
    });

    test("fromJson roundtrip", () {
      const original = ReplyToPermissionRequest(
        requestId: "perm-123",
        sessionId: "ses-456",
        reply: PermissionReply.once,
      );

      final json = original.toJson();
      final restored = ReplyToPermissionRequest.fromJson(json);

      expect(restored.requestId, original.requestId);
      expect(restored.sessionId, original.sessionId);
      expect(restored.reply, original.reply);
    });

    test("supports reply value always", () {
      const request = ReplyToPermissionRequest(
        requestId: "perm-789",
        sessionId: "ses-456",
        reply: PermissionReply.always,
      );

      final json = request.toJson();
      final restored = ReplyToPermissionRequest.fromJson(json);

      expect(restored.reply, PermissionReply.always);
    });

    test("supports reply value reject", () {
      const request = ReplyToPermissionRequest(
        requestId: "perm-789",
        sessionId: "ses-456",
        reply: PermissionReply.reject,
      );

      final json = request.toJson();
      final restored = ReplyToPermissionRequest.fromJson(json);

      expect(restored.reply, PermissionReply.reject);
    });
  });
}
