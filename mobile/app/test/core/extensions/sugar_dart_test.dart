import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/src/extensions/sugar_dart.dart";

void main() {
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
    group("ellipsizeStart", () {
      test("returns original string if shorter than maxLen", () {
        const str = "hello";
        expect(str.ellipsizeStart(10), equals("hello"));
      });

      test("ellipsizes start when longer than maxLen", () {
        const str = "hello world";
        expect(str.ellipsizeStart(5), equals("...world"));
      });

      test("ellipsizes start with exact maxLen", () {
        const str = "hello";
        expect(str.ellipsizeStart(5), equals("hello"));
      });

      test("ellipsizes start with single character maxLen", () {
        const str = "hello";
        expect(str.ellipsizeStart(1), equals("...o"));
      });
    });

    group("capitalizeWord", () {
      test("capitalizes first letter and lowercases rest", () {
        const str = "hELLO";
        expect(str.capitalizeWord(), equals("Hello"));
      });

      test("returns empty string for empty input", () {
        const str = "";
        expect(str.capitalizeWord(), equals(""));
      });

      test("capitalizes single character", () {
        const str = "a";
        expect(str.capitalizeWord(), equals("A"));
      });

      test("handles already capitalized word", () {
        const str = "Hello";
        expect(str.capitalizeWord(), equals("Hello"));
      });
    });

    group("chunked", () {
      test("chunks string into equal parts", () {
        const str = "abcdef";
        final result = str.chunked(2);

        expect(result, equals(["ab", "cd", "ef"]));
      });

      test("chunks string with remainder", () {
        const str = "abcde";
        final result = str.chunked(2);

        expect(result, equals(["ab", "cd", "e"]));
      });

      test("returns single chunk for chunkSize larger than string", () {
        const str = "abc";
        final result = str.chunked(5);

        expect(result, equals(["abc"]));
      });

      test("chunks empty string", () {
        const str = "";
        final result = str.chunked(2);

        expect(result, equals([]));
      });

      test("chunks with chunkSize of 1", () {
        const str = "abc";
        final result = str.chunked(1);

        expect(result, equals(["a", "b", "c"]));
      });
    });
  });

  group("MapExtensions", () {
    group("mapValues", () {
      test("transforms all values in map", () {
        final map = {"a": 1, "b": 2, "c": 3};
        final result = map.mapValues((v) => v * 2);

        expect(result, equals({"a": 2, "b": 4, "c": 6}));
      });

      test("preserves keys while transforming values", () {
        final map = {"x": "hello", "y": "world"};
        final result = map.mapValues((v) => v.length);

        expect(result, equals({"x": 5, "y": 5}));
      });

      test("handles empty map", () {
        final map = <String, int>{};
        final result = map.mapValues((v) => v * 2);

        expect(result, isEmpty);
      });
    });

    group("whereKey", () {
      test("filters map by key predicate", () {
        final map = {"a": 1, "b": 2, "c": 3};
        final result = map.whereKey((k) => k == "a" || k == "c");

        expect(result, equals({"a": 1, "c": 3}));
      });

      test("returns empty map when no keys match", () {
        final map = {"a": 1, "b": 2};
        final result = map.whereKey((k) => k == "z");

        expect(result, isEmpty);
      });

      test("returns all entries when all keys match", () {
        final map = {"a": 1, "b": 2};
        final result = map.whereKey((k) => true);

        expect(result, equals(map));
      });
    });

    group("whereKeyType", () {
      test("filters map entries by key type", () {
        final map = <dynamic, String>{
          "string_key": "value1",
          123: "value2",
          "another_string": "value3",
        };
        final result = map.whereKeyType<String>();

        expect(result.length, equals(2));
        expect(result["string_key"], equals("value1"));
        expect(result["another_string"], equals("value3"));
      });

      test("returns empty map when no keys match type", () {
        final map = <dynamic, String>{
          1: "value1",
          2: "value2",
        };
        final result = map.whereKeyType<String>();

        expect(result, isEmpty);
      });

      test("returns all entries when all keys match type", () {
        final map = <dynamic, String>{
          "a": "value1",
          "b": "value2",
        };
        final result = map.whereKeyType<String>();

        expect(result, equals(map));
      });
    });
  });
}
