// ignore_for_file: no_slop_linter/avoid_as_cast, no_slop_linter/prefer_specific_type
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("jsonCastMap", () {
    test("casts a decoded JSON map", () {
      final result = jsonCastMap(<String, dynamic>{"key": "value"});

      expect(result, {"key": "value"});
    });

    test("rejects decoded non-map values", () {
      final value = <int>[1, 2, 3];

      expect(
        () => jsonCastMap(value),
        throwsA(isA<FormatException>().having((error) => error.source, "source", same(value))),
      );
    });
  });

  group("JSON value helpers", () {
    test("returns string-keyed maps only", () {
      expect(asStringKeyedMap(value: <String, Object?>{"key": "value"}), {"key": "value"});
      expect(asStringKeyedMap(value: "value"), isNull);
    });

    test("returns non-empty strings without trimming", () {
      expect(nonEmptyString(value: "value"), "value");
      expect(nonEmptyString(value: " "), " ");
      expect(nonEmptyString(value: ""), isNull);
      expect(nonEmptyString(value: 1), isNull);
    });
  });

  group("jsonDecodeMap", () {
    test("decodes valid JSON map", () {
      const json = '{"key": "value", "number": 42}';
      final result = jsonDecodeMap(json);

      expect(result, isA<Map<String, dynamic>>());
      expect(result["key"], equals("value"));
      expect(result["number"], equals(42));
    });

    test("throws FormatException for non-map JSON", () {
      const json = "[1, 2, 3]";

      expect(
        () => jsonDecodeMap(json),
        throwsA(isA<FormatException>()),
      );
    });

    test("throws FormatException for JSON string", () {
      const json = '"just a string"';

      expect(
        () => jsonDecodeMap(json),
        throwsA(isA<FormatException>()),
      );
    });

    test("decodes nested JSON map", () {
      const json = '{"outer": {"inner": "value"}}';
      final result = jsonDecodeMap(json);

      expect(result["outer"], isA<Map<String, dynamic>>());
      expect((result["outer"] as Map<String, dynamic>)["inner"], equals("value"));
    });
  });

  group("StringExtensions", () {
    group("normalize", () {
      test("returns trimmed text", () {
        expect("  value  ".normalize(), equals("value"));
      });

      test("returns null for whitespace-only text", () {
        expect("   ".normalize(), isNull);
        expect("".normalize(), isNull);
      });
    });

    group("chunked", () {
      test("chunks string into equal parts", () {
        const str = "abcdef";
        final result = str.chunked(chunkSize: 2);

        expect(result, equals(["ab", "cd", "ef"]));
      });

      test("chunks string with remainder", () {
        const str = "abcde";
        final result = str.chunked(chunkSize: 2);

        expect(result, equals(["ab", "cd", "e"]));
      });

      test("returns single chunk for chunkSize larger than string", () {
        const str = "abc";
        final result = str.chunked(chunkSize: 5);

        expect(result, equals(["abc"]));
      });

      test("chunks empty string", () {
        const str = "";
        final result = str.chunked(chunkSize: 2);

        expect(result, equals([]));
      });

      test("chunks with chunkSize of 1", () {
        const str = "abc";
        final result = str.chunked(chunkSize: 1);

        expect(result, equals(["a", "b", "c"]));
      });
    });
  });
}
