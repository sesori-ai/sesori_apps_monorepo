import "dart:async";
import "dart:ui" show SemanticsAction;

import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_mobile/features/session_detail/widgets/question_modal.dart";
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

SesoriQuestionAsked _questionAsked({required List<QuestionInfo> questions}) {
  return SesoriQuestionAsked(
    id: "question-1",
    sessionID: "session-1",
    displaySessionId: null,
    questions: questions,
  );
}

void main() {
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
    await tester.enterText(find.byType(TextField), "Web preview");
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

    await tester.enterText(find.byType(TextField), "Web preview");
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
    await tester.enterText(find.byType(TextField), "   ");
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
    await tester.enterText(find.byType(TextField), "Web preview");
    await tester.pump();
    await tester.tap(find.byKey(const Key("custom-answer-toggle")));
    await tester.pumpAndSettle();

    expect(find.text("Web preview"), findsOneWidget);

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
    await tester.enterText(find.byType(TextField), "Need a follow-up pass");
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

    await tester.enterText(find.byType(TextField), "Need a follow-up pass");
    await tester.pump();
    await tester.tap(find.byKey(const Key("custom-answer-toggle")));
    await tester.pumpAndSettle();

    expect(find.text("Need a follow-up pass"), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);

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

    await tester.enterText(find.byType(TextField), "  Include the changelog.  ");
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
    await tester.enterText(find.byType(TextField), "Also notify QA");
    await tester.pump();

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    expect(find.text("Choose rollout speed"), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull);
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
    await tester.enterText(find.byType(TextField), "Notify QA");
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
    await tester.enterText(find.byType(TextField), "Notify QA and Docs");
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-step-1")));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Gradual"));
    await tester.pump();

    await tester.tap(find.byKey(const Key("question-step-2")));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), "Include the migration guide");
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
    expect(
      tester.widget<FilledButton>(find.byKey(const Key("question-primary-action"))).onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key("question-step-0")));
    await tester.pumpAndSettle();
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
    await tester.enterText(find.byType(TextField), "Web preview");
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
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
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
}
