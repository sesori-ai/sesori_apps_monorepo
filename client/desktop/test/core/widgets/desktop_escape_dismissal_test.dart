import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_desktop/core/widgets/desktop_escape_dismissal.dart";

void main() {
  testWidgets("Escape dismisses a popup route", (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopEscapeDismissal(child: child ?? const SizedBox.shrink()),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              autofocus: true,
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => const AlertDialog(
                  title: Text("Confirm action"),
                  content: Focus(autofocus: true, child: Text("Keep open")),
                ),
              ),
              child: const Text("Open dialog"),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text("Open dialog"));
    await tester.pumpAndSettle();
    expect(find.text("Confirm action"), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text("Confirm action"), findsNothing);
  });

  testWidgets("Escape relinquishes text focus without popping the page", (tester) async {
    final focusNode = FocusNode();
    addTearDown(focusNode.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopEscapeDismissal(child: child ?? const SizedBox.shrink()),
        home: Scaffold(body: TextField(autofocus: true, focusNode: focusNode)),
      ),
    );
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets("a closer Escape handler wins without dismissing twice", (tester) async {
    var innerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => DesktopEscapeDismissal(child: child ?? const SizedBox.shrink()),
        home: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => innerCalls++,
          },
          child: const Scaffold(
            body: Focus(autofocus: true, child: Text("Inner surface")),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(innerCalls, 1);
    expect(find.text("Inner surface"), findsOneWidget);
  });
}
