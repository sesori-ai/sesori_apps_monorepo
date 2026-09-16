import "package:freezed_annotation/freezed_annotation.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:test/test.dart";

void main() {
  test("parsing diagnostics omit payload without changing typed data or JSON parsing", () {
    const payload = '{"transcript":"private conversation"}';
    final error = ApiError.jsonParsing(jsonString: payload, innerError: null) as JsonParsingError;
    final decoded = JsonParsingError.fromJson({"jsonString": payload});
    expect(error.jsonString, payload);
    expect(decoded.jsonString, payload);
    expect(decoded.innerError, isNull);
    expect(error.toString(), "ApiError.jsonParsing(response body omitted)");
    expect(decoded.toString(), error.toString());
  });

  test("syntax causes retain identity and offset without source or message payloads", () {
    const cause = FormatException("private explanation", "private transcript", 4);
    final error = ApiError.jsonParsing(jsonString: "private transcript", innerError: cause) as JsonParsingError;
    expect(error.innerError, same(cause));
    expect(error.toString(), contains("FormatException; offset=4"));
    expect(error.toString(), isNot(contains("private")));
  });

  test("checked conversion diagnostics retain schema metadata and the original cause", () {
    late final CheckedFromJsonException cause;
    try {
      $checkedCreate<int>("CounterDto", {
        "count": "private transcript",
      }, (convert) => convert("count", (v) => v as int));
    } on CheckedFromJsonException catch (error) {
      cause = error;
    }
    final error = ApiError.jsonParsing(jsonString: "private transcript", innerError: cause) as JsonParsingError;
    expect(error.innerError, same(cause));
    expect(error.toString(), contains("class=CounterDto; key=count; innerType="));
    expect(error.toString(), contains("TypeError"));
    expect(error.toString(), isNot(contains("private transcript")));
    final native = ApiError.jsonParsing(jsonString: "private transcript", innerError: cause.innerError);
    expect(native.toString(), contains("String"));
    expect(native.toString(), contains("int"));
    expect(native.toString(), isNot(contains("private transcript")));
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
