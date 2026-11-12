import "dart:async";
import "dart:ui" show SemanticsAction;

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _ReplyCapture() {
  String? requestId;
  List<ReplyAnswer>? answers;
  String? rejectedRequestId;
  Stream<bool> pendingStream = const Stream.empty();
  bool isPending = true;

  void onReply({required String requestId, required List<ReplyAnswer> answers}) {
    this.requestId = requestId;
    this.answers = answers;
  }

  void onReject({required String requestId}) {
    rejectedRequestId = requestId;
  }
}

GoRouter _createRouter({
  required SesoriQuestionAsked question,
  required _ReplyCapture capture,
}) {
  return GoRouter(
    routes: [
      GoRoute(
        path: "/",
        builder: (context, state) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key("open-question-modal"),
                onPressed: () {
                  QuestionModal.show(
                    context,
                    question: question,
                    onReply: (requestId, answers) => capture.onReply(
                      requestId: requestId,
                      answers: answers,
                    ),
                    onReject: (requestId) => capture.onReject(requestId: requestId),
                    isPendingStream: capture.pendingStream,
                    isPending: () => capture.isPending,
                    openExternalLink: ({required url, required mode}) async => true,
                  );
                },
                child: const Text("Open question modal"),
              ),
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildApp({required GoRouter router}) {
  return MaterialApp.router(
    routerConfig: router,
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

Future<void> _openQuestionModal(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key("open-question-modal")));
  await tester.pumpAndSettle();
}

/// Types a custom answer, first picking "Other" when its field is not open yet.
Future<void> _enterCustomAnswer({required WidgetTester tester, required String text}) async {
  if (find.byType(TextField).evaluate().isEmpty) {
    await tester.tap(find.byKey(const Key("custom-answer-toggle")));
    await tester.pumpAndSettle();
  }
  await tester.enterText(find.byType(TextField), text);
}

SesoriQuestionAsked _questionAsked({required List<QuestionInfo> questions}) {
  return SesoriQuestionAsked(
    id: "question-1",
    sessionID: "session-1",
    displaySessionId: null,
    questions: questions,
  );
}

void main() {
  testWidgets("typed external requests offer a cancel handoff instead of ordinary answers", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: const SesoriQuestionAsked(
        id: "external-request",
        sessionID: "session-1",
        displaySessionId: null,
        interactionKind: QuestionInteractionKind.externalAction,
        questions: [
          QuestionInfo(
            header: "MCP authorization",
            question: "Update the client or cancel this request.",
            options: [QuestionOption(label: "Cancel", description: "Cancel the native request.")],
            multiple: false,
            custom: false,
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);
    expect(find.byKey(const Key("question-primary-action")), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text("Cancel request"));
    await tester.pumpAndSettle();
    expect(capture.rejectedRequestId, "external-request");
    expect(capture.answers, isNull);
  });

  for (final omitCustom in [false, true]) {
    testWidgets("checkbox and separate text questions preserve ${omitCustom ? 'omission' : 'identical values'}", (
      tester,
    ) async {
      final capture = _ReplyCapture();
      final router = _createRouter(
        question: _questionAsked(
          questions: const [
            QuestionInfo(
              question: "Choose deployment targets",
              header: "Targets",
              multiple: true,
              custom: false,
              options: [
                QuestionOption(label: "iOS", description: "iPhone"),
                QuestionOption(label: "Android", description: "Android phone"),
              ],
            ),
            QuestionInfo(question: "Add another target", header: "Other", custom: true, options: []),
          ],
        ),
        capture: capture,
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(_buildApp(router: router));
      await _openQuestionModal(tester);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text("iOS"));
      await tester.pump();
      await tester.tap(find.text("Android"));
      await tester.pump();
      expect(capture.answers, isNull);
      await tester.tap(find.byKey(const Key("question-primary-action")));
      await tester.pumpAndSettle();

      if (omitCustom) {
        await tester.tap(find.byKey(const Key("decline-current-question")));
      } else {
        await _enterCustomAnswer(tester: tester, text: "iOS");
      }
      await tester.pump();
      await tester.tap(find.byKey(const Key("question-primary-action")));
      await tester.pumpAndSettle();

      expect(capture.answers, [
        const ReplyAnswer(values: ["iOS", "Android"]),
        ReplyAnswer(values: omitCustom ? const [] : const ["iOS"]),
      ]);
      expect(capture.rejectedRequestId, isNull);
    });
  }

  testWidgets("multi-select questions submit selected options and custom text together", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose deployment targets",
            header: "Targets",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "iOS", description: "Ship to iPhone"),
              QuestionOption(label: "Android", description: "Ship to Android"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("iOS"));
    await tester.pump();
    await _enterCustomAnswer(tester: tester, text: "Web preview");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.requestId, "question-1");
    expect(capture.answers, [
      const ReplyAnswer(values: ["iOS", "Web preview"]),
    ]);
  });

  testWidgets("multi-select questions keep custom text when an option is selected afterward", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose deployment targets",
            header: "Targets",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "iOS", description: "Ship to iPhone"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await _enterCustomAnswer(tester: tester, text: "Web preview");
    await tester.pump();
    await tester.tap(find.text("iOS"));
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["iOS", "Web preview"]),
    ]);
  });

  testWidgets("multi-select questions ignore blank custom text when options are selected", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose deployment targets",
            header: "Targets",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "iOS", description: "Ship to iPhone"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("iOS"));
    await tester.pump();
    await _enterCustomAnswer(tester: tester, text: "   ");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["iOS"]),
    ]);
  });

  testWidgets("multi-select questions can deselect custom text without clearing the option or text", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose deployment targets",
            header: "Targets",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "iOS", description: "Ship to iPhone"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("iOS"));
    await tester.pump();
    await _enterCustomAnswer(tester: tester, text: "Web preview");
    await tester.pump();
    await tester.tap(find.byKey(const Key("custom-answer-toggle")));
    await tester.pumpAndSettle();

    expect(find.text("Web preview"), findsNothing);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["iOS"]),
    ]);
  });

  testWidgets("single-select questions keep custom answers exclusive", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Pick one response",
            header: "Response",
            custom: true,
            options: [
              QuestionOption(label: "Approve", description: "Looks good"),
              QuestionOption(label: "Reject", description: "Needs changes"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("Approve"));
    await tester.pump();
    await _enterCustomAnswer(tester: tester, text: "Need a follow-up pass");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(
      capture.answers,
      [
        const ReplyAnswer(values: ["Need a follow-up pass"]),
      ],
    );
  });

  testWidgets("single-select questions can deselect custom text before choosing an option", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Pick one response",
            header: "Response",
            custom: true,
            options: [
              QuestionOption(label: "Approve", description: "Looks good"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await _enterCustomAnswer(tester: tester, text: "Need a follow-up pass");
    await tester.pump();
    await tester.tap(find.byKey(const Key("custom-answer-toggle")));
    await tester.pumpAndSettle();

    expect(find.text("Need a follow-up pass"), findsNothing);
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(capture.answers, isNull);
    expect(find.text("Choose an answer to submit."), findsOneWidget);

    await tester.tap(find.text("Approve"));
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["Approve"]),
    ]);
  });

  testWidgets("custom-only questions submit trimmed text", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Add any extra notes",
            header: "Notes",
            options: [],
            custom: true,
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await _enterCustomAnswer(tester: tester, text: "  Include the changelog.  ");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["Include the changelog."]),
    ]);
  });

  testWidgets("each question starts with an independent draft", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose platforms",
            header: "Platforms",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
          QuestionInfo(
            question: "Choose rollout speed",
            header: "Rollout",
            options: [
              QuestionOption(label: "Gradual", description: "Ramp slowly"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("Mobile"));
    await tester.pump();
    await _enterCustomAnswer(tester: tester, text: "Also notify QA");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text("Choose rollout speed"), findsOneWidget);
    expect(find.text("Also notify QA"), findsNothing);

    await tester.tap(find.text("Gradual"));
    await tester.pump();
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(
      capture.answers,
      [
        const ReplyAnswer(values: ["Mobile", "Also notify QA"]),
        const ReplyAnswer(values: ["Gradual"]),
      ],
    );
  });

  testWidgets("questions can be visited unanswered and edited in either direction", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose platforms",
            header: "Platforms",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
          QuestionInfo(
            question: "Choose rollout speed",
            header: "Rollout",
            custom: false,
            options: [
              QuestionOption(label: "Gradual", description: "Ramp slowly"),
            ],
          ),
          QuestionInfo(
            question: "Add release notes",
            header: "Notes",
            options: [],
            custom: true,
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("Mobile"));
    await _enterCustomAnswer(tester: tester, text: "Notify QA");
    await tester.pump();
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();

    expect(find.text("Choose rollout speed"), findsOneWidget);
    final unansweredNext = tester.widget<FilledButton>(
      find.byKey(const Key("question-primary-action")),
    );
    expect(unansweredNext.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    expect(find.text("Add release notes"), findsOneWidget);

    await tester.tap(find.byIcon(TablerRegular.arrow_left));
    await tester.pumpAndSettle();
    expect(find.text("Choose rollout speed"), findsOneWidget);

    await tester.tap(find.byKey(const Key("question-step-0")));
    await tester.pumpAndSettle();
    expect(find.text("Choose platforms"), findsOneWidget);
    expect(find.text("Notify QA"), findsOneWidget);

    await tester.tap(find.text("Mobile"));
    await _enterCustomAnswer(tester: tester, text: "Notify QA and Docs");
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-step-1")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gradual"));
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-step-2")));
    await tester.pumpAndSettle();
    await _enterCustomAnswer(tester: tester, text: "Include the migration guide");
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["Notify QA and Docs"]),
      const ReplyAnswer(values: ["Gradual"]),
      const ReplyAnswer(values: ["Include the migration guide"]),
    ]);
  });

  testWidgets("submit requires every question to be answered or explicitly declined", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            custom: false,
            options: [
              QuestionOption(label: "Dart", description: "Flutter language"),
            ],
          ),
          QuestionInfo(
            question: "Choose an IDE",
            header: "IDE",
            custom: false,
            options: [
              QuestionOption(label: "VS Code", description: "Microsoft editor"),
            ],
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            custom: false,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();

    expect(find.text("Answer or decline every question to submit."), findsOneWidget);

    // Submitting early answers the tap: it returns to the first open question.
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    expect(capture.answers, isNull);
    expect(find.text("Choose a language"), findsOneWidget);
    expect(find.text("Answer or decline every question to submit."), findsOneWidget);

    await tester.tap(find.text("Dart"));
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-step-1")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("decline-current-question")));
    await tester.pump();
    expect(find.text("Question declined"), findsOneWidget);

    await tester.tap(find.byKey(const Key("question-step-2")));
    await tester.pumpAndSettle();
    expect(find.byIcon(TablerRegular.minus), findsOneWidget);
    await tester.tap(find.text("Mobile"));
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.byKey(const Key("question-primary-action"))).onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["Dart"]),
      const ReplyAnswer(values: []),
      const ReplyAnswer(values: ["Mobile"]),
    ]);
  });

  testWidgets("answering a locally declined question starts a fresh answer", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose targets",
            header: "Targets",
            multiple: true,
            custom: true,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
              QuestionOption(label: "Desktop", description: "Desktop app"),
            ],
          ),
          QuestionInfo(
            question: "Choose rollout speed",
            header: "Rollout",
            custom: false,
            options: [
              QuestionOption(label: "Gradual", description: "Ramp slowly"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.text("Mobile"));
    await _enterCustomAnswer(tester: tester, text: "Web preview");
    await tester.pump();
    await tester.tap(find.byKey(const Key("decline-current-question")));
    await tester.pump();
    await tester.tap(find.text("Desktop"));
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gradual"));
    await tester.pump();
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();

    expect(capture.answers, [
      const ReplyAnswer(values: ["Desktop"]),
      const ReplyAnswer(values: ["Gradual"]),
    ]);
  });

  testWidgets("decline all confirms before rejecting the complete request", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            options: [],
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            options: [],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.byKey(const Key("decline-question-request")));
    await tester.pumpAndSettle();

    expect(find.text("Decline all questions?"), findsOneWidget);
    expect(capture.rejectedRequestId, isNull);

    await tester.tap(find.text("Keep answering"));
    await tester.pumpAndSettle();
    expect(find.byType(PregoBottomSheet), findsOneWidget);

    await tester.tap(find.byKey(const Key("decline-question-request")));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, "Decline all"));
    await tester.pumpAndSettle();

    expect(capture.rejectedRequestId, "question-1");
    expect(capture.answers, isNull);
    expect(find.byType(PregoBottomSheet), findsNothing);
  });

  testWidgets("system back cancels decline-all confirmation without dismissing drafts", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            custom: false,
            options: [
              QuestionOption(label: "Dart", description: "Flutter language"),
            ],
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            custom: false,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);
    await tester.tap(find.text("Dart"));
    await tester.pump();
    await tester.tap(find.byKey(const Key("decline-question-request")));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(PregoBottomSheet), findsOneWidget);
    expect(find.text("Choose a language"), findsOneWidget);
    expect(find.byIcon(TablerRegular.circle_dot), findsOneWidget);
    expect(capture.rejectedRequestId, isNull);
  });

  testWidgets("external resolution dismisses an open decline-all confirmation", (tester) async {
    final capture = _ReplyCapture();
    final pendingController = StreamController<bool>();
    capture.pendingStream = pendingController.stream;
    addTearDown(pendingController.close);
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            options: [],
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            options: [],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);
    await tester.tap(find.byKey(const Key("decline-question-request")));
    await tester.pumpAndSettle();
    expect(find.text("Decline all questions?"), findsOneWidget);

    capture.isPending = false;
    pendingController.add(false);
    await tester.pumpAndSettle();

    expect(find.byType(PregoBottomSheet), findsNothing);
    expect(capture.rejectedRequestId, isNull);
  });

  testWidgets("question-step semantics announce current resolution", (tester) async {
    final semantics = tester.ensureSemantics();
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            custom: false,
            options: [
              QuestionOption(label: "Dart", description: "Flutter language"),
            ],
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            custom: false,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    final firstStep = find.bySemanticsLabel("Question 1 of 2, unanswered");
    expect(firstStep, findsOneWidget);
    expect(
      tester.getSemantics(firstStep).getSemanticsData().hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(find.text("Dart"));
    await tester.pump();
    expect(find.bySemanticsLabel("Question 1 of 2, answered"), findsOneWidget);

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key("decline-current-question")));
    await tester.pump();
    expect(find.bySemanticsLabel("Question 2 of 2, declined"), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("rapid return to a custom question keeps one text field mounted", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Add release notes",
            header: "Notes",
            options: [],
            custom: true,
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            custom: false,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.byKey(const Key("question-step-0")));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets("compact keyboard viewport keeps the action row overflow-free", (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 300);
    addTearDown(tester.view.reset);
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Add release notes",
            header: "Notes",
            options: [],
            custom: true,
          ),
          QuestionInfo(
            question: "Choose a platform",
            header: "Platform",
            custom: false,
            options: [
              QuestionOption(label: "Mobile", description: "Phone app"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);
    await tester.tap(find.byKey(const Key("question-primary-action")));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text("Answer or decline all"), findsOneWidget);
    expect(find.byKey(const Key("question-primary-action")), findsOneWidget);
    expect(find.byKey(const Key("question-step-0")), findsNothing);
  });

  testWidgets("single questions expose only the request-level decline", (tester) async {
    final capture = _ReplyCapture();
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a language",
            header: "Language",
            custom: false,
            options: [
              QuestionOption(label: "Dart", description: "Flutter language"),
            ],
          ),
        ],
      ),
      capture: capture,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    expect(find.byKey(const Key("decline-current-question")), findsNothing);
    expect(find.widgetWithText(OutlinedButton, "Decline"), findsOneWidget);

    await tester.tap(find.byKey(const Key("decline-question-request")));
    await tester.pumpAndSettle();

    expect(capture.rejectedRequestId, "question-1");
    expect(find.byType(PregoBottomSheet), findsNothing);
  });

  group("Other answer", () {
    const colorQuestion = QuestionInfo(
      question: "Pick a color",
      header: "Color",
      custom: true,
      options: [
        QuestionOption(label: "Red", description: ""),
        QuestionOption(label: "Blue", description: "", isDefault: true),
      ],
    );

    Future<_ReplyCapture> open(WidgetTester tester) async {
      final capture = _ReplyCapture();
      final router = _createRouter(
        question: _questionAsked(questions: const [colorQuestion]),
        capture: capture,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(_buildApp(router: router));
      await _openQuestionModal(tester);
      return capture;
    }

    testWidgets("the default arrives selected and submits at once", (tester) async {
      final capture = await open(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byKey(const Key("question-primary-action")));
      await tester.pumpAndSettle();

      expect(capture.answers, [
        const ReplyAnswer(values: ["Blue"]),
      ]);
    });

    testWidgets("picking Other grows its field in below the options and focuses it", (tester) async {
      await open(tester);
      final redTop = tester.getTopLeft(find.text("Red")).dy;
      final otherTop = tester.getTopLeft(find.text("Other")).dy;

      await tester.tap(find.byKey(const Key("custom-answer-toggle")));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midHeight = tester.getSize(find.byType(AnimatedSize).first).height;
      await tester.pumpAndSettle();

      expect(midHeight, lessThan(tester.getSize(find.byType(AnimatedSize).first).height));
      // The sheet is anchored to the bottom, so it rises as the field grows;
      // inside it, the options keep their places and the field opens below.
      final otherTopAfter = tester.getTopLeft(find.text("Other")).dy;
      expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(otherTopAfter));
      expect(otherTopAfter - tester.getTopLeft(find.text("Red")).dy, otherTop - redTop);
      expect(tester.widget<TextField>(find.byType(TextField)).focusNode?.hasFocus, isTrue);

      await tester.tap(find.text("Red"));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets("submitting Other with an empty field explains why", (tester) async {
      final capture = await open(tester);
      await tester.tap(find.byKey(const Key("custom-answer-toggle")));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key("question-primary-action")));
      await tester.pumpAndSettle();

      expect(capture.answers, isNull);
      expect(find.byKey(const Key("custom-answer-empty-reason")), findsOneWidget);

      await tester.enterText(find.byType(TextField), "Green");
      await tester.pump();
      expect(find.byKey(const Key("custom-answer-empty-reason")), findsNothing);
      await tester.tap(find.byKey(const Key("question-primary-action")));
      await tester.pumpAndSettle();
      expect(capture.answers, [
        const ReplyAnswer(values: ["Green"]),
      ]);
    });
  });
}
