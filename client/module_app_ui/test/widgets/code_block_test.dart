import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/src/l10n/app_localizations.dart";
import "package:sesori_app_ui/src/widgets/code_block.dart";
import "package:theme_prego/module_prego.dart";

String _lines(int count) => [for (var i = 1; i <= count; i++) "line $i"].join("\n");

Future<void> _pump(WidgetTester tester, {required String code}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: CodeBlock(code: code, language: "dart", highlightEnabled: false, isFullView: false),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("a block within the cap shows every line and no open action", (tester) async {
    await _pump(tester, code: _lines(12));

    expect(find.textContaining("line 12"), findsOneWidget);
    expect(find.textContaining("Open all"), findsNothing);
  });

  testWidgets("a long block shows its first lines and opens whole in a modal", (tester) async {
    await _pump(tester, code: _lines(40));

    expect(find.text(_lines(12)), findsOneWidget);
    expect(find.textContaining("line 13"), findsNothing);

    await tester.tap(find.text("Open all 40 lines"));
    await tester.pumpAndSettle();

    expect(find.text(_lines(40)), findsOneWidget);
    // The modal title and the capped block behind it; the full view drops its
    // own label because the modal already titles the language.
    expect(find.text("dart"), findsNWidgets(2));
  });
}
