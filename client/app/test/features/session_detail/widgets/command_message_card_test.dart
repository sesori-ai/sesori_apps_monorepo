import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/features/session_detail/widgets/command_message_card.dart";
import "package:sesori_mobile/features/session_detail/widgets/command_modal.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

MessageWithParts _commandMessage({
  required CommandOrigin origin,
  required String? arguments,
  required String result,
}) {
  const messageId = "command-message";
  const partId = "command-result";
  return MessageWithParts(
    info: Message.user(
      id: messageId,
      sessionID: "session-1",
      agent: null,
      time: null,
      command: CommandMessageInfo(
        name: "review",
        arguments: arguments,
        origin: origin,
        displayPartID: partId,
      ),
    ),
    parts: [
      MessagePart(
        id: partId,
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.text,
        text: result,
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      ),
    ],
  );
}

Widget _buildApp({
  required MessageWithParts message,
  required String? resultText,
}) {
  final command = (message.info as MessageUser).command!;
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    darkTheme: ThemeData(extensions: [PregoDesignSystem.dark]),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: CommandMessageCard(
        command: command,
        resultText: resultText,
      ),
    ),
  );
}

void main() {
  testWidgets("tap opens the command sheet with full command, origin, and result", (tester) async {
    final message = _commandMessage(
      origin: CommandOrigin.manual,
      arguments: "lib/main.dart --strict",
      result: "Completed **review** result.",
    );

    await tester.pumpWidget(
      _buildApp(
        message: message,
        resultText: "Completed **review** result.",
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("/review lib/main.dart --strict"), findsOneWidget);
    expect(find.text("Manual"), findsOneWidget);
    expect(find.byKey(CommandMessageCard.resultPreviewKey), findsOneWidget);

    await tester.tap(find.byType(CommandMessageCard));
    await tester.pumpAndSettle();

    final modal = find.byType(CommandModal);
    expect(modal, findsOneWidget);
    expect(find.descendant(of: modal, matching: find.text("/review lib/main.dart --strict")), findsOneWidget);
    expect(find.descendant(of: modal, matching: find.text("Manual")), findsOneWidget);
    final markdown = find.descendant(of: modal, matching: find.byType(MarkdownBody));
    expect(tester.widget<MarkdownBody>(markdown).data, "Completed **review** result.");
  });

  testWidgets("sheet distinguishes an empty result and shows the unknown origin fallback", (tester) async {
    final message = _commandMessage(
      origin: CommandOrigin.unknown,
      arguments: null,
      result: "",
    );

    await tester.pumpWidget(
      _buildApp(
        message: message,
        resultText: null,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Unknown"), findsOneWidget);
    expect(find.byKey(CommandMessageCard.resultPreviewKey), findsNothing);

    await tester.tap(find.byType(CommandMessageCard));
    await tester.pumpAndSettle();

    final modal = find.byType(CommandModal);
    expect(find.descendant(of: modal, matching: find.text("No result available.")), findsOneWidget);
  });

  testWidgets("sheet renders direct command result input", (tester) async {
    final message = _commandMessage(
      origin: CommandOrigin.automatic,
      arguments: null,
      result: "",
    );

    await tester.pumpWidget(
      _buildApp(
        message: message,
        resultText: "Partial **streamed** result",
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CommandMessageCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final modal = find.byType(CommandModal);
    final markdown = find.descendant(of: modal, matching: find.byType(MarkdownBody));
    expect(tester.widget<MarkdownBody>(markdown).data, "Partial **streamed** result");
    expect(find.descendant(of: modal, matching: find.text("Waiting for result...")), findsNothing);
  });
}
