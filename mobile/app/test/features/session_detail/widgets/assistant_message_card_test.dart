import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sesori_mobile/features/session_detail/widgets/assistant_message_card.dart';
import 'package:sesori_shared/sesori_shared.dart';

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

  group('AssistantMessageCard', () {
    testWidgets('renders View changes button', (tester) async {
      const message = MessageWithParts(
        info: Message(role: 'assistant', id: 'msg-1', sessionID: 'session-1'),
        parts: [
          MessagePart(
            id: 'part-1',
            sessionID: 'session-1',
            messageID: 'msg-1',
            type: 'text',
            text: 'Here is the code',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));
      expect(find.text('View changes'), findsOneWidget);
    });

    testWidgets('View changes button has correct icon', (tester) async {
      const message = MessageWithParts(
        info: Message(role: 'assistant', id: 'msg-1', sessionID: 'session-1'),
        parts: [
          MessagePart(
            id: 'part-1',
            sessionID: 'session-1',
            messageID: 'msg-1',
            type: 'text',
            text: 'Here is the code',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));
      expect(find.byIcon(Icons.difference_outlined), findsOneWidget);
    });

    testWidgets('View changes button is subtle (small font, muted color)', (tester) async {
      const message = MessageWithParts(
        info: Message(role: 'assistant', id: 'msg-1', sessionID: 'session-1'),
        parts: [
          MessagePart(
            id: 'part-1',
            sessionID: 'session-1',
            messageID: 'msg-1',
            type: 'text',
            text: 'Here is the code',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));
      final textFinder = find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'View changes' && widget.style?.fontSize == 12,
      );
      expect(textFinder, findsOneWidget);
    });

    testWidgets('button is present and tappable', (tester) async {
      const message = MessageWithParts(
        info: Message(role: 'assistant', id: 'msg-1', sessionID: 'session-1'),
        parts: [
          MessagePart(
            id: 'part-1',
            sessionID: 'session-1',
            messageID: 'msg-1',
            type: 'text',
            text: 'Here is the code',
          ),
        ],
      );

      await tester.pumpWidget(buildTestWidget(message));
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('View changes navigates to session diffs without messageId', (tester) async {
      const message = MessageWithParts(
        info: Message(
          role: 'assistant',
          id: 'assistant-msg-1',
          sessionID: 'session-1',
          parentID: 'user-msg-1',
        ),
        parts: [
          MessagePart(
            id: 'part-1',
            sessionID: 'session-1',
            messageID: 'assistant-msg-1',
            type: 'text',
            text: 'Here is the code',
          ),
        ],
      );

      final router = GoRouter(
        initialLocation: '/sessions/session-1',
        routes: [
          GoRoute(
            path: '/sessions/:sessionId',
            builder: (context, state) => const Scaffold(
              body: AssistantMessageCard(
                message: message,
                streamingText: {},
                children: [],
                childStatuses: {},
              ),
            ),
          ),
          GoRoute(
            path: '/sessions/:sessionId/diffs',
            builder: (context, state) => Scaffold(
              body: Text(
                'sessionId=${state.pathParameters["sessionId"] ?? ''}, noMessageId=${state.uri.queryParameters["messageId"] == null}',
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.text('View changes'));
      await tester.pumpAndSettle();

      expect(find.text('sessionId=session-1, noMessageId=true'), findsOneWidget);
    });
  });
}
