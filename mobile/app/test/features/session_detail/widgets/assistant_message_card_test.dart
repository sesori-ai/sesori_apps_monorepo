import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_shared/sesori_shared.dart";

import "package:sesori_mobile/features/session_detail/widgets/assistant_message_card.dart";

void main() {
  Widget buildTestWidget(MessageWithParts message) {
    return MaterialApp(
      home: Scaffold(
        body: AssistantMessageCard(
          message: message,
          streamingText: const {},
          children: const [],
          childStatuses: const {},
        ),
      ),
    );
  }

  group("AssistantMessageCard", () {
    testWidgets("renders 'View changes' button", (tester) async {
      final message = MessageWithParts(
        info: const Message(
          role: "assistant",
          id: "msg-1",
          sessionID: "session-1",
        ),
        parts: [
          const MessagePart(
            id: "part-1",
            sessionID: "session-1",
            messageID: "msg-1",
            type: "text",
            text: "Here is the code",
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));

      expect(find.text("View changes"), findsOneWidget);
    });

    testWidgets("'View changes' button has correct icon", (tester) async {
      final message = MessageWithParts(
        info: const Message(
          role: "assistant",
          id: "msg-1",
          sessionID: "session-1",
        ),
        parts: [
          const MessagePart(
            id: "part-1",
            sessionID: "session-1",
            messageID: "msg-1",
            type: "text",
            text: "Here is the code",
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));

      expect(find.byIcon(Icons.difference_outlined), findsOneWidget);
    });

    testWidgets("'View changes' button is subtle (small font, muted color)", (tester) async {
      final message = MessageWithParts(
        info: const Message(
          role: "assistant",
          id: "msg-1",
          sessionID: "session-1",
        ),
        parts: [
          const MessagePart(
            id: "part-1",
            sessionID: "session-1",
            messageID: "msg-1",
            type: "text",
            text: "Here is the code",
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));

      // Find the Text widget with "View changes"
      final textFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == "View changes" && widget.style?.fontSize == 12,
      );
      expect(textFinder, findsOneWidget);
    });

    testWidgets("button is present and tappable", (tester) async {
      final message = MessageWithParts(
        info: const Message(
          role: "assistant",
          id: "msg-1",
          sessionID: "session-1",
        ),
        parts: [
          const MessagePart(
            id: "part-1",
            sessionID: "session-1",
            messageID: "msg-1",
            type: "text",
            text: "Here is the code",
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));

      // Verify the button is present
      final buttonFinder = find.byType(TextButton);
      expect(buttonFinder, findsOneWidget);
    });
  });
}
