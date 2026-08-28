import "package:deepseek_plugin/deepseek_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  const parser = DeepSeekMessageTimeParser();

  test("parses valid DeepSeek message creation time", () {
    expect(
      parser.parse({
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": 1700000000123},
        },
      }),
      const PluginMessageTime(created: 1700000000123, completed: null),
    );
  });

  test("rejects omitted, null, invalid, negative, and unsafe times", () {
    for (final params in <Map<String, dynamic>>[
      {},
      {"_meta": null},
      {
        "_meta": {"sesori.ai/deepseek": null},
      },
      {
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": null},
        },
      },
      {
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": 1.0},
        },
      },
      {
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": "1"},
        },
      },
      {
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": -1},
        },
      },
      {
        "_meta": {
          "sesori.ai/deepseek": {"messageCreatedAt": 9007199254740992},
        },
      },
    ]) {
      expect(parser.parse(params), isNull, reason: "$params");
    }
  });
}
