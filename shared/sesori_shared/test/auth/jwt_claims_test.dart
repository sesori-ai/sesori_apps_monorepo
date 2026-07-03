import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

String _jwtWithPayload(Map<String, dynamic> payload) {
  final encodedPayload = base64Url.encode(utf8.encode(jsonEncode(payload))).replaceAll("=", "");
  return "header.$encodedPayload.signature";
}

void main() {
  group("parseJwtUserId", () {
    test("valid JWT with userId claim returns the userId", () {
      final token = _jwtWithPayload({"userId": "user-123", "exp": 1700000000});

      expect(parseJwtUserId(token), equals("user-123"));
    });

    test("JWT with missing userId claim returns null", () {
      final token = _jwtWithPayload({"sub": "user-123", "exp": 1700000000});

      expect(parseJwtUserId(token), isNull);
    });

    test("JWT with non-String userId claim returns null", () {
      final token = _jwtWithPayload({"userId": 123});

      expect(parseJwtUserId(token), isNull);
    });

    test("malformed base64 payload returns null", () {
      expect(parseJwtUserId("header.!!!invalid!!!.signature"), isNull);
    });

    test("non-JWT string with no dots returns null", () {
      expect(parseJwtUserId("notajwt"), isNull);
    });

    test("empty string returns null", () {
      expect(parseJwtUserId(""), isNull);
    });

    test("JWT with 3 parts but invalid JSON payload returns null", () {
      final invalidPayload = base64Url.encode(utf8.encode("not json")).replaceAll("=", "");

      expect(parseJwtUserId("header.$invalidPayload.signature"), isNull);
    });
  });

  group("parseJwtExpiry", () {
    test("valid JWT with exp claim returns correct DateTime in UTC", () {
      final token = _jwtWithPayload({"exp": 1700000000});

      final result = parseJwtExpiry(token);

      expect(result, isNotNull);
      expect(result!.isUtc, isTrue);
      expect(result.millisecondsSinceEpoch, equals(1700000000 * 1000));
    });

    test("JWT with missing exp claim returns null", () {
      final token = _jwtWithPayload({"userId": "user-123"});

      expect(parseJwtExpiry(token), isNull);
    });

    test("JWT with exp claim as string returns null", () {
      final token = _jwtWithPayload({"exp": "1700000000"});

      expect(parseJwtExpiry(token), isNull);
    });

    test("JWT with exp outside DateTime's supported range returns null", () {
      // 1e14 seconds → 1e17 ms, beyond DateTime's ±8.64e15 ms bound.
      final token = _jwtWithPayload({"exp": 100000000000000});

      expect(parseJwtExpiry(token), isNull);
    });
  });
}
