import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/features/session_detail/widgets/question_modal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

class _ReplyCapture {
  String? requestId;
  List<ReplyAnswer>? answers;

  void onReply(String requestId, List<ReplyAnswer> answers) {
    this.requestId = requestId;
    this.answers = answers;
  }
}

GoRouter _createRouter({
  required SesoriQuestionAsked question,
  required _ReplyCapture capture,
  required Stream<bool> isPendingStream,
  required VoidCallback onResolvedRemotely,
  bool Function()? isPendingNow,
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
                    onReply: capture.onReply,
                    onReject: (_) {},
                    isPendingStream: isPendingStream,
                    isPendingNow: isPendingNow ?? () => true,
                    onResolvedRemotely: onResolvedRemotely,
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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

  testWidgets("advancing to the next question resets current question state", (tester) async {
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
      isPendingStream: const Stream<bool>.empty(),
      onResolvedRemotely: () {},
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

  testWidgets("dismisses itself when already resolved before the sheet subscribes", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a release channel",
            header: "Release channel",
            options: [QuestionOption(label: "Stable", description: "Release to everyone")],
          ),
        ],
      ),
      capture: capture,
      isPendingStream: isPending.stream,
      isPendingNow: () => false,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    expect(find.text("Choose a release channel"), findsNothing);
    expect(capture.requestId, isNull);
    expect(capture.answers, isNull);
    expect(remoteDismissals, 1);
  });

  testWidgets("a local answer racing the resolved signal pops only the sheet", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a release channel",
            header: "Release channel",
            options: [QuestionOption(label: "Stable", description: "Release to everyone")],
          ),
        ],
      ),
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    // Answering resolves the request optimistically: the `false` emission
    // arrives while the sheet is still mounted in its exit animation. The
    // listener must not pop a second time (that would remove the page).
    await tester.tap(find.text("Stable"));
    await tester.pump();
    await tester.tap(find.text("Submit"));
    isPending.add(false);
    await tester.pumpAndSettle();

    expect(capture.requestId, "question-1");
    expect(find.text("Choose a release channel"), findsNothing);
    expect(find.byKey(const Key("open-question-modal")), findsOneWidget);
    expect(remoteDismissals, 0);
  });

  testWidgets("ignores actions tapped during the exit animation after a remote resolution", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    addTearDown(isPending.close);
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a release channel",
            header: "Release channel",
            options: [QuestionOption(label: "Stable", description: "Release to everyone")],
          ),
        ],
      ),
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () {},
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    isPending.add(false);
    // Mid exit animation: the buttons are still on screen and tappable, but
    // the request is already resolved — no answer may be sent.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text("Stable"), warnIfMissed: false);
    await tester.tap(find.text("Submit"), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(capture.requestId, isNull);
    expect(capture.answers, isNull);
  });

  testWidgets("ignores the resolved signal while exiting from a barrier dismissal", (tester) async {
    final capture = _ReplyCapture();
    final isPending = StreamController<bool>();
    var remoteDismissals = 0;
    addTearDown(isPending.close);
    final router = _createRouter(
      question: _questionAsked(
        questions: const [
          QuestionInfo(
            question: "Choose a release channel",
            header: "Release channel",
            options: [QuestionOption(label: "Stable", description: "Release to everyone")],
          ),
        ],
      ),
      capture: capture,
      isPendingStream: isPending.stream,
      onResolvedRemotely: () => remoteDismissals++,
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildApp(router: router));
    await _openQuestionModal(tester);

    // Barrier tap pops the route without going through the modal's dismiss
    // path; a resolution landing mid-exit-animation must not pop the page.
    await tester.tapAt(const Offset(200, 50));
    await tester.pump(const Duration(milliseconds: 50));
    isPending.add(false);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key("open-question-modal")), findsOneWidget);
    expect(remoteDismissals, 0);
  });
}
