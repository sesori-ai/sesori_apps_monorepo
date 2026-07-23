import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("jsonSchemaForLog", () {
    test("redacts strings while retaining opted-in enum values", () {
      final schema = jsonSchemaForLog(
        value: {
          "type": "response_item",
          "payload": {
            "type": "new_tool_call",
            "role": "assistant",
            "query": "secret source content",
            "nested": {
              "type": "nested_enum",
              "token": "secret-token",
            },
          },
        },
        enumKeyNames: const {"type", "role"},
      );

      expect(
        schema,
        '{type:enum("response_item"),payload:{type:enum("new_tool_call"),'
        'role:enum("assistant"),query:String,nested:{type:enum("nested_enum"),'
        "token:String}}}",
      );
      expect(schema, isNot(contains("secret")));
    });

    test("redacts enum values that are not identifier tokens", () {
      final schema = jsonSchemaForLog(
        value: {
          "type": "source code or prompt",
          "role": "assistant\nsecret",
        },
        enumKeyNames: const {"type", "role"},
      );

      expect(schema, "{type:String,role:String}");
    });

    test("bounds collection breadth and depth", () {
      final schema = jsonSchemaForLog(
        value: {
          "items": List<Object?>.generate(
            10,
            (index) => index == 0
                ? {
                    "one": {
                      "two": {
                        "three": {
                          "four": {"secret": "value"},
                        },
                      },
                    },
                  }
                : index,
          ),
        },
        enumKeyNames: const {},
      );

      expect(
        schema,
        "{items:List<{one:{two:{three:Map}}}|int,…>}",
      );
      expect(schema, isNot(contains("secret")));
      expect(schema, isNot(contains("value")));
    });
  });
}
