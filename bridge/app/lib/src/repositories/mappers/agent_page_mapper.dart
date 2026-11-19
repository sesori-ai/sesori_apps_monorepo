import "package:sesori_shared/sesori_shared.dart"
    show PendingPage, PendingQuestion, QuestionInfo, QuestionInteractionKind, QuestionOption;

extension AgentPageMapper on PendingPage {
  /// The marker that carries the page through the pending-question pipeline.
  /// Apps that know pages open the page itself; older apps show its title
  /// and can only cancel it.
  PendingQuestion toPendingQuestion() {
    return PendingQuestion(
      id: id,
      sessionID: sessionId,
      displaySessionId: displaySessionId,
      questions: [
        QuestionInfo(
          question: title,
          header: title,
          options: const [
            // COMPATIBILITY 2026-11-18 (v1.14.2): apps before v1.10.1 render this
            // marker as a plain question, so it offers one Cancel option. Remove the
            // option once no supported app predates v1.10.1.
            QuestionOption(
              label: "Cancel",
              description:
                  "Answering this page needs an updated Sesori app. Cancelling tells the agent you didn't answer.",
            ),
          ],
          multiple: false,
          custom: false,
        ),
      ],
      interactionKind: QuestionInteractionKind.page,
    );
  }
}
