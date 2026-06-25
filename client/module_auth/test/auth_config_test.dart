import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("AuthProvider.fromKey", () {
    test("returns github provider for github key", () {
      final result = AuthProvider.fromKey("github");

      expect(result, equals(AuthProvider.github));
    });

    test("returns google provider for google key", () {
      final result = AuthProvider.fromKey("google");

      expect(result, equals(AuthProvider.google));
    });

    test("returns null for unknown key", () {
      final result = AuthProvider.fromKey("unknown");

      expect(result, isNull);
    });

    test("returns null for null key", () {
      final result = AuthProvider.fromKey(null);

      expect(result, isNull);
    });

    test("returns null for empty string key", () {
      final result = AuthProvider.fromKey("");

      expect(result, isNull);
    });

    test("returns null for case-sensitive mismatch", () {
      final result = AuthProvider.fromKey("GitHub");

      expect(result, isNull);
    });

    test("returns null for whitespace-padded key", () {
      final result = AuthProvider.fromKey(" github ");

      expect(result, isNull);
    });
  });

  group("AuthProvider properties", () {
    test("github provider has correct key and label", () {
      expect(AuthProvider.github.key, equals("github"));
      expect(AuthProvider.github.label, equals("GitHub"));
    });

    test("google provider has correct key and label", () {
      expect(AuthProvider.google.key, equals("google"));
      expect(AuthProvider.google.label, equals("Google"));
    });
  });
}
