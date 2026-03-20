import "package:flutter_test/flutter_test.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/converters/http_method_converter.dart";

void main() {
  group("HttpMethodConverter", () {
    const converter = HttpMethodConverter();

    group("fromJson", () {
      test("converts GET string to HttpMethod.get", () {
        final result = converter.fromJson("GET");
        expect(result, equals(HttpMethod.get));
      });

      test("converts POST string to HttpMethod.post", () {
        final result = converter.fromJson("POST");
        expect(result, equals(HttpMethod.post));
      });

      test("converts PATCH string to HttpMethod.patch", () {
        final result = converter.fromJson("PATCH");
        expect(result, equals(HttpMethod.patch));
      });

      test("converts DELETE string to HttpMethod.delete", () {
        final result = converter.fromJson("DELETE");
        expect(result, equals(HttpMethod.delete));
      });

      test("throws ArgumentError for unknown method", () {
        expect(
          () => converter.fromJson("PUT"),
          throwsA(isA<ArgumentError>()),
        );
      });

      test("throws ArgumentError for lowercase method", () {
        expect(
          () => converter.fromJson("get"),
          throwsA(isA<ArgumentError>()),
        );
      });

      test("throws ArgumentError for empty string", () {
        expect(
          () => converter.fromJson(""),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group("toJson", () {
      test("converts HttpMethod.get to GET string", () {
        final result = converter.toJson(HttpMethod.get);
        expect(result, equals("GET"));
      });

      test("converts HttpMethod.post to POST string", () {
        final result = converter.toJson(HttpMethod.post);
        expect(result, equals("POST"));
      });

      test("converts HttpMethod.patch to PATCH string", () {
        final result = converter.toJson(HttpMethod.patch);
        expect(result, equals("PATCH"));
      });

      test("converts HttpMethod.delete to DELETE string", () {
        final result = converter.toJson(HttpMethod.delete);
        expect(result, equals("DELETE"));
      });
    });

    group("round-trip conversion", () {
      test("GET round-trips correctly", () {
        const original = HttpMethod.get;
        final json = converter.toJson(original);
        final restored = converter.fromJson(json);

        expect(restored, equals(original));
      });

      test("POST round-trips correctly", () {
        const original = HttpMethod.post;
        final json = converter.toJson(original);
        final restored = converter.fromJson(json);

        expect(restored, equals(original));
      });

      test("PATCH round-trips correctly", () {
        const original = HttpMethod.patch;
        final json = converter.toJson(original);
        final restored = converter.fromJson(json);

        expect(restored, equals(original));
      });

      test("DELETE round-trips correctly", () {
        const original = HttpMethod.delete;
        final json = converter.toJson(original);
        final restored = converter.fromJson(json);

        expect(restored, equals(original));
      });
    });
  });
}
