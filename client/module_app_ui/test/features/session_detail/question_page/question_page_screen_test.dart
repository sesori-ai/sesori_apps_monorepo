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

PendingPage _page({required List<PageSection> sections}) => PendingPage(
  id: "page-1",
  sessionId: "session-1",
  displaySessionId: null,
  title: "Release plan",
  intro: "Fixture intro",
  sections: sections,
);

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
  late int settledHere;

  setUp(() {
    settledHere = 0;
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
    String? title,
    bool animating = false,
  }) async {
    whenListen(cubit, states.stream, initialState: state);
    await tester.pumpWidget(
      _scoped(
        createPendingPageCubit: ({required requestId, required sessionId}) => cubit,
        child: BlocProvider<PendingPageCubit>.value(
          value: cubit,
          child: QuestionPageScreen(title: title, source: source, onClose: () {}, onSettledHere: () => settledHere++),
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
    await pumpScreen(
      tester,
      state: editing(draft: PageDraft.empty),
      source: "Claude Code · Fix the login",
    );

    expect(find.text("Release plan"), findsWidgets);
    expect(find.text("From Claude Code · Fix the login"), findsOneWidget);
    expect(find.text("3 left"), findsOneWidget);
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
      editing(
        draft: PageDraft.empty.withChoice(questionId: "plan", optionId: "canary"),
      ),
    );
    expect(optionIcon(tester, "canary"), TablerRegular.circle_dot);
    expect(find.text("2 left"), findsOneWidget);
    // Tapping the pick again clears it.
    await tester.tap(find.text("Canary"));
    verify(() => cubit.setChoice(questionId: "plan", optionId: null)).called(1);

    await tester.ensureVisible(find.text("End-to-end tests"));
    await tester.tap(find.text("End-to-end tests"));
    verify(() => cubit.setChoices(questionId: "checks", optionIds: ["e2e"])).called(1);
    await emit(
      tester,
      editing(
        draft: PageDraft.empty.withChoices(questionId: "checks", optionIds: ["e2e"]),
      ),
    );
    await tester.ensureVisible(find.text("Unit tests"));
    await tester.tap(find.text("Unit tests"));
    // Kept in the options' order.
    verify(() => cubit.setChoices(questionId: "checks", optionIds: ["unit", "e2e"])).called(1);

    await tester.enterText(
      find.descendant(of: find.byKey(const Key("question-page-answer-why")), matching: find.byType(TextField)),
      "Error rate",
    );
    verify(() => cubit.setText(questionId: "why", text: "Error rate")).called(1);
    await tester.enterText(
      find.descendant(of: find.byKey(const Key("question-page-note-plan")), matching: find.byType(TextField)),
      "Watch EU",
    );
    verify(() => cubit.setQuestionNote(questionId: "plan", note: "Watch EU")).called(1);
    // A text question has no separate note; its box already is free text.
    expect(find.byKey(const Key("question-page-note-why")), findsNothing);
    await tester.ensureVisible(find.byKey(const Key("question-page-closing-note")));
    expect(find.text("Anything else?"), findsOneWidget);
    await tester.enterText(
      find.descendant(of: find.byKey(const Key("question-page-closing-note")), matching: find.byType(TextField)),
      "Thanks",
    );
    verify(() => cubit.setNote(note: "Thanks")).called(1);

    await tester.tap(find.byKey(const Key("question-page-submit")));
    verify(() => cubit.submit()).called(1);
  });

  testWidgets("Submit with a required question unanswered scrolls to it with the reason", (tester) async {
    final long = _page(
      sections: [
        for (var index = 0; index < 6; index++)
          PageSection(
            heading: "Background $index",
            body: "Fixture text\n\n" * 6,
            images: const [],
            questions: const [],
          ),
        const PageSection(heading: null, body: null, images: [], questions: [_plan]),
      ],
    );
    await pumpScreen(
      tester,
      state: PageEditing(page: long, draft: PageDraft.empty, feedback: const PageFeedbackNone()),
    );
    final viewport = tester.getRect(find.byType(SingleChildScrollView));
    expect(tester.getRect(find.text("Rollout plan")).top, greaterThan(viewport.bottom));

    await tester.tap(find.byKey(const Key("question-page-submit")));
    verify(() => cubit.submit()).called(1);
    await emit(tester, PageSubmitting(page: long, draft: PageDraft.empty, action: PageAction.submit), animating: true);
    await emit(
      tester,
      PageEditing(
        page: long,
        draft: PageDraft.empty,
        feedback: PageFeedbackInvalid(questionIds: const ["plan"]),
      ),
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
          "plan": PageAnswer(
            questionId: "plan",
            value: PageChoiceAnswer(optionId: "all"),
            note: "Watch EU",
          ),
          "why": PageAnswer(
            questionId: "why",
            value: PageTextAnswer(text: "Error rate"),
            note: null,
          ),
        },
        note: "Thanks",
      );
      await pumpScreen(
        tester,
        state: PageReadOnly(page: _questionsPage, draft: draft, reason: reason),
      );

      expect(find.text(label), findsOneWidget);
      expect(find.byKey(const Key("question-page-submit")), findsNothing);
      // Hidden, keeping its room.
      expect(find.byKey(const Key("question-page-menu")).hitTestable(), findsNothing);
      expect(optionIcon(tester, "all"), TablerRegular.circle_dot);
      expect(find.text("Watch EU"), findsOneWidget);
      expect(find.byKey(const Key("question-page-note-plan")), findsOneWidget);
      expect(find.byKey(const Key("question-page-note-checks")), findsNothing);
      expect(find.text("Error rate"), findsOneWidget);
      expect(find.text("Thanks"), findsOneWidget);
      for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
        expect(field.enabled, isFalse);
      }
      await tester.tap(find.text("Canary"));
      verifyNever(
        () => cubit.setChoice(
          questionId: any(named: "questionId"),
          optionId: any(named: "optionId"),
        ),
      );
    });
  }

  testWidgets("a page settling elsewhere while open turns read-only in place", (tester) async {
    final draft = PageDraft.empty.withChoice(questionId: "plan", optionId: "canary");
    await pumpScreen(tester, state: editing(draft: draft));
    final before = tester.getRect(find.text("Rollout plan"));

    states.add(PageReadOnly(page: _questionsPage, draft: draft, reason: PageReadOnlyReason.answeredElsewhere));
    // The fold starts on the frame after the state arrives.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Empty notes fade as they fold, rather than vanishing in one frame.
    for (final key in ["question-page-note-plan", "question-page-closing-note"]) {
      final fade = tester.widget<FadeTransition>(
        find.ancestor(of: find.byKey(Key(key)), matching: find.byType(FadeTransition)).first,
      );
      expect(fade.opacity.value, inExclusiveRange(0, 1));
    }
    await tester.pumpAndSettle();

    expect(tester.getRect(find.text("Rollout plan")), before);
    expect(find.text("Answered on another device"), findsOneWidget);
    expect(optionIcon(tester, "canary"), TablerRegular.circle_dot);
    // Empty notes fold away once the page is read-only.
    expect(find.byKey(const Key("question-page-note-plan")), findsNothing);
    expect(find.byKey(const Key("question-page-closing-note")), findsNothing);
  });

  testWidgets("a dismiss refused because the page settled elsewhere turns read-only without an error", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty));
    final before = tester.getRect(find.text("Rollout plan"));

    await tester.tap(find.byKey(const Key("question-page-menu")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Dismiss page"));
    await emit(
      tester,
      PageSubmitting(page: _questionsPage, draft: PageDraft.empty, action: PageAction.dismiss),
      animating: true,
    );
    // Empty notes stay while the request is in flight, so nothing moves.
    expect(find.byKey(const Key("question-page-note-plan")), findsOneWidget);
    expect(find.byKey(const Key("question-page-closing-note")), findsOneWidget);
    // The cubit looks the page up before it would show the failure.
    await emit(
      tester,
      PageReadOnly(page: _questionsPage, draft: PageDraft.empty, reason: PageReadOnlyReason.dismissed),
    );

    expect(find.text("Dismissed"), findsOneWidget);
    expect(find.textContaining("Couldn't"), findsNothing);
    expect(settledHere, 0);
    expect(tester.getRect(find.text("Rollout plan")), before);
  });

  testWidgets("a missing page says it is no longer available", (tester) async {
    await pumpScreen(tester, state: const PageMissing());

    expect(find.text("This page is no longer available."), findsOneWidget);
    expect(find.byKey(const Key("question-page-submit")), findsNothing);
  });

  group("the header", () {
    // Long enough to be cut, so a change in the header's room would show.
    const source = "Claude Code · Required and dismiss questions before the agent ships the checkout release";
    Rect sourceRect(WidgetTester tester) => tester.getRect(find.text("From $source"));

    testWidgets("keeps the page's title when the page goes missing, and nothing in it moves", (tester) async {
      await pumpScreen(
        tester,
        state: editing(draft: PageDraft.empty),
        source: source,
      );
      // The header's title comes first; the body repeats it.
      final title = tester.getRect(find.text("Release plan").first);
      final from = sourceRect(tester);

      await emit(tester, const PageMissing());

      expect(find.text("This page is no longer available."), findsOneWidget);
      expect(tester.getRect(find.text("Release plan")), title);
      expect(sourceRect(tester), from);
    });

    testWidgets("shows the opener's title before the lookup and keeps it when the page is missing", (tester) async {
      await pumpScreen(tester, state: const PageLoading(), source: source, title: "Release plan", animating: true);
      expect(find.text("Release plan"), findsOneWidget);

      await emit(tester, const PageMissing());
      expect(find.text("Release plan"), findsOneWidget);
    });

    for (final (name, next) in [
      ("goes missing", const PageMissing() as PendingPageState),
      ("loads", PageEditing(page: _questionsPage, draft: PageDraft.empty, feedback: const PageFeedbackNone())),
    ]) {
      testWidgets("without a known title holds its height while the page $name", (tester) async {
        await pumpScreen(tester, state: const PageLoading(), source: source, animating: true);
        final from = sourceRect(tester);

        await emit(tester, next);
        expect(sourceRect(tester), from);
      });
    }
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
        page: _page(
          sections: const [PageSection(heading: "Heads up", body: "Fixture", images: [], questions: [])],
        ),
        draft: PageDraft.empty,
        feedback: const PageFeedbackNone(),
      ),
    );

    expect(find.text("Done"), findsOneWidget);
    expect(find.byKey(const Key("question-page-left")), findsNothing);
  });

  testWidgets("an accepted Submit closes the page once, as it looked while sending", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty));
    await emit(
      tester,
      PageSubmitting(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit),
      animating: true,
    );
    final before = tester.getRect(find.byKey(const Key("question-page-closing-note")));

    await emit(
      tester,
      PageSettledHere(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit),
      animating: true,
    );

    expect(settledHere, 1);
    // Nothing folds or changes while the page leaves.
    expect(tester.getRect(find.byKey(const Key("question-page-closing-note"))), before);
    expect(find.byKey(const Key("question-page-settled")), findsNothing);
  });

  for (final (name, outcome) in [
    (
      "fails",
      editing(
        draft: PageDraft.empty,
        feedback: PageFeedbackFailed(action: PageAction.submit, cause: ApiError.generic()),
      ),
    ),
    (
      "is refused as invalid",
      editing(
        draft: PageDraft.empty,
        feedback: PageFeedbackInvalid(questionIds: const ["plan"]),
      ),
    ),
    (
      "finds the page answered elsewhere",
      PageReadOnly(page: _questionsPage, draft: PageDraft.empty, reason: PageReadOnlyReason.answeredElsewhere),
    ),
    ("finds the page archived", const PageMissing() as PendingPageState),
  ]) {
    testWidgets("a Submit that $name keeps the page open", (tester) async {
      await pumpScreen(tester, state: editing(draft: PageDraft.empty));
      await emit(
        tester,
        PageSubmitting(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit),
        animating: true,
      );
      await emit(tester, outcome);
      expect(settledHere, 0);
    });
  }

  testWidgets("an accepted dismiss closes the page once", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty));
    await emit(tester, PageSubmitting(page: _questionsPage, draft: PageDraft.empty, action: PageAction.dismiss));
    await emit(tester, PageSettledHere(page: _questionsPage, draft: PageDraft.empty, action: PageAction.dismiss));

    expect(settledHere, 1);
    expect(find.byKey(const Key("question-page-settled")), findsNothing);
  });

  Future<void> tapDismiss(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key("question-page-menu")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Dismiss page"));
    await tester.pumpAndSettle();
  }

  testWidgets("the dismiss question wraps on a phone rather than being cut", (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpScreen(
      tester,
      state: editing(
        draft: PageDraft.empty.withChoice(questionId: "plan", optionId: "canary"),
      ),
    );

    await tapDismiss(tester);
    final title = tester.widget<Text>(find.text("Dismiss without sending your answers?"));
    expect(title.maxLines, isNull);
    expect(title.overflow, isNot(TextOverflow.ellipsis));
    expect(tester.takeException(), isNull);
  });

  testWidgets("Dismiss page on an untouched page dismisses at once", (tester) async {
    await pumpScreen(tester, state: editing(draft: PageDraft.empty));

    await tapDismiss(tester);
    expect(find.text("Dismiss without sending your answers?"), findsNothing);
    verify(() => cubit.dismiss()).called(1);
  });

  for (final (name, draft) in [
    ("a pick", PageDraft.empty.withChoice(questionId: "plan", optionId: "canary")),
    ("a closing note", PageDraft.empty.withNote(note: "Fixture note")),
  ]) {
    testWidgets("Dismiss page with $name asks first, and Cancel keeps it all", (tester) async {
      await pumpScreen(tester, state: editing(draft: draft));

      await tapDismiss(tester);
      expect(find.text("Dismiss without sending your answers?"), findsOneWidget);
      verifyNever(() => cubit.dismiss());

      await tester.tap(find.byKey(const Key("question-page-dismiss-cancel")));
      await tester.pumpAndSettle();
      expect(find.text("Dismiss without sending your answers?"), findsNothing);
      verifyNever(() => cubit.dismiss());
      verifyNever(() => cubit.setNote(note: any(named: "note")));
      verifyNever(
        () => cubit.setChoice(
          questionId: any(named: "questionId"),
          optionId: any(named: "optionId"),
        ),
      );

      await tapDismiss(tester);
      await tester.tap(find.byKey(const Key("question-page-dismiss-confirm")));
      await tester.pumpAndSettle();
      verify(() => cubit.dismiss()).called(1);
    });
  }

  testWidgets("numbers questions by section once the page has more than one", (tester) async {
    String? number(String questionId) => tester.widget<Text>(find.byKey(Key("question-page-number-$questionId"))).data;

    await pumpScreen(tester, state: editing(draft: PageDraft.empty));
    expect(
      [
        for (final id in ["plan", "checks", "why", "future"]) number(id),
      ],
      ["1", "2", "3", "4"],
    );

    final sectioned = _page(
      sections: const [
        PageSection(heading: "Rollout", body: null, images: [], questions: [_plan, _checks]),
        PageSection(heading: "Follow-up", body: null, images: [], questions: [_why]),
      ],
    );
    await emit(tester, PageEditing(page: sectioned, draft: PageDraft.empty, feedback: const PageFeedbackNone()));
    expect(
      [
        for (final id in ["plan", "checks", "why"]) number(id),
      ],
      ["1.1", "1.2", "2.1"],
    );
  });

  testWidgets("the left pill turns into a check mark once all is answered, and Submit stays put", (tester) async {
    final answered = PageDraft.empty
        .withChoice(questionId: "plan", optionId: "canary")
        .withChoices(questionId: "checks", optionIds: ["unit"])
        .withText(questionId: "why", text: "Fixture");
    await pumpScreen(
      tester,
      state: editing(draft: answered.withText(questionId: "why", text: null)),
    );
    expect(find.text("1 left"), findsOneWidget);
    final submit = tester.getRect(find.byKey(const Key("question-page-submit")));

    await emit(tester, editing(draft: answered));
    expect(find.byKey(const Key("question-page-left")), findsNothing);
    expect(find.byKey(const Key("question-page-all-answered")), findsOneWidget);
    expect(tester.widget<Icon>(find.byKey(const Key("question-page-all-answered"))).semanticLabel, "All answered");
    expect(tester.getRect(find.byKey(const Key("question-page-submit"))), submit);
  });

  group("Submit", () {
    Future<void> tapSubmit(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key("question-page-submit")));
      await tester.pumpAndSettle();
    }

    for (final (name, draft) in [
      ("a required question unanswered", PageDraft.empty.withChoices(questionId: "checks", optionIds: ["unit"])),
      (
        "everything answered",
        PageDraft.empty
            .withChoice(questionId: "plan", optionId: "canary")
            .withChoices(questionId: "checks", optionIds: ["unit"])
            .withText(questionId: "why", text: "Fixture"),
      ),
    ]) {
      testWidgets("with $name submits without asking", (tester) async {
        await pumpScreen(tester, state: editing(draft: draft));

        await tapSubmit(tester);
        expect(find.byKey(const Key("question-page-gaps-submit")), findsNothing);
        verify(() => cubit.submit()).called(1);
      });
    }

    testWidgets("with only optional questions unanswered asks first, and Submit anyway sends", (tester) async {
      await pumpScreen(
        tester,
        state: editing(
          draft: PageDraft.empty.withChoice(questionId: "plan", optionId: "canary"),
        ),
      );

      await tapSubmit(tester);
      expect(find.text("Submit with 2 unanswered questions?"), findsOneWidget);
      expect(find.text('The agent sees them as "no answer" and may ask again.'), findsOneWidget);
      verifyNever(() => cubit.submit());

      await tester.tap(find.byKey(const Key("question-page-gaps-submit")));
      await tester.pumpAndSettle();
      expect(find.text("Submit with 2 unanswered questions?"), findsNothing);
      verify(() => cubit.submit()).called(1);
    });

    testWidgets("Go to first closes the question and scrolls to the first unanswered question", (tester) async {
      final long = _page(
        sections: [
          const PageSection(heading: "Rollout", body: null, images: [], questions: [_plan]),
          for (var index = 0; index < 6; index++)
            PageSection(
              heading: "Background $index",
              body: "Fixture text\n\n" * 6,
              images: const [],
              questions: const [],
            ),
          const PageSection(heading: "Follow-up", body: null, images: [], questions: [_why]),
        ],
      );
      await pumpScreen(
        tester,
        state: PageEditing(
          page: long,
          draft: PageDraft.empty.withChoice(questionId: "plan", optionId: "canary"),
          feedback: const PageFeedbackNone(),
        ),
      );
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(tester.getRect(find.text("Anything to watch?")).top, greaterThan(viewport.bottom));

      await tapSubmit(tester);
      expect(find.text("Submit with 1 unanswered question?"), findsOneWidget);
      expect(find.text('The agent sees it as "no answer" and may ask again.'), findsOneWidget);
      await tester.tap(find.byKey(const Key("question-page-gaps-go-to-first")));
      await tester.pumpAndSettle();

      expect(find.text("Submit with 1 unanswered question?"), findsNothing);
      final title = tester.getRect(find.text("Anything to watch?"));
      expect(title.top, greaterThanOrEqualTo(viewport.top));
      expect(title.bottom, lessThanOrEqualTo(viewport.bottom));
      verifyNever(() => cubit.submit());
    });
  });

  group("images", () {
    PendingPageState imagePage({required PageImage image}) => PageEditing(
      page: _page(
        sections: [
          PageSection(heading: null, body: null, images: [image], questions: const []),
        ],
      ),
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
                  ).openPage(context: context, requestId: "page-1", sessionId: "session-1", title: null),
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
    // File links in the page's Markdown open through the session's cubit.
    expect(tester.element(find.byType(QuestionPageScreen)).read<SessionDetailCubit>(), session);

    await emit(tester, PageEditing(page: _questionsPage, draft: PageDraft.empty, feedback: const PageFeedbackNone()));
    expect(find.text("3 left"), findsOneWidget);

    await tester.tap(find.byKey(const Key("question-page-close")));
    await tester.pumpAndSettle();
    expect(find.byType(QuestionPageScreen), findsNothing);
    verifyNever(() => session.acknowledgeQuestionSettlement(requestId: any(named: "requestId")));
  });

  group("an accepted Submit through the scope's opener", () {
    late _MockSessionDetailCubit session;

    Future<void> open(WidgetTester tester) async {
      session = _MockSessionDetailCubit();
      whenListen(
        session,
        const Stream<SessionDetailState>.empty(),
        initialState: const SessionDetailState.loading(launchHandoff: null, seededComposer: null),
      );
      whenListen(
        cubit,
        states.stream,
        initialState: PageEditing(page: _questionsPage, draft: PageDraft.empty, feedback: const PageFeedbackNone()),
      );
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
                    ).openPage(context: context, requestId: "page-1", sessionId: "session-1", title: null),
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
    }

    testWidgets("settles the request on the session and slides the page down", (tester) async {
      await open(tester);

      states.add(PageSettledHere(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit));
      await tester.pump();
      verify(() => session.acknowledgeQuestionSettlement(requestId: "page-1")).called(1);
      // The pop starts the slide on the next frame.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final screenHeight = tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final midway = tester.getRect(find.byType(QuestionPageScreen)).top;
      expect(midway, greaterThan(0));
      expect(midway, lessThan(screenHeight));
      await tester.pumpAndSettle();
      expect(find.byType(QuestionPageScreen), findsNothing);
      expect(find.text("Open"), findsOneWidget);
    });

    testWidgets("while the page is already sliding down leaves the session in place", (tester) async {
      await open(tester);

      await tester.tap(find.byKey(const Key("question-page-close")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      states.add(PageSettledHere(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit));
      await tester.pumpAndSettle();

      verify(() => session.acknowledgeQuestionSettlement(requestId: "page-1")).called(1);
      expect(find.byType(QuestionPageScreen), findsNothing);
      expect(find.text("Open"), findsOneWidget);
    });

    testWidgets("under a route the page opened removes only the page", (tester) async {
      await open(tester);
      Navigator.of(
        tester.element(find.byType(QuestionPageScreen)),
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text("Fixture preview"))));
      await tester.pumpAndSettle();

      states.add(PageSettledHere(page: _questionsPage, draft: PageDraft.empty, action: PageAction.submit));
      await tester.pumpAndSettle();
      expect(find.text("Fixture preview"), findsOneWidget);
      expect(find.byType(QuestionPageScreen, skipOffstage: false), findsNothing);

      Navigator.of(tester.element(find.text("Fixture preview"))).pop();
      await tester.pumpAndSettle();
      expect(find.text("Open"), findsOneWidget);
    });
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
                  ).openPage(context: context, requestId: "page-1", sessionId: "session-1", title: null),
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

  testWidgets("three pages open in one session each count, ask and scroll on their own", (tester) async {
    final session = _MockSessionDetailCubit();
    whenListen(
      session,
      const Stream<SessionDetailState>.empty(),
      initialState: const SessionDetailState.loading(launchHandoff: null, seededComposer: null),
    );
    PendingPage page({required String id, required List<PageSection> sections}) => PendingPage(
      id: id,
      sessionId: "session-1",
      displaySessionId: null,
      title: "Fixture $id",
      intro: null,
      sections: sections,
    );
    final picked = PageDraft.empty.withChoice(questionId: "plan", optionId: "canary");
    final page2 = page(
      id: "page-2",
      sections: const [
        PageSection(heading: "Rollout", body: null, images: [], questions: [_plan]),
        PageSection(heading: "Follow-up", body: null, images: [], questions: [_why]),
      ],
    );
    final pages = {
      // Untouched: three left.
      "page-1": PageEditing(page: _questionsPage, draft: PageDraft.empty, feedback: const PageFeedbackNone()),
      // One optional question left, in its second section.
      "page-2": PageEditing(
        page: page2,
        draft: picked,
        feedback: const PageFeedbackNone(),
      ),
      // Two optional questions left, the first far down the page.
      "page-3": PageEditing(
        page: page(
          id: "page-3",
          sections: [
            const PageSection(heading: null, body: null, images: [], questions: [_plan]),
            for (var index = 0; index < 6; index++)
              PageSection(heading: null, body: "Fixture text\n\n" * 6, images: const [], questions: const []),
            const PageSection(heading: null, body: null, images: [], questions: [_checks, _why]),
          ],
        ),
        draft: picked,
        feedback: const PageFeedbackNone(),
      ),
    };
    final cubits = <String, _MockPendingPageCubit>{};
    final page2States = StreamController<PendingPageState>.broadcast();
    addTearDown(page2States.close);
    for (final MapEntry(key: id, value: state) in pages.entries) {
      final pageCubit = cubits[id] = _MockPendingPageCubit();
      whenListen(
        pageCubit,
        id == "page-2" ? page2States.stream : const Stream<PendingPageState>.empty(),
        initialState: state,
      );
      when(pageCubit.submit).thenAnswer((_) async {});
    }
    _MockPendingPageCubit pageCubit(String id) => cubits[id] ?? (throw StateError("no fixture page $id"));
    late BuildContext sessionContext;
    await tester.pumpWidget(
      _scoped(
        createPendingPageCubit: ({required requestId, required sessionId}) => pageCubit(requestId),
        child: BlocProvider<SessionDetailCubit>.value(
          value: session,
          child: Builder(
            builder: (context) {
              sessionContext = context;
              return const Scaffold(body: Text("Session"));
            },
          ),
        ),
      ),
    );
    // Page 2 opens last, so it sits on top of the other two.
    for (final id in ["page-1", "page-3", "page-2"]) {
      unawaited(
        SessionDetailPresentationScope.read(
          sessionContext,
        ).openPage(context: sessionContext, requestId: id, sessionId: "session-1", title: "Fixture $id"),
      );
      await tester.pumpAndSettle();
    }
    Finder screen(String id) =>
        find.byWidgetPredicate((widget) => widget is QuestionPageScreen && widget.title == "Fixture $id");
    Finder inPage(String id, Finder finder) => find.descendant(of: screen(id), matching: finder);
    double scrolled(String id) =>
        tester.state<ScrollableState>(inPage(id, find.byType(Scrollable)).first).position.pixels;

    expect(tester.widget<Text>(inPage("page-1", find.byKey(const Key("question-page-left")))).data, "3 left");
    expect(tester.widget<Text>(inPage("page-2", find.byKey(const Key("question-page-left")))).data, "1 left");
    expect(tester.widget<Text>(inPage("page-3", find.byKey(const Key("question-page-left")))).data, "2 left");
    expect(tester.widget<Text>(inPage("page-2", find.byKey(const Key("question-page-number-why")))).data, "2.1");
    expect(tester.widget<Text>(inPage("page-1", find.byKey(const Key("question-page-number-why")))).data, "3");

    // Page 2 asks about its own gap only and sends only itself.
    await tester.tap(inPage("page-2", find.byKey(const Key("question-page-submit"))));
    await tester.pumpAndSettle();
    expect(find.text("Submit with 1 unanswered question?"), findsOneWidget);
    await tester.tap(find.byKey(const Key("question-page-gaps-submit")));
    await tester.pumpAndSettle();
    verify(pageCubit("page-2").submit).called(1);
    verifyNever(pageCubit("page-1").submit);
    verifyNever(pageCubit("page-3").submit);

    // Settling page 2 closes only page 2.
    page2States.add(PageSettledHere(page: page2, draft: picked, action: PageAction.submit));
    await tester.pumpAndSettle();
    verify(() => session.acknowledgeQuestionSettlement(requestId: "page-2")).called(1);
    verifyNever(
      () => session.acknowledgeQuestionSettlement(
        requestId: any(named: "requestId", that: isNot("page-2")),
      ),
    );
    expect(screen("page-2"), findsNothing);
    expect(screen("page-1"), findsOneWidget);
    expect(screen("page-3"), findsOneWidget);
    expect(tester.widget<Text>(inPage("page-1", find.byKey(const Key("question-page-left")))).data, "3 left");
    expect(tester.widget<Text>(inPage("page-3", find.byKey(const Key("question-page-left")))).data, "2 left");
    expect(scrolled("page-1"), 0);
    expect(scrolled("page-3"), 0);

    // Go to first on page 3, now on top, scrolls page 3 alone.
    await tester.tap(inPage("page-3", find.byKey(const Key("question-page-submit"))));
    await tester.pumpAndSettle();
    expect(find.text("Submit with 2 unanswered questions?"), findsOneWidget);
    await tester.tap(find.byKey(const Key("question-page-gaps-go-to-first")));
    await tester.pumpAndSettle();
    expect(scrolled("page-3"), greaterThan(0));
    expect(scrolled("page-1"), 0);
    verifyNever(pageCubit("page-1").submit);
    verifyNever(pageCubit("page-3").submit);
  });
}
