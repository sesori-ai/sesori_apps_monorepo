import "package:json_annotation/json_annotation.dart" show CheckedFromJsonException;
import "package:sesori_tool_interface/sesori_tool_interface.dart";
import "package:test/test.dart";

const _parser = SesoriToolArgumentParser(
  nestedPlaces: {"_Option": "options[]."},
  kindFields: {
    "when": {
      "in": ["minutes"],
      "daily": ["time"],
    },
  },
);

/// Fails as checked decoding does when [key] is wrong in [json].
Never _failOn({required Map<String, dynamic> json, required String key, required String className}) {
  throw CheckedFromJsonException(json, key, className, "wrong");
}

String _reason(void Function() parse) {
  try {
    parse();
  } on InvalidToolArguments catch (error) {
    return error.reason;
  }
  fail("Expected InvalidToolArguments.");
}

void main() {
  test("empty strings read as absent", () {
    final parsed = _parser.parse(json: {"a": "", "b": "x", "c": 1}, fromJson: (json) => json);

    expect(parsed, {"b": "x", "c": 1});
  });

  test("a missing or invalid field is named, with its nested place", () {
    expect(
      _reason(
        () => _parser.parse(
          json: {"label": "x"},
          fromJson: (json) => _failOn(json: json, key: "id", className: "_Option"),
        ),
      ),
      "options[].id is required.",
    );
    expect(
      _reason(
        () => _parser.parse(
          json: {"page": "two"},
          fromJson: (json) => _failOn(json: json, key: "page", className: "_Other"),
        ),
      ),
      "page is not valid; see its input schema.",
    );
  });

  test("a nested kind must be known and carry its fields", () {
    expect(
      _reason(
        () => _parser.parse(
          json: {
            "when": {"kind": "weekly"},
          },
          fromJson: (json) => json,
        ),
      ),
      "when.kind must be one of in, daily.",
    );
    expect(
      _reason(
        () => _parser.parse(
          json: {
            "when": {"kind": "daily"},
          },
          fromJson: (json) => json,
        ),
      ),
      "when.time is required when when.kind is daily.",
    );
  });

  test("blank text is required or absent", () {
    expect(_reason(() => requiredToolText(value: "  ", field: "title")), "title is required.");
    expect(requiredToolText(value: "Hi", field: "title"), "Hi");
    expect(optionalToolText(value: " "), isNull);
    expect(optionalToolText(value: null), isNull);
    expect(optionalToolText(value: "x"), "x");
  });
}
