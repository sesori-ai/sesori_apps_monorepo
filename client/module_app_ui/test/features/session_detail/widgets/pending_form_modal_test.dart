import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/pending_form_field_editor.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

const _count = PendingFormField(
  id: "count",
  label: "Fixture count",
  description: null,
  isRequired: true,
  schema: FormIntegerSchema(defaultValue: 0, minimum: 0, maximum: 3),
);
const _form = PendingForm(
  id: "request",
  sessionID: "owner",
  displaySessionId: "display",
  title: "Fixture form",
  message: "Review the fixture values.",
  fields: [
    _count,
    PendingFormField(
      id: "text",
      label: "Fixture text",
      description: null,
      isRequired: false,
      schema: FormTextSchema(
        defaultValue: "Fixture answer",
        minLength: null,
        maxLength: null,
        format: FormTextFormat.plain,
      ),
    ),
    PendingFormField(
      id: "boolean",
      label: "Fixture boolean",
      description: null,
      isRequired: true,
      schema: FormBooleanSchema(defaultValue: null),
    ),
    PendingFormField(
      id: "choice",
      label: "Fixture choice",
      description: null,
      isRequired: false,
      schema: FormChoiceSchema(
        options: [FormChoice(id: "opaque-a", label: "Visible option")],
        defaultOptionId: null,
      ),
    ),
    PendingFormField(
      id: "choices",
      label: "Fixture choices",
      description: null,
      isRequired: false,
      schema: FormChoicesSchema(
        options: [FormChoice(id: "opaque-b", label: "Visible multiple option")],
        defaultOptionIds: null,
        minItems: null,
        maxItems: null,
      ),
    ),
  ],
);

class _Harness() {
  final repository = MockSessionRepository();
  final connection = MockConnectionService();
  final changes = StreamController<bool>.broadcast();
  final statuses = BehaviorSubject<ConnectionStatus>.seeded(
    const ConnectionStatus.connected(
      config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "fixture"),
      health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
    ),
  );
  bool pending = true;
  int settlements = 0;
  this {
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => repository.getPendingForms(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingFormsResponse(data: [_form])));
    when(() => repository.replyToForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
    when(() => repository.declineForm(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const FormReplyAccepted()));
  }
  late final router = GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, _) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showPendingFormModal(
                context: context,
                requestId: "request",
                sessionId: "owner",
                createCubit: ({required requestId, required sessionId}) => PendingFormCubit(
                  service: PendingFormService(repository: repository),
                  connectionService: connection,
                  requestId: requestId,
                  sessionId: sessionId,
                ),
                isPendingStream: changes.stream,
                isPending: () => pending,
                onPendingDismissed: () {},
                onCancelUnavailable: () {},
                onSettled: () {
                  settlements++;
                  pending = false;
                  changes.add(false);
                },
              ),
              child: const Text("Open form"),
            ),
          ),
        ),
      ),
    ],
  );
  Widget app({required double scale, required bool reduced}) => MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: reduced),
      child: child!,
    ),
  );
  Future<void> close() async {
    router.dispose();
    await changes.close();
    await statuses.close();
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(const ReplyToFormRequest(requestId: "request", sessionId: "owner", values: {}));
    registerFallbackValue(
      const DeclineFormRequest(requestId: "request", sessionId: "owner", choice: FormDismissalChoice.cancel),
    );
  });
  late _Harness harness;
  setUp(() {
    harness = _Harness();
  });
  tearDown(() async {
    await harness.close();
  });
  Future<void> open({
    required WidgetTester tester,
    double scale = 1,
    bool reduced = false,
    Size size = const Size(800, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(harness.app(scale: scale, reduced: reduced));
    await tester.tap(find.text("Open form"));
    await tester.pumpAndSettle();
  }

  Future<void> tap({required WidgetTester tester, required String label}) async {
    final button = find.widgetWithText(PregoButtonsSolid, label);
    final finder = button.evaluate().isEmpty ? find.text(label) : button;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Finder editor({required String id}) => find.byKey(ValueKey(id));
  Finder input({required String id}) => find.descendant(
    of: editor(id: id),
    matching: find.byType(TextField),
  );

  testWidgets("typed fields preserve false, zero, choices and explicit optional omission", (tester) async {
    await open(tester: tester);
    await tap(tester: tester, label: "No");
    await tap(tester: tester, label: "Visible option");
    await tap(tester: tester, label: "Visible multiple option");
    final clear = find.descendant(
      of: editor(id: "text"),
      matching: find.text("Clear answer"),
    );
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await tester.pump();
    await tap(tester: tester, label: "Submit answers");
    final request =
        verify(() => harness.repository.replyToForm(request: captureAny(named: "request"))).captured.single
            as ReplyToFormRequest;
    expect(request.sessionId, "owner");
    expect(request.values, {
      "count": const FormIntegerValue(value: 0),
      "boolean": const FormBooleanValue(value: false),
      "choice": const FormChoiceValue(optionId: "opaque-a"),
      "choices": const FormChoicesValue(optionIds: ["opaque-b"]),
    });
    expect(harness.settlements, 1);
    expect(find.byType(PendingFormModal), findsNothing);
  });

  testWidgets("validation keeps raw drafts and the same input controller", (tester) async {
    when(() => harness.repository.replyToForm(request: any(named: "request"))).thenAnswer(
      (_) async =>
          ApiResponse.success(const FormValidationFailed(fieldErrors: {"count": FormValidationIssue.outOfRange})),
    );
    await open(tester: tester);
    expect(find.text("Required · Whole number · Minimum: 0 · Maximum: 3"), findsOneWidget);
    final controller = tester.widget<TextField>(input(id: "count")).controller!;
    await tester.enterText(input(id: "count"), "99");
    await tap(tester: tester, label: "No");
    await tap(tester: tester, label: "Submit answers");
    expect(find.byType(PendingFormModal), findsOneWidget);
    expect(tester.widget<TextField>(input(id: "count")).controller, same(controller));
    expect(controller.text, "99");
    expect(find.text("This value is outside the allowed range."), findsOneWidget);
    expect(tester.widget<TextField>(input(id: "text")).controller!.text, "Fixture answer");
    expect(harness.settlements, 0);
  });

  testWidgets("busy and validation transitions retain focus, selection and field height", (tester) async {
    FormValidationIssue? issue;
    bool editable = true;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PendingFormFieldEditor(
                field: _count,
                draft: const FormInputDraft(text: "123"),
                issue: issue,
                editable: editable,
                onChanged: (_) {},
              );
            },
          ),
        ),
      ),
    );
    final field = find.byType(TextField);
    await tester.tap(field);
    await tester.pump();
    final widget = tester.widget<TextField>(field);
    widget.controller!.selection = const TextSelection.collapsed(offset: 1);
    final height = tester.getSize(find.byType(PendingFormFieldEditor)).height;
    update(() {
      editable = false;
    });
    await tester.pump();
    expect(widget.focusNode!.hasFocus, isTrue);
    expect(tester.widget<TextField>(field).readOnly, isTrue);
    update(() {
      editable = true;
      issue = FormValidationIssue.outOfRange;
    });
    await tester.pump();
    expect(tester.widget<TextField>(field).controller, same(widget.controller));
    expect(widget.focusNode!.hasFocus, isTrue);
    expect(widget.controller!.selection.baseOffset, 1);
    expect(tester.getSize(find.byType(PendingFormFieldEditor)).height, height);
  });

  testWidgets("authoritative settlement dismisses before a late HTTP reply", (tester) async {
    final reply = Completer<ApiResponse<FormReplyResult>>();
    when(() => harness.repository.declineForm(request: any(named: "request"))).thenAnswer((_) => reply.future);
    await open(tester: tester);
    await tap(tester: tester, label: "Decline request");
    harness.pending = false;
    harness.changes.add(false);
    await tester.pumpAndSettle();
    expect(find.byType(PendingFormModal), findsNothing);
    reply.complete(ApiResponse.success(const FormReplyAccepted()));
    await tester.pumpAndSettle();
    expect(harness.settlements, 0);
  });

  testWidgets("large text keeps cancellation reachable with reduced motion", (tester) async {
    await open(tester: tester, scale: 2, reduced: true, size: const Size(390, 844));
    await tap(tester: tester, label: "Cancel request");
    expect(tester.takeException(), isNull);
    verify(
      () => harness.repository.declineForm(
        request: const DeclineFormRequest(requestId: "request", sessionId: "owner", choice: FormDismissalChoice.cancel),
      ),
    ).called(1);
    expect(harness.settlements, 1);
  });

  testWidgets("closing leaves native state pending", (tester) async {
    await open(tester: tester);
    harness.router.pop();
    await tester.pumpAndSettle();
    verifyNever(() => harness.repository.replyToForm(request: any(named: "request")));
    verifyNever(() => harness.repository.declineForm(request: any(named: "request")));
    expect(harness.pending, isTrue);
  });

  testWidgets("retiring an in-flight form shows connection change and retains read-only drafts", (tester) async {
    final reply = Completer<ApiResponse<FormReplyResult>>();
    when(() => harness.repository.declineForm(request: any(named: "request"))).thenAnswer((_) => reply.future);
    await open(tester: tester);
    await tap(tester: tester, label: "Decline request");
    harness.statuses.add(const ConnectionStatus.disconnected());
    await tester.pumpAndSettle();
    expect(find.text("The connection changed. Close this request and reopen it after reconnecting."), findsOneWidget);
    expect(find.text("Sending your response to the coding agent…"), findsNothing);
    expect(tester.widget<TextField>(input(id: "text")).controller!.text, "Fixture answer");
    expect(tester.widget<TextField>(input(id: "text")).readOnly, isTrue);
    reply.complete(ApiResponse.success(const FormReplyAccepted()));
    await tester.pumpAndSettle();
    expect(find.byType(PendingFormModal), findsOneWidget);
    expect(harness.settlements, 0);
  });

  testWidgets("an unknown schema blocks acceptance but permits an explicit negative reply", (tester) async {
    const form = PendingForm(
      id: "request",
      sessionID: "owner",
      displaySessionId: "display",
      title: "Fixture form",
      message: "Unsupported fixture input.",
      fields: [
        PendingFormField(
          id: "unknown",
          label: "Fixture field",
          description: null,
          isRequired: true,
          schema: FormSchemaUnknown(),
        ),
      ],
    );
    when(() => harness.repository.getPendingForms(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingFormsResponse(data: [form])));
    await open(tester: tester);
    expect(
      tester.widget<PregoButtonsSolid>(find.widgetWithText(PregoButtonsSolid, "Submit answers")).onPressed,
      isNull,
    );
    await tap(tester: tester, label: "Decline request");
    expect(harness.settlements, 1);
    verifyNever(() => harness.repository.replyToForm(request: any(named: "request")));
  });

  testWidgets("empty text and an emptied selection stay explicit instead of becoming omission", (tester) async {
    await open(tester: tester);
    await tester.enterText(input(id: "text"), "");
    await tap(tester: tester, label: "No");
    await tap(tester: tester, label: "Visible multiple option");
    await tap(tester: tester, label: "Visible multiple option");
    await tap(tester: tester, label: "Submit answers");
    final request =
        verify(() => harness.repository.replyToForm(request: captureAny(named: "request"))).captured.single
            as ReplyToFormRequest;
    expect(request.values["text"], const FormTextValue(value: ""));
    expect(request.values["choices"], const FormChoicesValue(optionIds: []));
    expect(request.values.containsKey("choice"), isFalse);
  });

  testWidgets("phone form viewport leaves space for the software keyboard", (tester) async {
    await open(tester: tester, size: const Size(390, 844));
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final viewport = find.descendant(of: find.byType(PendingFormModal), matching: find.byType(SingleChildScrollView));
    expect(tester.getRect(viewport).bottom, lessThanOrEqualTo(844 - 320));
    await tap(tester: tester, label: "Cancel request");
    expect(harness.settlements, 1);
  });

  for (final validation in [true, false]) {
    testWidgets("${validation ? 'validation' : 'transport failure'} stays visible above scrolled fields", (
      tester,
    ) async {
      when(() => harness.repository.replyToForm(request: any(named: "request"))).thenAnswer(
        (_) async => validation
            ? ApiResponse.success(const FormValidationFailed(fieldErrors: {"count": FormValidationIssue.outOfRange}))
            : ApiResponse.error(ApiError.generic()),
      );
      await open(tester: tester, size: const Size(390, 844));
      final controller = tester.widget<TextField>(input(id: "text")).controller!;
      controller.selection = const TextSelection.collapsed(offset: 3);
      await tap(tester: tester, label: "No");
      final submit = find.widgetWithText(PregoButtonsSolid, "Submit answers");
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      final position = Scrollable.of(tester.element(submit)).position;
      final offset = position.pixels;
      expect(offset, greaterThan(0));
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final status = find.text(
        validation
            ? "Check the highlighted fields. Your other answers are kept."
            : "Your response could not be confirmed. Your answers are kept here; you can try again.",
      );
      expect(tester.getRect(status).top, greaterThanOrEqualTo(0));
      expect(tester.getRect(status).bottom, lessThanOrEqualTo(tester.getRect(submit).top));
      expect(position.pixels, offset);
      expect(tester.widget<TextField>(input(id: "text")).controller, same(controller));
      expect(controller.selection.baseOffset, 3);
      expect(controller.text, "Fixture answer");
      expect(harness.settlements, 0);
    });
  }
}
