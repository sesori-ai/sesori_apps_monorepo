import "dart:convert";

import "package:sesori_bridge/src/auth/jwt_expiry.dart";
import "package:test/test.dart";

void main() {
  group("parseJwtExpiry", () {
    test("valid JWT with exp claim returns correct DateTime in UTC", () {
      // Create a valid JWT with exp claim
      // exp: 1700000000 (Nov 15, 2023 13:26:40 UTC)
      final payload = jsonEncode({"exp": 1700000000});
      final encodedPayload = base64Url.encode(utf8.encode(payload)).replaceAll("=", "");
      final token = "header.$encodedPayload.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNotNull);
      expect(result!.isUtc, true);
      expect(result.millisecondsSinceEpoch, 1700000000 * 1000);
    });

    test("JWT with missing exp claim returns null", () {
      // Create a JWT without exp claim
      final payload = jsonEncode({"sub": "user123", "iat": 1600000000});
      final encodedPayload = base64Url.encode(utf8.encode(payload)).replaceAll("=", "");
      final token = "header.$encodedPayload.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNull);
    });

    test("malformed base64 payload returns null", () {
      // Invalid base64 characters
      const token = "header.!!!invalid!!!.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNull);
    });

    test("non-JWT string with no dots returns null", () {
      const token = "notajwt";

      final result = parseJwtExpiry(token);

      expect(result, isNull);
    });

    test("empty string returns null", () {
      final result = parseJwtExpiry("");

      expect(result, isNull);
    });

    test("JWT with 3 parts but invalid JSON payload returns null", () {
      // Valid base64 but not valid JSON
      final invalidPayload = base64Url.encode(utf8.encode("not json")).replaceAll("=", "");
      final token = "header.$invalidPayload.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNull);
    });

    test("JWT with exp claim as string instead of int returns null", () {
      // exp as string instead of int
      final payload = jsonEncode({"exp": "1700000000"});
      final encodedPayload = base64Url.encode(utf8.encode(payload)).replaceAll("=", "");
      final token = "header.$encodedPayload.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNull);
    });

    test("expired JWT still returns the DateTime", () {
      // exp: 1000000000 (Sep 9, 2001 01:46:40 UTC) - in the past
      final payload = jsonEncode({"exp": 1000000000});
      final encodedPayload = base64Url.encode(utf8.encode(payload)).replaceAll("=", "");
      final token = "header.$encodedPayload.signature";

      final result = parseJwtExpiry(token);

      expect(result, isNotNull);
      expect(result!.millisecondsSinceEpoch, 1000000000 * 1000);
      expect(result.isBefore(DateTime.now()), true);
    });
  });
}
