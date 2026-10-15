import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  const choices = [
    FormChoice(id: "option-a", label: "First choice"),
    FormChoice(id: "option-b", label: "Second choice"),
  ];
  const fields = [
    PendingFormField(
      id: "field-text",
      label: "Fixture label",
      description: null,
      isRequired: false,
      schema: FormTextSchema(
        defaultValue: "private-fixture",
        minLength: 1,
        maxLength: 30,
        format: FormTextFormat.plain,
      ),
    ),
    PendingFormField(
      id: "field-integer",
      label: "Count",
      description: "A bounded count",
      isRequired: true,
      schema: FormIntegerSchema(defaultValue: 0, minimum: 0, maximum: 10),
    ),
    PendingFormField(
      id: "field-number",
      label: "Amount",
      description: null,
      isRequired: false,
      schema: FormNumberSchema(defaultValue: 1.5, minimum: 0, maximum: 3.5),
    ),
    PendingFormField(
      id: "field-boolean",
      label: "Enabled",
      description: null,
      isRequired: true,
      schema: FormBooleanSchema(defaultValue: false),
    ),
    PendingFormField(
      id: "field-choice",
      label: "Plan",
      description: null,
      isRequired: true,
      schema: FormChoiceSchema(options: choices, defaultOptionId: "option-b"),
    ),
    PendingFormField(
      id: "field-choices",
      label: "Tags",
      description: null,
      isRequired: false,
      schema: FormChoicesSchema(options: choices, defaultOptionIds: ["option-a"], minItems: 1, maxItems: 2),
    ),
  ];
  const form = PendingForm(
    id: "request",
    sessionID: "child",
    displaySessionId: "parent",
    title: "Fixture MCP",
    message: "Review these fixture fields.",
    fields: fields,
  );

  test("snapshots retain original owner, typed defaults and supported constraints", () {
    const response = PendingFormsResponse(data: [form]);
    final decoded = PendingFormsResponse.fromJson(response.toJson()).data.single;
    expect(decoded, form);
    expect(decoded.sessionID, "child");
    expect(decoded.displaySessionId, "parent");
    expect(decoded.fields.first.toJson().containsKey("description"), isFalse);
    expect(decoded.fields[3].schema, const FormBooleanSchema(defaultValue: false));
    expect(response.toString(), isNot(contains("private-fixture")));
    expect(decoded.fields.first.toString(), isNot(contains("private-fixture")));
    expect(decoded.fields.first.schema.toString(), isNot(contains("private-fixture")));
  });

  test("missing optional answers remain distinct from empty text, zero and false", () {
    const request = ReplyToFormRequest(
      requestId: "request",
      sessionId: "child",
      values: {
        "empty": FormTextValue(value: ""),
        "count": FormIntegerValue(value: 0),
        "amount": FormNumberValue(value: 1.5),
        "enabled": FormBooleanValue(value: false),
      },
    );
    final decoded = ReplyToFormRequest.fromJson(request.toJson());
    expect(decoded, request);
    expect(decoded.values.containsKey("unanswered"), isFalse);
    expect(decoded.values["count"], isA<FormIntegerValue>());
    expect(decoded.values["amount"], isA<FormNumberValue>());
    expect(decoded.values["enabled"], const FormBooleanValue(value: false));
    expect(decoded.values["empty"], const FormTextValue(value: ""));
  });

  test("choice answers carry opaque IDs separately from presentation labels", () {
    const request = ReplyToFormRequest(
      requestId: "request",
      sessionId: "child",
      values: {
        "field-choice": FormChoiceValue(optionId: "option-b"),
        "field-choices": FormChoicesValue(optionIds: ["option-a", "option-b"]),
      },
    );
    expect(ReplyToFormRequest.fromJson(request.toJson()), request);
    expect(jsonEncode(request.toJson()), isNot(contains("First choice")));
    expect(jsonEncode(request.toJson()), isNot(contains("Second choice")));
    expect(const FormTextValue(value: "private-fixture").toString(), isNot(contains("private-fixture")));
  });

  test("nullable defaults and display parent remain absent without empty sentinels", () {
    const schema = FormTextSchema(defaultValue: null, minLength: null, maxLength: null, format: FormTextFormat.plain);
    expect(schema.toJson(), {"format": "plain", "type": "text"});
    expect(FormFieldSchema.fromJson(schema.toJson()), schema);
    final decoded = PendingForm.fromJson(form.toJson()..remove("displaySessionId"));
    expect(decoded.displaySessionId, isNull);
  });

  test("future schema, value, format and dismissal variants stay explicitly unknown", () {
    expect(FormFieldSchema.fromJson({"type": "future"}), const FormSchemaUnknown());
    expect(FormValue.fromJson({"type": "future", "value": "unrecognized"}), const FormValueUnknown());
    expect(
      FormFieldSchema.fromJson({"type": "text", "format": "future"}),
      const FormTextSchema(defaultValue: null, minLength: null, maxLength: null, format: FormTextFormat.unknown),
    );
    expect(
      DeclineFormRequest.fromJson({"requestId": "request", "sessionId": "child", "choice": "future"}).choice,
      FormDismissalChoice.unknown,
    );
  });

  test("validation errors retain field attribution and tolerate future issue codes", () {
    const result = FormValidationFailed(fieldErrors: {"field-integer": FormValidationIssue.outOfRange});
    expect(FormReplyResult.fromJson(result.toJson()), result);
    expect(
      FormReplyResult.fromJson({
        "type": "validationFailed",
        "fieldErrors": {"field-text": "future"},
      }),
      const FormValidationFailed(fieldErrors: {"field-text": FormValidationIssue.unknown}),
    );
  });

  test("acceptance, replay, unsupported choice and both dismissal choices remain distinct", () {
    for (final result in [const FormReplyAccepted(), const FormAlreadySettled(), const FormUnsupportedChoice()]) {
      expect(FormReplyResult.fromJson(result.toJson()), result);
    }
    expect(FormReplyResult.fromJson({"type": "future"}), const FormReplyUnknown());
    for (final choice in [FormDismissalChoice.decline, FormDismissalChoice.cancel]) {
      final request = DeclineFormRequest(requestId: "request", sessionId: "child", choice: choice);
      expect(DeclineFormRequest.fromJson(request.toJson()), request);
      expect(request.toJson()["choice"], choice.name);
    }
  });

  test("integer answers and bounds never silently truncate fractional wire values", () {
    for (final value in [1.5, 1.0]) {
      expect(() => FormValue.fromJson({"type": "integer", "value": value}), throwsFormatException);
    }
    expect(
      () => FormFieldSchema.fromJson({"type": "integer", "minimum": 1.5}),
      throwsFormatException,
    );
    expect(
      () => FormFieldSchema.fromJson({"type": "text", "format": "plain", "minLength": 1.5}),
      throwsFormatException,
    );
  });

  test("nonfinite number values and defaults cannot cross the serialization boundary", () {
    for (final value in [double.nan, double.infinity, double.negativeInfinity, jsonDecode("1e999")]) {
      expect(() => FormValue.fromJson({"type": "number", "value": value}), throwsFormatException);
      expect(
        () => FormFieldSchema.fromJson({"type": "number", "defaultValue": value}),
        throwsFormatException,
      );
    }
    expect(() => const FormNumberValue(value: double.infinity).toJson(), throwsFormatException);
    expect(
      () => const FormNumberSchema(defaultValue: double.nan, minimum: null, maximum: null).toJson(),
      throwsFormatException,
    );
  });
}
