import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/edit_message_dialogs.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:theme_prego/module_prego.dart";

Future<void> _show(
  WidgetTester tester, {
  required MessageEditRefusal refusal,
  required VoidCallback? onFork,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showEditUnavailableDialog(context: context, refusal: refusal, onFork: onFork),
            child: const Text("Edit"),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text("Edit"));
  await tester.pumpAndSettle();
}

void main() {
  const fork = Key("edit_unavailable_fork");
  const ok = Key("edit_unavailable_ok");

  testWidgets("a follow-up sent mid-turn offers Fork, which closes the explanation and forks", (tester) async {
    var forks = 0;
    await _show(tester, refusal: MessageEditRefusal.sentMidTurn, onFork: () => forks++);

    expect(find.byKey(ok), findsOneWidget);
    await tester.tap(find.byKey(fork));
    await tester.pumpAndSettle();

    expect(forks, 1);
    expect(find.byKey(fork), findsNothing);
  });

  testWidgets("a follow-up sent mid-turn offers only OK where the session does not fork", (tester) async {
    await _show(tester, refusal: MessageEditRefusal.sentMidTurn, onFork: null);

    expect(find.byKey(ok), findsOneWidget);
    expect(find.byKey(fork), findsNothing);
  });

  testWidgets("a command offers no Fork", (tester) async {
    await _show(tester, refusal: MessageEditRefusal.command, onFork: () {});

    expect(find.byKey(ok), findsOneWidget);
    expect(find.byKey(fork), findsNothing);
  });
}
