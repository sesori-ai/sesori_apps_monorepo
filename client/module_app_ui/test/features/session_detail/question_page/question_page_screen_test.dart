import "dart:async";
import "dart:convert";
import "dart:typed_data";

import "package:bloc_test/bloc_test.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _MockPendingPageCubit() extends MockCubit<PendingPageState> implements PendingPageCubit;

class _MockSessionDetailCubit() extends MockCubit<SessionDetailState> implements SessionDetailCubit;

/// A 1×1 transparent PNG.
final _png = base64Decode(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
);

const _plan = PageQuestion(
  id: "plan",
  title: "Rollout plan",
  // The image in the Markdown renders nothing, so nothing loads from the network.
  body: "Pick **one**. ![remote](https://example.invalid/fixture.png)",
  images: [],
  kind: PageSingleChoice(
    options: [
      PageOption(id: "canary", label: "Canary", description: "5% first", image: null, recommended: true),
      PageOption(id: "all", label: "All at once", description: null, image: null, recommended: false),
    ],
  ),
  isRequired: true,
);
const _checks = PageQuestion(
  id: "checks",
  title: "Checks to run",
  body: null,
  images: [],
  kind: PageMultipleChoice(
    options: [
      PageOption(id: "unit", label: "Unit tests", description: null, image: null, recommended: false),
      PageOption(id: "e2e", label: "End-to-end tests", description: null, image: null, recommended: false),
    ],
  ),
  isRequired: false,
);
const _why = PageQuestion(
  id: "why",
  title: "Anything to watch?",
  body: null,
  images: [],
  kind: PageTextInput(),
  isRequired: false,
);
const _future = PageQuestion(
  id: "future",
  title: "A newer question",
  body: null,
  images: [],
  kind: PageQuestionKindUnknown(),
  isRequired: true,
);

PendingPage _page({required List<PageSection> sections}) =>
    PendingPage(id: "page-1", sessionId: "session-1", displaySessionId: null, title: "Release plan", intro: "Fixture intro", sections: sections);

final _questionsPage = _page(
  sections: const [
    PageSection(heading: "Rollout", body: "Fixture section", images: [], questions: [_plan, _checks, _why, _future]),
  ],
);

PageImage _image({required int width, required int height}) =>
    PageImage(path: "/fixture/page-images/$width-$height.png", width: width, height: height, caption: null);

Widget _scoped({required PendingPageCubitFactory createPendingPageCubit, required Widget child}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: SessionDetailPresentationScope(
    returnToSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    openHarnessSettings: () {},
    openBridgeSettings: () {},
    openSideChat: null,
    messageImageRepository: () => throw UnimplementedError(),
    imageSaver: () => throw UnimplementedError(),
    imageClipboard: () => throw UnimplementedError(),
    imageSharer: () => throw UnimplementedError(),
    sessionRepository: () => throw UnimplementedError(),
    createPendingPageCubit: createPendingPageCubit,
    createPendingFormCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
    createFilePreviewCubit: ({required reference}) => throw UnimplementedError(),
    createExternalActionCubit: ({required requestId, required sessionId}) => throw UnimplementedError(),
    canShareImages: false,
    openExternalLink: ({required url, required mode}) async => false,
    openSession: ({required projectId, required sessionId, required sessionTitle, required readOnly}) {},
    child: child,
  ),
);

void main() {
  late _MockPendingPageCubit cubit;
  late StreamController<PendingPageState> states;

  setUp(() {
    cubit = _MockPendingPageCubit();
    states = StreamController<PendingPageState>.broadcast();
    addTearDown(states.close);
    when(() => cubit.submit()).thenAnswer((_) async {});
    when(() => cubit.dismiss()).thenAnswer((_) async {});
    when(() => cubit.retry()).thenAnswer((_) async {});
  });

  // Shimmers and spinners never settle, so those states pump frames instead.
  Future<void> settle(WidgetTester tester, {required bool animating}) async {
    if (!animating) {
      await tester.pumpAndSettle();
      return;
    }
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    required PendingPageState state,
    String? source,
    bool animating = false,
  }) async {
    whenListen(cubit, states.stream, initialState: state);
    await tester.pumpWidget(
      _scoped(
        createPendingPageCubit: ({required requestId, required sessionId}) => cubit,
        child: BlocProvider<PendingPageCubit>.value(
          value: cubit,
          child: QuestionPageScreen(source: source, onClose: () {}),
        ),
      ),
    );
    await settle(tester, animating: animating);
  }

  Future<void> emit(WidgetTester tester, PendingPageState state, {bool animating = false}) async {
    states.add(state);
    await settle(tester, animating: animating);
  }

  IconData? optionIcon(WidgetTester tester, String optionId) => tester
      .widget<Icon>(
        find.descendant(of: find.byKey(Key("question-page-option-$optionId")), matching: find.byType(Icon)).first,
      )
      .icon;

  PageEditing editing({required PageDraft draft, PageFeedback feedback = const PageFeedbackNone()}) =>
      PageEditing(page: _questionsPage, draft: draft, feedback: feedback);

  testWidgets("names its source and sends picks, text and notes to the cubit", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty), source: "Claude Code · Fix the login");

    expect(find.text("Release plan"), findsWidgets);
    expect(find.text("From Claude Code · Fix the login"), findsOneWidget);
    expect(find.text("0 of 3 answered"), findsOneWidget);
    expect(find.text("Required"), findsNWidgets(2));
    // Recommended is a label, never a pick.
    expect(find.text("Recommended"), findsOneWidget);
    expect(optionIcon(tester, "canary"), TablerRegular.circle);
    // The newer kind reads as needing an update and never blocks Submit.
    expect(find.text("This question needs an updated Sesori app. You can submit without it."), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.tap(find.text("Canary"));
    verify(() => cubit.setChoice(questionId: "plan", optionId: "canary")).called(1);

    await emit(
      tester,
      editing(draft: PageDraft.empty.withChoice(questionId: "plan", optionId: "canary")),
    );
    expect(optionIcon(tester, "canary"), TablerRegular.circle_dot);
    expect(find.text("1 of 3 answered"), findsOneWidget);
    // Tapping the pick again clears it.
    await tester.tap(find.text("Canary"));
    verify(() => cubit.setChoice(questionId: "plan", optionId: null)).called(1);

    await tester.ensureVisible(find.text("End-to-end tests"));
    await tester.tap(find.text("End-to-end tests"));
    verify(() => cubit.setChoices(questionId: "checks", optionIds: ["e2e"])).called(1);
    await emit(
      tester,
      editing(draft: PageDraft.empty.withChoices(questionId: "checks", optionIds: ["e2e"])),
    );
    await tester.ensureVisible(find.text("Unit tests"));
    await tester.tap(find.text("Unit tests"));
    // Kept in the options' order.
    verify(() => cubit.setChoices(questionId: "checks", optionIds: ["unit", "e2e"])).called(1);

    await tester.enterText(find.descendant(of: find.byKey(const Key("question-page-answer-why")), matching: find.byType(TextField)), "Error rate");
    verify(() => cubit.setText(questionId: "why", text: "Error rate")).called(1);
    await tester.enterText(find.descendant(of: find.byKey(const Key("question-page-note-plan")), matching: find.byType(TextField)), "Watch EU");
    verify(() => cubit.setQuestionNote(questionId: "plan", note: "Watch EU")).called(1);
    // A text question has no separate note; its box already is free text.
    expect(find.byKey(const Key("question-page-note-why")), findsNothing);
    await tester.ensureVisible(find.byKey(const Key("question-page-closing-note")));
    expect(find.text("Anything else?"), findsOneWidget);
    await tester.enterText(find.descendant(of: find.byKey(const Key("question-page-closing-note")), matching: find.byType(TextField)), "Thanks");
    verify(() => cubit.setNote(note: "Thanks")).called(1);

    await tester.tap(find.byKey(const Key("question-page-submit")));
    verify(() => cubit.submit()).called(1);
  });

  testWidgets("Submit with a required question unanswered scrolls to it with the reason", (tester) async {
    final long = _page(
      sections: [
        for (var index = 0; index < 6; index++)
          PageSection(heading: "Background $index", body: "Fixture text\n\n" * 6, images: const [], questions: const []),
        const PageSection(heading: null, body: null, images: [], questions: [_plan]),
      ],
    );
    await pumpScreen(tester, state: PageEditing(page: long, draft: PageDraft.empty, feedback: const PageFeedbackNone()));
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(tester.getRect(find.text("Rollout plan")).top, greaterThan(viewport.bottom));

    await tester.tap(find.byKey(const Key("question-page-submit")));
    verify(() => cubit.submit()).called(1);
    await emit(tester, PageSubmitting(page: long, draft: PageDraft.empty, action: PageAction.submit), animating: true);
    await emit(
      tester,
      PageEditing(page: long, draft: PageDraft.empty, feedback: PageFeedbackInvalid(questionIds: const ["plan"])),
    );

    final title = tester.getRect(find.text("Rollout plan"));
    expect(title.top, greaterThanOrEqualTo(viewport.top));
    expect(title.bottom, lessThanOrEqualTo(viewport.bottom));
    expect(find.byKey(const Key("question-page-issue-plan")), findsOneWidget);
    expect(find.text("Answer this question to submit."), findsOneWidget);
    expect(find.text("1 question needs your attention"), findsOneWidget);
  });

  for (final (reason, label) in [
    (PageReadOnlyReason.answered, "Answered"),
    (PageReadOnlyReason.answeredElsewhere, "Answered on another device"),
    (PageReadOnlyReason.dismissed, "Dismissed"),
  ]) {
    testWidgets("read-only $reason fills in the answers and disables the controls", (tester) async {
      final draft = PageDraft(
        answers: const {
          "plan": PageAnswer(questionId: "plan", value: PageChoiceAnswer(optionId: "all"), note: "Watch EU"),
          "why": PageAnswer(questionId: "why", value: PageTextAnswer(text: "Error rate"), note: null),
        },
        note: "Thanks",
      );
      await pumpScreen(tester, state: PageReadOnly(page: _questionsPage, draft: draft, reason: reason));

      expect(find.text(label), findsOneWidget);
      expect(find.byKey(const Key("question-page-submit")), findsNothing);
      expect(find.byKey(const Key("question-page-menu")), findsNothing);
      expect(optionIcon(tester, "all"), TablerRegular.circle_dot);
      expect(find.text("Watch EU"), findsOneWidget);
      expect(find.text("Error rate"), findsOneWidget);
      expect(find.text("Thanks"), findsOneWidget);
      for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(field.enabled, isFalse);
      }
      await tester.tap(find.text("Canary"));
      verifyNever(() => cubit.setChoice(questionId: any(named: "questionId"), optionId: any(named: "optionId")));
    });
  }

  testWidgets("a page settling elsewhere while open turns read-only in place", (tester) async {
    final draft = PageDraft.empty.withChoice(questionId: "plan", optionId: "canary");
    await pumpScreen(tester, state: editing(draft: draft));
    final before = tester.getRect(find.text("Rollout plan"));

    await emit(tester, PageReadOnly(page: _questionsPage, draft: draft, reason: PageReadOnlyReason.answeredElsewhere));

    expect(tester.getRect(find.text("Rollout plan")), before);
    expect(find.text("Answered on another device"), findsOneWidget);
    expect(optionIcon(tester, "canary"), TablerRegular.circle_dot);
  });

  testWidgets("a missing page says it is no longer available", (tester) async {
    await pumpScreen(tester, state: const PageMissing());

    expect(find.text("This page is no longer available."), findsOneWidget);
    expect(find.byKey(const Key("question-page-submit")), findsNothing);
  });

  testWidgets("a failed open offers a retry", (tester) async {
    await pumpScreen(tester, state: PageLoadFailed(cause: ApiError.generic()));

    await tester.tap(find.text("Try again"));
    verify(() => cubit.retry()).called(1);
  });

  testWidgets("a page with no questions offers Done", (tester) async {
    await pumpScreen(
      tester,
      state: PageEditing(
        page: _page(sections: const [PageSection(heading: "Heads up", body: "Fixture", images: [], questions: [])]),
        draft: PageDraft.empty,
        feedback: const PageFeedbackNone(),
      ),
    );

    expect(find.text("Done"), findsOneWidget);
    expect(find.textContaining("answered"), findsNothing);
  });

  testWidgets("Dismiss page in the top bar's menu dismisses through the cubit", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty));

    await tester.tap(find.byKey(const Key("question-page-menu")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Dismiss page"));
    await tester.pumpAndSettle();
    verify(() => cubit.dismiss()).called(1);
  });

  group("images", () {
    PendingPageState imagePage({required PageImage image}) => PageEditing(
      page: _page(sections: [PageSection(heading: null, body: null, images: [image], questions: const [])]),
      draft: PageDraft.empty,
      feedback: const PageFeedbackNone(),
    );

    testWidgets("hold their declared aspect ratio while loading and after a failed load", (tester) async {
      final image = _image(width: 800, height: 400);
      final load = Completer<Uint8List?>();
      when(() => cubit.loadImage(image: image)).thenAnswer((_) => load.future);
      await pumpScreen(tester, state: imagePage(image: image), animating: true);

      final loading = tester.getSize(find.byKey(const Key("question-page-image-box")));
      expect(loading.width / loading.height, closeTo(2, 0.01));

      load.complete(null);
      await settle(tester, animating: true);
      expect(find.byKey(const Key("question-page-image-unavailable")), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key("question-page-image-box"))), loading);
    });

    testWidgets("a tall image narrows to the height cap", (tester) async {
      final image = _image(width: 400, height: 1600);
      when(() => cubit.loadImage(image: image)).thenAnswer((_) async => _png);
      await pumpScreen(tester, state: imagePage(image: image), animating: true);

      final size = tester.getSize(find.byKey(const Key("question-page-image-box")));
      expect(size.height, 420);
      expect(size.width, 105);
      expect(find.byType(Image), findsOneWidget);
    });
  });

  testWidgets("the scope's opener slides the page up and down over the session", (tester) async {
    final session = _MockSessionDetailCubit();
    whenListen(
      session,
      const Stream<SessionDetailState>.empty(),
      initialState: const SessionDetailState.loading(launchHandoff: null, seededComposer: null),
    );
    whenListen(cubit, states.stream, initialState: const PageLoading());
    final opened = <(String, String)>[];
    await tester.pumpWidget(
      _scoped(
        createPendingPageCubit: ({required requestId, required sessionId}) {
          opened.add((requestId, sessionId));
          return cubit;
        },
        child: BlocProvider<SessionDetailCubit>.value(
          value: session,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => SessionDetailPresentationScope.read(
                    context,
                  ).openPage(context: context, requestId: "page-1", sessionId: "session-1"),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text("Open"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final midway = tester.getRect(find.byType(QuestionPageScreen)).top;
    expect(midway, greaterThan(0));
    expect(midway, lessThan(screenHeight));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(QuestionPageScreen)).top, 0);
    expect(opened, [("page-1", "session-1")]);

    await emit(tester, PageEditing(page: _questionsPage, draft: PageDraft.empty, feedback: const PageFeedbackNone()));
    expect(find.text("0 of 3 answered"), findsOneWidget);

    await tester.tap(find.byKey(const Key("question-page-close")));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPageScreen), findsNothing);
  });

  testWidgets("a wide window shows the page as a wide overlay over the dimmed session", (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = _MockSessionDetailCubit();
    whenListen(
      session,
      const Stream<SessionDetailState>.empty(),
      initialState: const SessionDetailState.loading(launchHandoff: null, seededComposer: null),
    );
    whenListen(cubit, states.stream, initialState: const PageMissing());
    await tester.pumpWidget(
      _scoped(
        createPendingPageCubit: ({required requestId, required sessionId}) => cubit,
        child: BlocProvider<SessionDetailCubit>.value(
          value: session,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => SessionDetailPresentationScope.read(
                    context,
                  ).openPage(context: context, requestId: "page-1", sessionId: "session-1"),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open"));
    await tester.pumpAndSettle();

    final panel = tester.getRect(find.byType(QuestionPageScreen));
    expect(panel.width, PregoModalWidth.code.pixels);
    expect(panel.center.dx, 700);
    expect(panel.bottom, 900);

    await tester.tapAt(const Offset(40, 450));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPageScreen), findsNothing);
  });
}
