import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("MessageError.kind", () {
    Map<String, dynamic> errorJson({required Object? kind}) => {
      "role": "error",
      "id": "msg-1",
      "sessionID": "session-1",
      "agent": null,
      "modelID": null,
      "providerID": null,
      "errorName": "Fixture",
      "errorMessage": "Fixture text",
      "time": null,
      "kind": ?kind,
    };

    test("defaults an older bridge payload to failure", () {
      final message = Message.fromJson(errorJson(kind: null));

      expect((message as MessageError).kind, MessageErrorKind.failure);
    });

    test("decodes a future kind as failure", () {
      final message = Message.fromJson(errorJson(kind: "future-kind"));

      expect((message as MessageError).kind, MessageErrorKind.failure);
    });

    test("round-trips each kind on the error wire envelope", () {
      for (final kind in MessageErrorKind.values) {
        final message = Message.error(
          id: "msg-1",
          sessionID: "session-1",
          agent: null,
          modelID: null,
          providerID: null,
          errorName: "Fixture",
          errorMessage: "Fixture text",
          kind: kind,
          time: null,
        );

        final json = message.toJson();

        expect(json["kind"], kind.name);
        expect(Message.fromJson(json), message);
      }
    });
  });
}
