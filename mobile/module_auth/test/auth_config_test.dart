import "package:sesori_auth/sesori_auth.dart";
import "package:test/test.dart";

void main() {
  group("OAuthProvider.fromKey", () {
    test("returns github provider for github key", () {
      final result = OAuthProvider.fromKey("github");

      expect(result, equals(OAuthProvider.github));
    });

    test("returns google provider for google key", () {
      final result = OAuthProvider.fromKey("google");

      expect(result, equals(OAuthProvider.google));
    });

    test("returns null for unknown key", () {
      final result = OAuthProvider.fromKey("unknown");

      expect(result, isNull);
    });

    test("returns null for null key", () {
      final result = OAuthProvider.fromKey(null);

      expect(result, isNull);
    });

    test("returns null for empty string key", () {
      final result = OAuthProvider.fromKey("");

      expect(result, isNull);
    });

    test("returns null for case-sensitive mismatch", () {
      final result = OAuthProvider.fromKey("GitHub");

      expect(result, isNull);
    });

    test("returns null for whitespace-padded key", () {
      final result = OAuthProvider.fromKey(" github ");

      expect(result, isNull);
    });
  });

  group("OAuthProvider properties", () {
    test("github provider has correct key and label", () {
      expect(OAuthProvider.github.key, equals("github"));
      expect(OAuthProvider.github.label, equals("GitHub"));
    });

    test("google provider has correct key and label", () {
      expect(OAuthProvider.google.key, equals("google"));
      expect(OAuthProvider.google.label, equals("Google"));
    });
  });
}
