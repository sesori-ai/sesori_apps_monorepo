import "dart:async";
import "dart:convert";

import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/repositories/form_repository.dart";
import "package:sesori_bridge/src/repositories/pending_interaction_support.dart";
import "package:sesori_bridge/src/routing/decline_form_handler.dart";
import "package:sesori_bridge/src/routing/get_session_forms_handler.dart";
import "package:sesori_bridge/src/routing/reply_to_form_handler.dart";
import "package:sesori_bridge/src/services/pending_interaction_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../helpers/fakes/fake_derived_bridge_plugin.dart";
import "../../helpers/plugin_runtime_test_support.dart";
import "../../helpers/test_database.dart";
import "../routing/routing_test_helpers.dart";

void main() {
  late AppDatabase db;
  late _FormPlugin plugin;
  late TestPluginRuntime runtime;
  late FormRepository repository;
  late PendingInteractionService service;
  const reply = ReplyToFormRequest(
    requestId: "request",
    sessionId: "child",
    values: {
      "text": FormTextValue(value: ""),
      "integer": FormIntegerValue(value: 0),
      "number": FormNumberValue(value: 1.5),
      "boolean": FormBooleanValue(value: false),
      "choice": FormChoiceValue(optionId: "option-b"),
      "choices": FormChoicesValue(optionIds: ["option-a"]),
    },
  );
  const cancel = DeclineFormRequest(requestId: "request", sessionId: "child", choice: FormDismissalChoice.cancel);

  setUp(() async {
    db = createTestDatabase();
    addTearDown(db.close);
    plugin = _FormPlugin();
    runtime = createTestPluginRuntime(plugins: [plugin]);
    addTearDown(runtime.dispose);
    for (final id in ["root", "child"]) {
      await recordSessionBinding(
        database: db,
        sessionId: id,
        backendSessionId: "$id-native",
        pluginId: plugin.id,
        projectId: "/fixture",
        parentSessionId: id == "child" ? "root" : null,
      );
    }
    repository = FormRepository(
      runtime: runtime,
      pendingSupport: PendingInteractionSupport(sessionDao: db.sessionDao),
    );
    final pending = buildTestPendingInteractionService(database: db, plugin: plugin);
    service = pending.service;
    addTearDown(() async {
      service.dispose();
      await pending.dispatcher.dispose();
    });
  });

  test("real JSON snapshots retain canonical child/display owners and all typed schemas", () async {
    final result = await GetSessionFormsHandler(service: service).routeInternal(
      request: makeRequest(
        "POST",
        "/session/forms",
        body: jsonEncode(const SessionIdRequest(sessionId: "root").toJson()),
      ),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(result.response.status, 200);
    final form = PendingFormsResponse.fromJson(jsonDecodeMap(result.response.body!)).data.single;
    expect(form.sessionID, "child");
    expect(form.displaySessionId, "root");
    expect(form.fields.map((field) => field.schema.runtimeType), [
      FormTextSchema,
      FormIntegerSchema,
      FormNumberSchema,
      FormBooleanSchema,
      FormChoiceSchema,
      FormChoicesSchema,
    ]);
    expect((form.fields.first.schema as FormTextSchema).defaultValue, "private-fixture-default");
    expect((form.fields[4].schema as FormChoiceSchema).defaultOptionId, "option-b");
    expect((form.fields[5].schema as FormChoicesSchema).maxItems, 2);
    expect(form.toString(), isNot(contains("private-fixture-default")));
    expect(
      await service.replyToForm(
        request: const ReplyToFormRequest(requestId: "request", sessionId: "root", values: {}),
      ),
      isA<FormAlreadySettled>(),
    );
    expect(plugin.replies, isEmpty);
  });

  test("real JSON submission preserves every answer type, empty/zero/false and omission", () async {
    final result = await ReplyToFormHandler(service: service).routeInternal(
      request: makeRequest("POST", "/form/reply", body: jsonEncode(reply.toJson())),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(result.response.status, 200);
    expect(FormReplyResult.fromJson(jsonDecodeMap(result.response.body!)), isA<FormReplyAccepted>());
    final native = plugin.replies.single;
    expect(native.sessionId, "child-native");
    expect(native.requestId, "request");
    expect((native.values["text"]! as PluginFormTextValue).value, "");
    expect((native.values["integer"]! as PluginFormIntegerValue).value, 0);
    expect((native.values["number"]! as PluginFormNumberValue).value, 1.5);
    expect((native.values["boolean"]! as PluginFormBooleanValue).value, isFalse);
    expect((native.values["choice"]! as PluginFormChoiceValue).optionId, "option-b");
    expect((native.values["choices"]! as PluginFormChoicesValue).optionIds, ["option-a"]);
    expect(native.values.containsKey("optional"), isFalse);
    expect(await service.replyToForm(request: reply), isA<FormAlreadySettled>());
    expect(plugin.replies, hasLength(1));
  });

  test("typed native validation results survive actual JSON and allow correction", () async {
    plugin.submissionResult = PluginFormValidationFailed(
      fieldErrors: {
        "integer": PluginFormValidationIssue.outOfRange,
        "text": PluginFormValidationIssue.required,
      },
    );
    final result = await ReplyToFormHandler(service: service).routeInternal(
      request: makeRequest("POST", "/form/reply", body: jsonEncode(reply.toJson())),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(result.response.status, 200);
    expect(
      FormReplyResult.fromJson(jsonDecodeMap(result.response.body!)),
      const FormValidationFailed(
        fieldErrors: {
          "integer": FormValidationIssue.outOfRange,
          "text": FormValidationIssue.required,
        },
      ),
    );
    expect(await repository.getPending(sessionId: "child"), hasLength(1));
    plugin.submissionResult = const PluginFormAccepted();
    expect(await service.replyToForm(request: reply), isA<FormReplyAccepted>());
  });

  test("future answer and dismissal variants cannot reach native mutation", () async {
    expect(
      await repository.reply(
        request: const ReplyToFormRequest(
          requestId: "request",
          sessionId: "child",
          values: {"text": FormValueUnknown()},
        ),
      ),
      const FormValidationFailed(fieldErrors: {"text": FormValidationIssue.invalidType}),
    );
    expect(
      await repository.decline(
        request: const DeclineFormRequest(
          requestId: "request",
          sessionId: "child",
          choice: FormDismissalChoice.unknown,
        ),
      ),
      isA<FormUnsupportedChoice>(),
    );
    expect(plugin.replies, isEmpty);
    expect(plugin.dismissals, isEmpty);
  });

  for (final choice in [FormDismissalChoice.decline, FormDismissalChoice.cancel]) {
    test("${choice.name} uses the original owner and exact declared negative choice", () async {
      final result = await DeclineFormHandler(service: service).routeInternal(
        request: makeRequest(
          "POST",
          "/form/decline",
          body: jsonEncode(DeclineFormRequest(requestId: "request", sessionId: "child", choice: choice).toJson()),
        ),
        targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
      );
      expect(result.response.status, 200);
      expect(FormReplyResult.fromJson(jsonDecodeMap(result.response.body!)), isA<FormReplyAccepted>());
      expect(plugin.dismissals.single.sessionId, "child-native");
      expect(plugin.dismissals.single.choice.name, choice.name);
    });
  }

  test("inactive reads and replies never initialize the plugin", () async {
    runtime.stoppedPluginIds.add(plugin.id);
    expect(await repository.getPending(sessionId: "root"), isEmpty);
    expect(await repository.reply(request: reply), isA<FormAlreadySettled>());
    expect(await repository.decline(request: cancel), isA<FormAlreadySettled>());
    expect(plugin.reads, isZero);
    expect(plugin.replies, isEmpty);
    expect(plugin.dismissals, isEmpty);
  });

  test("plugins without form support expose no snapshots and reject mutations explicitly", () async {
    final otherRuntime = createTestPluginRuntime(
      plugins: [
        FakeDerivedBridgePlugin(id: plugin.id, launchDirectory: "/fixture", allSessions: const []),
      ],
    );
    addTearDown(otherRuntime.dispose);
    final unsupported = FormRepository(
      runtime: otherRuntime,
      pendingSupport: PendingInteractionSupport(sessionDao: db.sessionDao),
    );
    expect(await unsupported.getPending(sessionId: "root"), isEmpty);
    expect(await unsupported.reply(request: reply), isA<FormUnsupportedChoice>());
    expect(await unsupported.decline(request: cancel), isA<FormUnsupportedChoice>());
    expect(plugin.reads, isZero);
  });

  for (final deleted in ["child-native", "root-native"]) {
    test("tombstoned $deleted is hidden and cannot receive a form reply", () async {
      await db.sessionDao.insertSessionTombstone(backendSessionId: deleted, pluginId: plugin.id, deletedAt: 1);
      expect(await repository.getPending(sessionId: "root"), isEmpty);
      await expectLater(
        repository.reply(request: reply),
        throwsA(isA<PluginOperationException>().having((e) => e.isNotFound, "not found", isTrue)),
      );
      expect(plugin.replies, isEmpty);
    });
  }

  test("archived actual owners disappear from direct and display-parent reads", () async {
    await db.sessionDao.setArchived(sessionId: "child", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
    expect(await repository.getPending(sessionId: "child"), isEmpty);
    expect(await repository.getPending(sessionId: "root"), isEmpty);
  });

  test("canonical archived rejection precedes reads and native mutations", () async {
    await db.sessionDao.setArchived(sessionId: "child", archivedAt: 2, updatedAt: 2, projectionUpdatedAt: 2);
    final result = await ReplyToFormHandler(service: service).routeInternal(
      request: makeRequest("POST", "/form/reply", body: jsonEncode(reply.toJson())),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(result.response.status, 409);
    expect(SessionArchivedRejection.fromJson(jsonDecodeMap(result.response.body!)).sessionId, "child");
    final dismissal = await DeclineFormHandler(service: service).routeInternal(
      request: makeRequest("POST", "/form/decline", body: jsonEncode(cancel.toJson())),
      targetParams: const (pathParams: <String, String>{}, queryParams: <String, String>{}),
    );
    expect(dismissal.response.status, 409);
    expect(plugin.reads, isZero);
    expect(plugin.replies, isEmpty);
    expect(plugin.dismissals, isEmpty);
  });

  test("failed native writes return 503 and leave pending state available", () async {
    plugin.submissionResult = const PluginFormUnavailable();
    plugin.dismissalResult = PluginFormDismissalResult.unavailable;
    final failure = throwsA(isA<PluginOperationException>().having((e) => e.statusCode, "status", 503));
    await expectLater(service.replyToForm(request: reply), failure);
    await expectLater(service.declineForm(request: cancel), failure);
    expect(await repository.getPending(sessionId: "child"), hasLength(1));
  });

  test("concurrent submission and cancellation share existing session ordering", () async {
    plugin.replyGate = Completer<PluginFormSubmissionResult>();
    final first = service.replyToForm(request: reply);
    await plugin.replyStarted.future;
    final second = service.declineForm(request: cancel);
    expect(plugin.dismissals, isEmpty);
    plugin.replyGate!.complete(const PluginFormAccepted());
    expect(await first, isA<FormReplyAccepted>());
    expect(await second, isA<FormAlreadySettled>());
    expect(plugin.replies, hasLength(1));
    expect(plugin.dismissals, isEmpty);
  });

  test("disposed service refuses reads and mutations", () async {
    service.dispose();
    await expectLater(service.getPendingForms(sessionId: "child"), throwsStateError);
    await expectLater(service.replyToForm(request: reply), throwsStateError);
    await expectLater(service.declineForm(request: cancel), throwsStateError);
    expect(plugin.reads, isZero);
  });
}

class _FormPlugin() extends FakeDerivedBridgePlugin implements FormInteractionPluginApi {
  this : super(id: "fixture", launchDirectory: "/fixture", allSessions: const []);
  final forms = <PluginPendingForm>[_form()];
  final replies = <({String requestId, String sessionId, Map<String, PluginFormValue> values})>[];
  final dismissals = <({String sessionId, PluginFormDismissalChoice choice})>[];
  final replyStarted = Completer<void>();
  Completer<PluginFormSubmissionResult>? replyGate;
  PluginFormSubmissionResult submissionResult = const PluginFormAccepted();
  PluginFormDismissalResult dismissalResult = PluginFormDismissalResult.accepted;
  int reads = 0;

  @override
  Future<List<PluginPendingForm>> getPendingForms({required String sessionId}) async {
    reads++;
    return forms.where((form) => form.sessionID == sessionId || form.displaySessionId == sessionId).toList();
  }

  @override
  Future<PluginFormSubmissionResult> replyToForm({
    required String requestId,
    required String sessionId,
    required Map<String, PluginFormValue> values,
  }) async {
    replies.add((requestId: requestId, sessionId: sessionId, values: values));
    if (!replyStarted.isCompleted) replyStarted.complete();
    final result = await replyGate?.future ?? submissionResult;
    if (result is PluginFormAccepted) forms.clear();
    return result;
  }

  @override
  Future<PluginFormDismissalResult> declineForm({
    required String requestId,
    required String sessionId,
    required PluginFormDismissalChoice choice,
  }) async {
    dismissals.add((sessionId: sessionId, choice: choice));
    if (dismissalResult == PluginFormDismissalResult.accepted) forms.clear();
    return dismissalResult;
  }
}

PluginPendingForm _form() => PluginPendingForm(
  id: "request",
  sessionID: "child-native",
  displaySessionId: "root-native",
  title: "Fixture server",
  message: "Complete fixture",
  fields: [
    const PluginFormField(
      id: "text",
      label: "Text",
      description: null,
      isRequired: false,
      schema: PluginFormTextSchema(
        defaultValue: "private-fixture-default",
        minLength: null,
        maxLength: 40,
        format: PluginFormTextFormat.plain,
      ),
    ),
    const PluginFormField(
      id: "integer",
      label: "Integer",
      description: null,
      isRequired: true,
      schema: PluginFormIntegerSchema(defaultValue: 0, minimum: 0, maximum: 3),
    ),
    const PluginFormField(
      id: "number",
      label: "Number",
      description: null,
      isRequired: false,
      schema: PluginFormNumberSchema(defaultValue: 1.5, minimum: 0, maximum: 3.5),
    ),
    const PluginFormField(
      id: "boolean",
      label: "Boolean",
      description: null,
      isRequired: true,
      schema: PluginFormBooleanSchema(defaultValue: false),
    ),
    PluginFormField(
      id: "choice",
      label: "Choice",
      description: null,
      isRequired: true,
      schema: PluginFormChoiceSchema(options: _options, defaultOptionId: "option-b"),
    ),
    PluginFormField(
      id: "choices",
      label: "Choices",
      description: null,
      isRequired: false,
      schema: PluginFormChoicesSchema(options: _options, defaultOptionIds: ["option-a"], minItems: 1, maxItems: 2),
    ),
  ],
);

const _options = [
  PluginFormChoice(id: "option-a", label: "Label A"),
  PluginFormChoice(id: "option-b", label: "Label B"),
];
