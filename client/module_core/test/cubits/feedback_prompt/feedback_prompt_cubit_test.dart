import "package:bloc_test/bloc_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:test/test.dart";

void main() {
  late FakeFeedbackPromptService feedbackPromptService;

  setUp(() => feedbackPromptService = FakeFeedbackPromptService());

  tearDown(() => feedbackPromptService.promptsController.close());

  blocTest<FeedbackPromptCubit, FeedbackPromptPresentation>(
    "asks to show the sheet once per claimed showing, each a distinct state",
    build: () => FeedbackPromptCubit(feedbackPromptService: feedbackPromptService),
    act: (_) {
      feedbackPromptService.promptsController
        ..add(null)
        ..add(null);
    },
    expect: () => const [
      FeedbackPromptPresentation.show(sequence: 1),
      FeedbackPromptPresentation.show(sequence: 2),
    ],
  );

  test("starts idle and stops listening once closed", () async {
    final cubit = FeedbackPromptCubit(feedbackPromptService: feedbackPromptService);
    expect(cubit.state, const FeedbackPromptPresentation.idle());

    await cubit.close();

    expect(feedbackPromptService.promptsController.hasListener, isFalse);
  });
}
