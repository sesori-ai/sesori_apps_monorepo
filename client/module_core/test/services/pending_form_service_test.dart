import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const form = PendingForm(
  id: "request",
  sessionID: "owner",
  displaySessionId: "parent",
  title: "Fixture form",
  message: "Review fixture values",
  fields: [
    PendingFormField(
      id: "text",
      label: "Text",
      description: null,
      isRequired: false,
      schema: FormTextSchema(defaultValue: "", minLength: null, maxLength: 30, format: FormTextFormat.plain),
    ),
    PendingFormField(
      id: "integer",
      label: "Integer",
      description: null,
      isRequired: true,
      schema: FormIntegerSchema(defaultValue: 0, minimum: 0, maximum: 3),
    ),
    PendingFormField(
      id: "number",
      label: "Number",
      description: null,
      isRequired: false,
      schema: FormNumberSchema(defaultValue: 1.5, minimum: 0, maximum: 3.5),
    ),
    PendingFormField(
      id: "boolean",
      label: "Boolean",
      description: null,
      isRequired: true,
      schema: FormBooleanSchema(defaultValue: false),
    ),
    PendingFormField(
      id: "choice",
      label: "Choice",
      description: null,
      isRequired: true,
      schema: FormChoiceSchema(
        options: [FormChoice(id: "option-b", label: "Display label")],
        defaultOptionId: "option-b",
      ),
    ),
    PendingFormField(
      id: "choices",
      label: "Choices",
      description: null,
      isRequired: false,
      schema: FormChoicesSchema(
        options: [FormChoice(id: "option-a", label: "Label A")],
        defaultOptionIds: ["option-a"],
        minItems: 1,
        maxItems: 2,
      ),
    ),
    PendingFormField(
      id: "optional",
      label: "Optional",
      description: null,
      isRequired: false,
      schema: FormTextSchema(defaultValue: null, minLength: null, maxLength: null, format: FormTextFormat.plain),
    ),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(const ReplyToFormRequest(requestId: "request", sessionId: "owner", values: {}));
    registerFallbackValue(
      const DeclineFormRequest(requestId: "request", sessionId: "owner", choice: FormDismissalChoice.cancel),
    );
  });
  late MockSessionRepository repository;
  late PendingFormService service;
  setUp(() {
    repository = MockSessionRepository();
    service = PendingFormService(repository: repository);
    when(() => repository.getPendingForms(sessionId: any(named: "sessionId")))
        .thenAnswer((_) async => ApiResponse.success(const PendingFormsResponse(data: [form])));
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
    when(() => repository.declineForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
  });

  test("read requires the request's exact original session rather than its display parent", () async {
    expect(await service.read(requestId: "request", sessionId: "owner"), form);
    expect(await service.read(requestId: "request", sessionId: "parent"), isNull);
    expect(await service.read(requestId: "missing", sessionId: "owner"), isNull);
  });

  test("defaults preserve omission, empty text, zero, false and opaque choices", () async {
    final drafts = service.initialDrafts(form: form);
    expect(drafts.containsKey("optional"), isFalse);
    expect((drafts["text"]! as FormInputDraft).text, "");
    expect((drafts["integer"]! as FormInputDraft).text, "0");
    expect((drafts["boolean"]! as FormBooleanDraft).value, isFalse);
    expect(drafts.clear, throwsUnsupportedError);
    expect(const FormInputDraft(text: "private-fixture").toString(), isNot(contains("private-fixture")));
    expect(await service.submit(form: form, drafts: drafts), isA<FormReplyAccepted>());
    final request =
        verify(() => repository.replyToForm(request: captureAny(named: "request"))).captured.single
            as ReplyToFormRequest;
    expect(request.sessionId, "owner");
    expect(request.values, {
      "text": const FormTextValue(value: ""),
      "integer": const FormIntegerValue(value: 0),
      "number": const FormNumberValue(value: 1.5),
      "boolean": const FormBooleanValue(value: false),
      "choice": const FormChoiceValue(optionId: "option-b"),
      "choices": const FormChoicesValue(optionIds: ["option-a"]),
    });
  });

  test("invalid numeric input and missing required answer never reach transport", () async {
    final drafts = {...service.initialDrafts(form: form)}
      ..["integer"] = const FormInputDraft(text: "1.5")
      ..["number"] = const FormInputDraft(text: "NaN")
      ..remove("boolean");
    expect(
      await service.submit(form: form, drafts: drafts),
      const FormValidationFailed(
        fieldErrors: {
          "integer": FormValidationIssue.invalidType,
          "number": FormValidationIssue.invalidType,
          "boolean": FormValidationIssue.required,
        },
      ),
    );
    expect((drafts["integer"]! as FormInputDraft).text, "1.5");
    verifyNever(() => repository.replyToForm(request: any(named: "request")));
  });

  test("clearing an optional draft omits it instead of silently reapplying its default", () async {
    final drafts = {...service.initialDrafts(form: form)}..remove("text");
    await service.submit(form: form, drafts: drafts);
    final request =
        verify(() => repository.replyToForm(request: captureAny(named: "request"))).captured.single
            as ReplyToFormRequest;
    expect(request.values.containsKey("text"), isFalse);
  });

  test("native constraints remain authoritative and keyed validation errors are preserved", () async {
    const failure = FormValidationFailed(fieldErrors: {"integer": FormValidationIssue.outOfRange});
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(failure));
    expect(
      await service.submit(
        form: form,
        drafts: {
          ...service.initialDrafts(form: form),
          "integer": const FormInputDraft(text: "9"),
        },
      ),
      failure,
    );
  });

  for (final schema in [
    const FormSchemaUnknown(),
    const FormTextSchema(defaultValue: null, minLength: null, maxLength: null, format: FormTextFormat.unknown),
  ]) {
    test("unknown schema or format cannot be submitted but can be cancelled", () async {
      final unsupported = PendingForm(
        id: form.id,
        sessionID: form.sessionID,
        displaySessionId: form.displaySessionId,
        title: form.title,
        message: form.message,
        fields: [PendingFormField(id: "field", label: "Fixture", description: null, isRequired: true, schema: schema)],
      );
      expect(service.supportsSubmission(form: unsupported), isFalse);
      expect(await service.submit(form: unsupported, drafts: {}), isA<FormUnsupportedChoice>());
      verifyNever(() => repository.replyToForm(request: any(named: "request")));
      expect(await service.decline(form: unsupported, choice: FormDismissalChoice.cancel), isA<FormReplyAccepted>());
    });
  }

  test("negative choices preserve exact intent and reject unknown without a request", () async {
    for (final choice in [FormDismissalChoice.decline, FormDismissalChoice.cancel]) {
      expect(await service.decline(form: form, choice: choice), isA<FormReplyAccepted>());
    }
    expect(await service.decline(form: form, choice: FormDismissalChoice.unknown), isA<FormUnsupportedChoice>());
    final requests = verify(() => repository.declineForm(request: captureAny(named: "request"))).captured
        .cast<DeclineFormRequest>();
    expect(requests.map((r) => r.choice), [FormDismissalChoice.decline, FormDismissalChoice.cancel]);
    expect(requests.map((r) => r.sessionId), everyElement("owner"));
  });

  test("transport failure retains its original typed cause", () async {
    final error = NonSuccessCodeError(errorCode: 503, rawErrorString: null);
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(error));
    await expectLater(
      service.submit(
        form: form,
        drafts: service.initialDrafts(form: form),
      ),
      throwsA(same(error)),
    );
  });
}
