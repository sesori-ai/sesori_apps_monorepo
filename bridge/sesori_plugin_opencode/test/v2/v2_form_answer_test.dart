import "package:opencode_plugin/src/v2/mappers/v2_form_answer_mapper.dart";
import "package:opencode_plugin/src/v2/mappers/v2_form_answer_validator.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_reply.g.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const mapper = V2FormAnswerMapper();
const validator = V2FormAnswerValidator();

FormInfo form({required List<Map<String, dynamic>> fields}) => FormInfo.fromJson({
  "id": "form-fixture",
  "sessionID": "session-fixture",
  "fields": fields,
});

void main() {
  test("visible field order and native scalar/option values survive reply serialization", () {
    final request = form(
      fields: [
        {"type": "string", "key": "hidden", "hidden": true},
        {"type": "string", "key": "text"},
        {
          "type": "string",
          "key": "choice",
          "options": [
            {"label": "Display", "value": "native"},
          ],
        },
        {
          "type": "multiselect",
          "key": "multi",
          "options": [
            {"label": "First", "value": "one"},
          ],
          "custom": true,
        },
        {"type": "boolean", "key": "flag"},
        {"type": "number", "key": "ratio", "minimum": 0, "maximum": 1},
        {"type": "integer", "key": "count", "minimum": 1, "maximum": 4},
      ],
    );
    final answer = mapper.map(
      form: request,
      answers: [
        ["Text"],
        ["Display"],
        ["First", "Custom"],
        ["false"],
        ["0.5"],
        ["4"],
      ],
    );
    validator.validate(form: request, answer: answer);
    expect(FormReply(answer: answer).toJson(), {
      "answer": {
        "text": "Text",
        "choice": "native",
        "multi": ["one", "Custom"],
        "flag": false,
        "ratio": 0.5,
        "count": 4,
      },
    });
  });

  test("declined fields are omitted, while an explicit empty text value remains text", () {
    final request = form(
      fields: [
        {"type": "boolean", "key": "flag"},
        {"type": "string", "key": "text"},
      ],
    );
    expect(
      mapper
          .map(
            form: request,
            answers: [
              [],
              [""],
            ],
          )
          .toJson(),
      {"text": ""},
    );
  });

  test("answer cardinality and scalar shape errors are explicit client failures", () {
    final request = form(
      fields: [
        {"type": "boolean", "key": "flag"},
      ],
    );
    for (final answers in <List<List<String>>>[
      [],
      [
        ["true", "false"],
      ],
      [
        ["yes"],
      ],
    ]) {
      expect(
        () => mapper.map(form: request, answers: answers),
        throwsA(isA<PluginOperationException>().having((e) => e.statusCode, "status", 400)),
      );
    }
    expect(
      () => mapper.map(
        form: form(
          fields: [
            {"type": "number", "key": "n"},
          ],
        ),
        answers: [
          ["not a number"],
        ],
      ),
      throwsA(isA<PluginOperationException>()),
    );
  });

  for (final value in ["NaN", "Infinity", "-Infinity", "1.5"]) {
    test("integer answers reject $value before dispatch", () {
      final request = form(
        fields: [
          {"type": "integer", "key": "n"},
        ],
      );
      final answer = mapper.map(
        form: request,
        answers: [
          [value],
        ],
      );
      expect(() => validator.validate(form: request, answer: answer), throwsA(isA<PluginOperationException>()));
    });
  }

  test("both numeric field kinds enforce native minimum/maximum bounds", () {
    for (final type in ["number", "integer"]) {
      final request = form(
        fields: [
          {"type": type, "key": "n", "minimum": 1, "maximum": 3},
        ],
      );
      for (final value in ["1", "3"]) {
        validator.validate(
          form: request,
          answer: mapper.map(
            form: request,
            answers: [
              [value],
            ],
          ),
        );
      }
      for (final value in ["0", "4"]) {
        expect(
          () => validator.validate(
            form: request,
            answer: mapper.map(
              form: request,
              answers: [
                [value],
              ],
            ),
          ),
          throwsA(isA<PluginOperationException>()),
        );
      }
    }
  });

  test("special-string bounds keep native non-finite comparison semantics", () {
    final unbounded = form(
      fields: [
        {"type": "number", "key": "n", "minimum": "-Infinity", "maximum": "Infinity"},
      ],
    );
    validator.validate(
      form: unbounded,
      answer: mapper.map(
        form: unbounded,
        answers: [
          ["7"],
        ],
      ),
    );
    final impossible = form(
      fields: [
        {"type": "number", "key": "n", "minimum": "Infinity"},
      ],
    );
    expect(
      () => validator.validate(
        form: impossible,
        answer: mapper.map(
          form: impossible,
          answers: [
            ["7"],
          ],
        ),
      ),
      throwsA(isA<PluginOperationException>()),
    );
  });

  test("omission and conditional constraints remain native-authoritative", () {
    final request = form(
      fields: [
        {"type": "boolean", "key": "flag"},
        {
          "type": "integer",
          "key": "n",
          "required": true,
          "when": [
            {"key": "flag", "op": "eq", "value": true},
          ],
        },
      ],
    );
    final answer = mapper.map(
      form: request,
      answers: [
        ["false"],
        [],
      ],
    );
    validator.validate(form: request, answer: answer);
    expect(answer.toJson(), {"flag": false});
  });
}
