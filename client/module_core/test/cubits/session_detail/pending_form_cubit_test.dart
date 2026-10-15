import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../services/pending_form_service_test.dart" show form;

const connected = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "first"),
  health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
);
const replaced = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "second"),
  health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
);

void main() {
  setUpAll(() {
    registerFallbackValue(const ReplyToFormRequest(requestId: "request", sessionId: "owner", values: {}));
    registerFallbackValue(
      const DeclineFormRequest(requestId: "request", sessionId: "owner", choice: FormDismissalChoice.cancel),
    );
  });
  late MockSessionRepository repository;
  late MockConnectionService connection;
  late BehaviorSubject<ConnectionStatus> statuses;
  setUp(() {
    repository = MockSessionRepository();
    connection = MockConnectionService();
    statuses = BehaviorSubject.seeded(connected);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => repository.getPendingForms(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingFormsResponse(data: [form])));
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
    when(() => repository.declineForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
    addTearDown(statuses.close);
  });
  PendingFormCubit create() {
    final cubit = PendingFormCubit(
      service: PendingFormService(repository: repository),
      connectionService: connection,
      requestId: "request",
      sessionId: "owner",
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> ready({required PendingFormCubit cubit}) async {
    if (cubit.state is FormReady) return;
    await cubit.stream.firstWhere((s) => s is FormReady).timeout(const Duration(seconds: 5));
  }

  Future<void> retired({required PendingFormCubit cubit}) async {
    if (cubit.state case FormReady(connection: FormConnectionOwnership.retired)) return;
    await cubit.stream
        .firstWhere((s) => s is FormReady && s.connection == FormConnectionOwnership.retired)
        .timeout(const Duration(seconds: 5));
  }

  test("opening creates immutable defaults without native intent; refresh keeps edited drafts", () async {
    final cubit = create();
    await ready(cubit: cubit);
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "1."),
    );
    await cubit.refresh();
    final state = cubit.state as FormReady;
    expect((state.drafts["integer"]! as FormInputDraft).text, "1.");
    expect(state.drafts.clear, throwsUnsupportedError);
    expect(cubit.canSubmit, isTrue);
    verify(() => repository.getPendingForms(sessionId: "owner")).called(1);
    verifyNever(() => repository.replyToForm(request: any(named: "request")));
    verifyNever(() => repository.declineForm(request: any(named: "request")));
  });

  test("invalid numeric draft stays editable and never sends a flattened answer", () async {
    final cubit = create();
    await ready(cubit: cubit);
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "-"),
    );
    await cubit.submit();
    final state = cubit.state as FormReady;
    expect((state.drafts["integer"]! as FormInputDraft).text, "-");
    expect((state.submission as FormSubmissionInvalid).fieldErrors, {"integer": FormValidationIssue.invalidType});
    verifyNever(() => repository.replyToForm(request: any(named: "request")));
  });

  test("native validation keeps all drafts and edits clear only the affected field issue", () async {
    when(() => repository.replyToForm(request: any(named: "request"))).thenAnswer(
      (_) async => ApiResponse.success(
        const FormValidationFailed(
          fieldErrors: {"integer": FormValidationIssue.outOfRange, "text": FormValidationIssue.invalidLength},
        ),
      ),
    );
    final cubit = create();
    await ready(cubit: cubit);
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "9"),
    );
    cubit.edit(
      fieldId: "text",
      draft: const FormInputDraft(text: "private draft"),
    );
    await cubit.submit();
    final rejected = cubit.state as FormReady;
    expect((rejected.drafts["text"]! as FormInputDraft).text, "private draft");
    expect(rejected.toString(), isNot(contains("private draft")));
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "2"),
    );
    expect(((cubit.state as FormReady).submission as FormSubmissionInvalid).fieldErrors, {
      "text": FormValidationIssue.invalidLength,
    });
    cubit.edit(
      fieldId: "text",
      draft: const FormInputDraft(text: "corrected"),
    );
    expect((cubit.state as FormReady).submission, isA<FormSubmissionIdle>());
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
    await cubit.submit();
    expect((cubit.state as FormReplySent).intent, FormSubmissionIntent.submit);
    final requests = verify(() => repository.replyToForm(request: captureAny(named: "request"))).captured
        .cast<ReplyToFormRequest>();
    expect(requests.last.values["integer"], const FormIntegerValue(value: 2));
    expect(requests.last.values["text"], const FormTextValue(value: "corrected"));
  });

  test("transport failure retains its cause and optional answers can be cleared", () async {
    final error = NonSuccessCodeError(errorCode: 503, rawErrorString: null);
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(error));
    final cubit = create();
    await ready(cubit: cubit);
    cubit.edit(
      fieldId: "optional",
      draft: const FormInputDraft(text: ""),
    );
    await cubit.submit();
    final failed = cubit.state as FormReady;
    expect((failed.submission as FormSubmissionFailed).cause, same(error));
    expect((failed.drafts["optional"]! as FormInputDraft).text, "");
    cubit.edit(fieldId: "optional", draft: null);
    expect((cubit.state as FormReady).drafts.containsKey("optional"), isFalse);
  });

  test("in-flight submission blocks edits, duplicate submits and cancellation", () async {
    final response = Completer<ApiResponse<FormReplyResult>>();
    when(() => repository.replyToForm(request: any(named: "request"))).thenAnswer((_) => response.future);
    final cubit = create();
    await ready(cubit: cubit);
    final first = cubit.submit();
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "2"),
    );
    await cubit.submit();
    await cubit.decline(choice: FormDismissalChoice.cancel);
    expect((cubit.state as FormReady).submission, isA<FormSubmitting>());
    expect((cubit.state as FormReady).drafts["integer"], isA<FormInputDraft>().having((v) => v.text, "text", "0"));
    response.complete(ApiResponse.success(const FormReplyAccepted()));
    await first;
    expect(cubit.state, isA<FormReplySent>());
    verify(() => repository.replyToForm(request: any(named: "request"))).called(1);
    verifyNever(() => repository.declineForm(request: any(named: "request")));
  });

  for (final choice in [FormDismissalChoice.decline, FormDismissalChoice.cancel]) {
    test("${choice.name} preserves exact negative intent and original owner", () async {
      final cubit = create();
      await ready(cubit: cubit);
      await cubit.decline(choice: choice);
      final request =
          verify(() => repository.declineForm(request: captureAny(named: "request"))).captured.single
              as DeclineFormRequest;
      expect(request.sessionId, "owner");
      expect(request.choice, choice);
      expect(cubit.state, isA<FormReplySent>());
    });
  }

  for (final result in [const FormReplyUnknown(), const FormUnsupportedChoice()]) {
    test("${result.runtimeType} retains the draft without claiming settlement", () async {
      when(() => repository.replyToForm(request: any(named: "request")))
          .thenAnswer((_) async => ApiResponse.success(result));
      final cubit = create();
      await ready(cubit: cubit);
      await cubit.submit();
      expect((cubit.state as FormReady).submission, isA<FormSubmissionRefused>());
      expect((cubit.state as FormReady).drafts, isNotEmpty);
    });
  }

  test("unknown dismissal is refused without native intent", () async {
    final cubit = create();
    await ready(cubit: cubit);
    await cubit.decline(choice: FormDismissalChoice.unknown);
    expect(
      ((cubit.state as FormReady).submission as FormSubmissionRefused).reason,
      FormRefusalReason.unsupportedChoice,
    );
    verifyNever(() => repository.declineForm(request: any(named: "request")));
  });

  test("disconnect keeps visible drafts but cannot reactivate controls after reconnect", () async {
    final cubit = create();
    await ready(cubit: cubit);
    cubit.edit(
      fieldId: "integer",
      draft: const FormInputDraft(text: "1."),
    );
    statuses.add(const ConnectionStatus.disconnected());
    await retired(cubit: cubit);
    statuses.add(connected);
    await Future<void>.delayed(Duration.zero);
    await cubit.submit();
    await cubit.refresh();
    expect((cubit.state as FormReady).connection, FormConnectionOwnership.retired);
    expect((cubit.state as FormReady).drafts["integer"], isA<FormInputDraft>().having((v) => v.text, "text", "1."));
    expect(cubit.canSubmit, isFalse);
    verifyNever(() => repository.replyToForm(request: any(named: "request")));
  });

  test("bridge replacement during submission fences a late acceptance", () async {
    final response = Completer<ApiResponse<FormReplyResult>>();
    when(() => repository.replyToForm(request: any(named: "request"))).thenAnswer((_) => response.future);
    final cubit = create();
    await ready(cubit: cubit);
    final submitted = cubit.submit();
    statuses.add(replaced);
    await retired(cubit: cubit);
    response.complete(ApiResponse.success(const FormReplyAccepted()));
    await submitted;
    expect((cubit.state as FormReady).connection, FormConnectionOwnership.retired);
    expect((cubit.state as FormReady).drafts, isNotEmpty);
  });

  test("closing an observer does not cancel the request and ignores late data", () async {
    final response = Completer<ApiResponse<PendingFormsResponse>>();
    when(() => repository.getPendingForms(sessionId: "owner")).thenAnswer((_) => response.future);
    final cubit = create();
    await cubit.close();
    response.complete(ApiResponse.success(const PendingFormsResponse(data: [form])));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.isClosed, isTrue);
    verifyNever(() => repository.declineForm(request: any(named: "request")));
  });
}
