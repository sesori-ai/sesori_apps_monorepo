import "package:sesori_auth/sesori_auth.dart";
import "package:test/test.dart";

void main() {
  test("parsing diagnostics omit payload without changing typed data or JSON parsing", () {
    const payload = '{"transcript":"private conversation"}';
    final error = ApiError.jsonParsing(payload) as JsonParsingError;
    final decoded = JsonParsingError.fromJson({"jsonString": payload});
    expect(error.jsonString, payload);
    expect(decoded.jsonString, payload);
    expect(error.toString(), "ApiError.jsonParsing(response body omitted)");
    expect(decoded.toString(), error.toString());
  });

  test("other error variants retain their diagnostic context", () {
    expect(ApiError.dartHttpClient(StateError("disk /tmp/repo")).toString(), contains("Bad state: disk /tmp/repo"));
    expect(
      ApiError.nonSuccessCode(errorCode: 409, rawErrorString: "repair /tmp/repo").toString(),
      "ApiError.nonSuccessCode(errorCode: 409, rawErrorString: repair /tmp/repo)",
    );
    expect(ApiError.generic().toString(), "ApiError.generic()");
    expect(ApiError.notAuthenticated().toString(), "ApiError.notAuthenticated()");
    expect(ApiError.emptyResponse().toString(), "ApiError.emptyResponse()");
  });
}
