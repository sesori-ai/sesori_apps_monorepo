import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/invocation_card.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/queued_message_bubble.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/sent_bubble_landing.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/user_message_card.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

const _skill = PromptTurnShape.invocation(
  name: "fixture-greeter",
  source: CommandSource.skill,
  arguments: "Greet the team\nin two lines",
);

const _message = MessageWithParts(
  info: Message.user(
    id: "m1",
    sessionID: "s1",
    agent: null,
    time: null,
    promptId: "p1",
    invocation: CommandInvocation(
      name: "fixture-greeter",
      source: CommandSource.skill,
      arguments: "Greet the team\nin two lines",
    ),
  ),
  parts: [MessagePart.text(id: "t1", sessionID: "s1", messageID: "m1", text: "Greet the team\nin two lines")],
);

Future<void> _pump(WidgetTester tester, {required Widget child, double width = 390}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => SentBubbleLanding(child: child ?? const SizedBox.shrink()),
      home: Scaffold(
        body: Align(alignment: Alignment.topCenter, child: child),
      ),
    ),
  );
}

QueuedMessageBubble _queued({required QueuedMessageBubblePresentation presentation, required PromptTurnShape shape}) =>
    QueuedMessageBubble(
      key: const ValueKey("row"),
      displayText: "/fixture-greeter Greet the team\nin two lines",
      isCommand: true,
      shape: shape,
      attachmentCount: 0,
      localAttachments: const [],
      presentation: presentation,
    );

Finder get _surface => find.descendant(of: find.byType(InvocationCard), matching: find.byType(AnimatedContainer));

void main() {
  testWidgets("shows what ran over its arguments, at the leading edge", (tester) async {
    for (final width in [390.0, 1200.0]) {
      await _pump(
        tester,
        width: width,
        child: const UserMessageCard(message: _message, shape: _skill, outlineFade: null),
      );

      expect(find.text("You ran /fixture-greeter"), findsOneWidget);
      expect(find.text("Skill"), findsOneWidget);
      final rect = tester.getRect(_surface);
      // The surface's rect includes its row margin.
      expect(rect.left, 0);
      expect(rect.width - PregoSpacing.xl * 2, lessThanOrEqualTo((width - PregoSpacing.xl * 2) * 0.76 + 0.01));
    }
  });

  testWidgets("gives dictated arguments a slot to land on, as a bubble does", (tester) async {
    await _pump(
      tester,
      child: const UserMessageCard(message: _message, shape: _skill, outlineFade: null),
    );

    final slot = tester.widget<SentBubbleSlot>(
      find.descendant(of: find.byType(InvocationCard), matching: find.byType(SentBubbleSlot)),
    );
    expect(slot.text, "Greet the team\nin two lines");
  });

  testWidgets("is a record, not a control: no ink, no button role", (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      child: const UserMessageCard(message: _message, shape: _skill, outlineFade: null),
    );

    expect(find.descendant(of: find.byType(InvocationCard), matching: find.byType(InkResponse)), findsNothing);
    await tester.tap(find.text("You ran /fixture-greeter"));
    await tester.pump();
    expect(find.descendant(of: find.byType(InvocationCard), matching: find.byType(InkResponse)), findsNothing);

    final node = tester.getSemantics(find.bySemanticsLabel(RegExp("^You ran skill fixture-greeter")));
    expect(node, isSemantics(isButton: false));
    semantics.dispose();
  });

  testWidgets("keeps one size from sending through queued to confirmed", (tester) async {
    Future<Size> sizeOf(QueuedMessageBubblePresentation presentation) async {
      await _pump(
        tester,
        child: _queued(presentation: presentation, shape: _skill),
      );
      await tester.pumpAndSettle();
      return tester.getSize(_surface);
    }

    final sending = await sizeOf(
      const QueuedMessageBubblePresentation.sending(harnessName: "Codex", sendingSince: null, reservesLine: false),
    );
    final queued = await sizeOf(QueuedMessageBubblePresentation.pending(onCancel: () {}, sentAt: DateTime(2000)));
    final confirmed = await sizeOf(
      QueuedMessageBubblePresentation.delivered(
        message: ({required outlineFade}) =>
            UserMessageCard(message: _message, shape: _skill, outlineFade: outlineFade),
      ),
    );

    expect(queued, sending);
    expect(confirmed, sending);
    // The queued line names no command: the card already does.
    await sizeOf(QueuedMessageBubblePresentation.pending(onCancel: () {}, sentAt: DateTime(2000)));
    expect(find.text("Queued"), findsOneWidget);
  });

  testWidgets("falls back to the bubble when the turn is not an invocation", (tester) async {
    await _pump(
      tester,
      child: _queued(
        presentation: QueuedMessageBubblePresentation.pending(onCancel: () {}, sentAt: DateTime(2000)),
        shape: const PromptTurnShape.bubble(),
      ),
    );

    expect(find.byType(InvocationCard), findsNothing);
    expect(find.byType(UserMessageBubble), findsOneWidget);
    expect(find.text("Queued command"), findsOneWidget);
  });
}
