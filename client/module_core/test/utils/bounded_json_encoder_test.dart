import "dart:convert";
import "dart:typed_data";

import "package:sesori_dart_core/src/utils/bounded_json_encoder.dart";
import "package:test/test.dart";

void main() {
  test("matches compact jsonEncode bytes and map insertion order", () async {
    final value = <String, Object?>{
      "z": 'quote: " slash: \\ control: \n emoji: 😀',
      "a": <Object?>[true, null, -1, 1.5],
      "nested": <String, Object?>{"second": 2, "first": 1},
    };
    final encoder = BoundedJsonEncoder(chunkSize: 5, yieldTurn: () async {});

    final actual = await encoder.convert(value: value);

    expect(actual, utf8.encode(jsonEncode(value)));
  });

  test("base64 source stays byte exact across view-backed chunks", () async {
    final storage = Uint8List.fromList(List<int>.generate(31, (index) => index));
    final source = Uint8List.sublistView(storage, 4, 27);
    final value = <String, Object?>{"base64": BoundedBase64Value(bytes: source)};
    var yields = 0;
    final encoder = BoundedJsonEncoder(
      chunkSize: 7,
      yieldTurn: () async {
        yields++;
      },
    );
    final expected = jsonEncode(<String, Object?>{"base64": base64Encode(source)});

    final actual = await encoder.convertToString(value: value);

    expect(actual, expected);
    expect(yields, (utf8.encode(expected).length - 1) ~/ 7);
    storage[4] = 255;
    expect(source.first, 255);
  });

  test("yields deterministically between bounded output chunks", () async {
    var yields = 0;
    final encoder = BoundedJsonEncoder(
      chunkSize: 4,
      yieldTurn: () async {
        yields++;
      },
    );
    final expected = utf8.encode(jsonEncode(<String, Object?>{"body": "abcdefghij"}));

    final actual = await encoder.convert(value: <String, Object?>{"body": "abcdefghij"});

    expect(actual, expected);
    expect(yields, expected.length ~/ 4);
  });

  test("reduced max-path fixture crosses many chunks without a large allocation", () async {
    const maxFixtureBytes = 257;
    var yields = 0;
    final encoder = BoundedJsonEncoder(
      chunkSize: 16,
      yieldTurn: () async {
        yields++;
      },
    );
    final body = "x" * maxFixtureBytes;
    final expected = utf8.encode(jsonEncode(<String, Object?>{"body": body}));

    final actual = await encoder.convert(value: <String, Object?>{"body": body});

    expect(actual, expected);
    expect(actual.length, greaterThan(maxFixtureBytes));
    expect(yields, expected.length ~/ 16);
  });
}
