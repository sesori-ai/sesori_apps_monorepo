import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("shows bounded confirmation only after a successful copy", (tester) async {
    var shouldSucceed = false;
    var calls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: PregoCopyIconButton(
            onCopy: () async {
              calls++;
              return shouldSucceed;
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.copy), findsOneWidget);
    await tester.tap(find.byType(PregoCopyIconButton));
    await tester.pump();
    expect(calls, 1);
    expect(find.byIcon(Icons.copy), findsOneWidget);

    shouldSucceed = true;
    await tester.tap(find.byType(PregoCopyIconButton));
    await tester.pump();
    await tester.pump();
    expect(calls, 2);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });
}
