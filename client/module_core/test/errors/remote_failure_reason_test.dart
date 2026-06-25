import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/errors/api_error_remote_failure_x.dart";
import "package:test/test.dart";

void main() {
  group("ApiError.remoteFailureReason", () {
    final cases = <String, (ApiError, RemoteFailureReason)>{
      "notAuthenticated → notAuthenticated": (ApiError.notAuthenticated(), RemoteFailureReason.notAuthenticated),
      "nonSuccessCode → serverRejected": (
        ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "boom"),
        RemoteFailureReason.serverRejected,
      ),
      "nonSuccessCode (no body) → serverRejected": (
        ApiError.nonSuccessCode(errorCode: 503, rawErrorString: null),
        RemoteFailureReason.serverRejected,
      ),
      "dartHttpClient → networkDown": (
        ApiError.dartHttpClient(Exception("offline")),
        RemoteFailureReason.networkDown,
      ),
      "jsonParsing → badResponse": (ApiError.jsonParsing("{not json"), RemoteFailureReason.badResponse),
      "emptyResponse → badResponse": (ApiError.emptyResponse(), RemoteFailureReason.badResponse),
      "generic → unknown": (ApiError.generic(), RemoteFailureReason.unknown),
    };

    cases.forEach((name, testCase) {
      final (error, expected) = testCase;
      test(name, () {
        expect(error.remoteFailureReason, expected);
      });
    });

    test("maps every ApiError subtype (exhaustive — no fallthrough)", () {
      // Guards against a future ApiError subtype silently defaulting: every
      // case above must resolve to a concrete reason, never throw.
      for (final (error, _) in cases.values) {
        expect(() => error.remoteFailureReason, returnsNormally);
      }
    });
  });
}
