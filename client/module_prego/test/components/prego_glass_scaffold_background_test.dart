import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("page background remains painted behind the keyboard", (tester) async {
    const keyboardInset = 180.0;
    const pageBackground = Color(0xFF123456);
    final devicePixelRatio = tester.view.devicePixelRatio;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * devicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: const PregoGlassScaffold(
          title: "Title",
          automaticallyImplyLeading: false,
          backgroundColor: pageBackground,
          slivers: [SliverFillRemaining(child: SizedBox.expand())],
        ),
      ),
    );

    // The outer Material scaffold owns keyboard avoidance but still fills the
    // window, so its surface is what iOS reveals around the translucent
    // keyboard after the inner GlassScaffold resizes above it.
    final scaffoldFinder = find.byType(Scaffold);
    final scaffold = tester.widget<Scaffold>(scaffoldFinder);
    final logicalHeight = tester.view.physicalSize.height / devicePixelRatio;
    expect(tester.getSize(scaffoldFinder).height, logicalHeight);
    expect(scaffold.backgroundColor, pageBackground);
  });
}
