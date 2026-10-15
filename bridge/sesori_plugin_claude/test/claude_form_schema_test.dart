import "package:claude_plugin/src/claude_form_schema.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("opaque fields preserve typed defaults, native keys and distinct option labels", () {
    final schema = ClaudeFormSchema.parse(
      schema: {
        "type": "object",
        "required": ["native-boolean"],
        "properties": {
          "native-text": {"type": "string", "title": "Note", "description": "Fixture", "default": "", "maxLength": 3},
          "native-integer": {"type": "integer", "minimum": 0, "maximum": 2, "default": 0},
          "native-number": {"type": "number", "minimum": 0, "maximum": 2, "default": 1.5},
          "native-boolean": {"type": "boolean", "default": false},
          "native-choice": {
            "type": "string",
            "default": "pro",
            "oneOf": [
              {"const": "basic", "title": "Basic plan"},
              {"const": "pro", "title": "Pro plan"},
            ],
          },
          "native-array": {
            "type": "array",
            "minItems": 1,
            "maxItems": 2,
            "default": ["a"],
            "items": {
              "type": "string",
              "anyOf": [
                {"const": "a", "title": "Label A"},
                {"const": "b"},
              ],
            },
          },
        },
      },
    )!;
    expect(schema.fields.map((field) => field.id), List.generate(6, (index) => "field-$index"));
    expect(schema.fields.first.label, "Note");
    expect(schema.fields.first.description, "Fixture");
    expect((schema.fields.first.schema as PluginFormTextSchema).defaultValue, "");
    expect((schema.fields[1].schema as PluginFormIntegerSchema).defaultValue, 0);
    expect((schema.fields[2].schema as PluginFormNumberSchema).defaultValue, 1.5);
    expect((schema.fields[3].schema as PluginFormBooleanSchema).defaultValue, false);
    expect(schema.fields[3].isRequired, isTrue);
    final choice = schema.fields[4].schema as PluginFormChoiceSchema;
    expect(choice.defaultOptionId, "option-1");
    expect(choice.options.last.label, "Pro plan");
    final array = schema.fields[5].schema as PluginFormChoicesSchema;
    expect(array.defaultOptionIds, ["option-0"]);
    expect(array.options.first.label, "Label A");
    final values = <String, PluginFormValue>{
      "field-0": const PluginFormTextValue(value: ""),
      "field-1": const PluginFormIntegerValue(value: 0),
      "field-2": const PluginFormNumberValue(value: 1.5),
      "field-3": const PluginFormBooleanValue(value: false),
      "field-4": const PluginFormChoiceValue(optionId: "option-1"),
      "field-5": PluginFormChoicesValue(optionIds: ["option-1", "option-0"]),
    };
    expect(schema.validate(values: values), isEmpty);
    expect(schema.encode(values: values), {
      "native-text": "",
      "native-integer": 0,
      "native-number": 1.5,
      "native-boolean": false,
      "native-choice": "pro",
      "native-array": ["b", "a"],
    });
    expect(schema.encode(values: {"field-3": const PluginFormBooleanValue(value: false)}), {"native-boolean": false});
    expect(schema.fields.clear, throwsUnsupportedError);
    expect(choice.options.clear, throwsUnsupportedError);
    expect(() => array.defaultOptionIds!.clear(), throwsUnsupportedError);
    expect(schema.toString(), isNot(contains("native-text")));
  });

  test("validation attributes required, type, bounds and choice failures without coercion", () {
    final schema = ClaudeFormSchema.parse(
      schema: {
        "type": "object",
        "required": ["text"],
        "properties": {
          "text": {"type": "string", "minLength": 1, "maxLength": 2},
          "integer": {"type": "integer", "minimum": 1, "maximum": 3},
          "number": {"type": "number", "minimum": 0, "maximum": 2},
          "choice": {
            "type": "string",
            "enum": ["a", "b"],
          },
          "array": {
            "type": "array",
            "minItems": 1,
            "maxItems": 2,
            "items": {
              "type": "string",
              "enum": ["a"],
            },
          },
        },
      },
    )!;
    expect(schema.validate(values: {}), {"field-0": PluginFormValidationIssue.required});
    expect(
      schema.validate(
        values: {
          "field-0": const PluginFormTextValue(value: "long"),
          "field-1": const PluginFormNumberValue(value: 1.5),
          "field-2": const PluginFormNumberValue(value: double.infinity),
          "field-3": const PluginFormChoiceValue(optionId: "a"),
          "field-4": PluginFormChoicesValue(optionIds: []),
          "native-key": const PluginFormTextValue(value: "unrecognized"),
        },
      ),
      {
        "field-0": PluginFormValidationIssue.invalidLength,
        "field-1": PluginFormValidationIssue.invalidType,
        "field-2": PluginFormValidationIssue.outOfRange,
        "field-3": PluginFormValidationIssue.invalidChoice,
        "field-4": PluginFormValidationIssue.invalidLength,
        "native-key": PluginFormValidationIssue.invalidChoice,
      },
    );
    expect(
      schema.validate(
        values: {
          "field-0": const PluginFormTextValue(value: "😀"),
          "field-1": const PluginFormIntegerValue(value: 4),
          "field-2": const PluginFormNumberValue(value: -1),
          "field-4": PluginFormChoicesValue(optionIds: ["native-value"]),
        },
      ),
      {
        "field-1": PluginFormValidationIssue.outOfRange,
        "field-2": PluginFormValidationIssue.outOfRange,
        "field-4": PluginFormValidationIssue.invalidChoice,
      },
    );
  });

  for (final field in <Map<String, Object?>>[
    {"type": "object", "properties": {}},
    {"type": "string", "format": "password"},
    {"type": "string", "format": "email"},
    {"type": "string", "pattern": "a+"},
    {"type": "string", "minLength": 3, "maxLength": 1},
    {"type": "string", "default": null},
    {"type": "string", "minLength": -1},
    {"type": "integer", "default": 1.5},
    {"type": "integer", "minimum": 1.5},
    {"type": "number", "maximum": double.infinity},
    {"type": "number", "minimum": 2, "maximum": 1},
    {"type": "integer", "minimum": 1, "default": 0},
    {"type": "boolean", "default": "false"},
    {
      "type": "string",
      "enum": ["a", "a"],
    },
    {"type": "string", "enum": []},
    {
      "type": "string",
      "enum": ["a"],
      "default": "b",
    },
    {
      "type": "string",
      "enum": ["a"],
      "oneOf": [
        {"const": "a"},
      ],
    },
    {
      "type": "array",
      "items": {"type": "number"},
    },
    {
      "type": "array",
      "items": {
        "type": "string",
        "enum": ["a"],
      },
      "default": ["b"],
    },
  ].indexed) {
    test("unsupported or inconsistent schema ${field.$1} is explicitly rejected", () {
      expect(
        ClaudeFormSchema.parse(
          schema: {
            "type": "object",
            "properties": {"field": field.$2},
          },
        ),
        isNull,
      );
    });
  }

  test("malformed root and unknown required keys are unsupported", () {
    for (final schema in [
      null,
      <Object?>[],
      {"type": "array"},
      {
        "type": "object",
        "properties": <String, Object?>{},
        "required": ["missing"],
      },
      {"type": "object", "properties": <String, Object?>{}, "required": "wrong type"},
    ]) {
      expect(ClaudeFormSchema.parse(schema: schema), isNull);
    }
  });
}
