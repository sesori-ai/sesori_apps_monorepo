import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget harness({bool disableAnimations = false}) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: const Scaffold(
        body: PregoLaunchStatus(
          semanticsLabel: "Launching session",
          messages: ["Preparing workspace", "Starting agent"],
        ),
      ),
    );
  }

  testWidgets("renders activity semantics and initial message", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(harness());

    expect(find.byType(PregoActivityIndicator), findsOneWidget);
    expect(find.text("Preparing workspace"), findsOneWidget);
    expect(tester.getSemantics(find.byType(PregoLaunchStatus)).label, "Launching session");

    handle.dispose();
  });

  testWidgets("rotates messages every 3.5 seconds", (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 3499));
    expect(find.text("Preparing workspace"), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text("Starting agent"), findsOneWidget);
  });

  testWidgets("keeps initial message still when motion is disabled", (tester) async {
    await tester.pumpWidget(harness(disableAnimations: true));
    await tester.pump(const Duration(seconds: 7));

    expect(find.text("Preparing workspace"), findsOneWidget);
    expect(find.text("Starting agent"), findsNothing);
  });
}
