import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:go_router/go_router.dart";
import "package:sesori_mobile/features/session_detail/widgets/question_modal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";

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
}
