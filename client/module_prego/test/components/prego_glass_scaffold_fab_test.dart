import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

const _fabKey = Key("fab");

/// The scaffold's floating action is positioned by the inner Material
/// [Scaffold]; this guards that it keeps the trailing `endFloat` placement.
Widget _harness() {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: const PregoGlassScaffold(
      title: "Title",
      titleMode: PregoTopNavigationTitleMode.inline,
      automaticallyImplyLeading: false,
      floatingActionButton: SizedBox(key: _fabKey, width: 120, height: 52),
      slivers: [SliverToBoxAdapter(child: SizedBox(height: 10))],
    ),
  );
}

void main() {
  testWidgets("the action sits on the trailing edge", (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final fab = tester.getRect(find.byKey(_fabKey));
    final page = tester.getRect(find.byType(PregoGlassScaffold));
    // Scaffold's endFloat inset — the placement every other screen relies on.
    expect(page.right - fab.right, moreOrLessEquals(kFloatingActionButtonMargin, epsilon: 0.5));
  });

  testWidgets("a snackbar clears the floating action", (tester) async {
    late BuildContext bodyContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: PregoGlassScaffold(
          title: "Title",
          automaticallyImplyLeading: false,
          floatingActionButton: const SizedBox(key: _fabKey, width: 120, height: 52),
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  bodyContext = context;
                  return const SizedBox(height: 10);
                },
              ),
            ),
          ],
        ),
      ),
    );

    ScaffoldMessenger.of(bodyContext).showSnackBar(const SnackBar(content: Text("Notice")));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byKey(_fabKey)).bottom, lessThanOrEqualTo(tester.getRect(find.byType(SnackBar)).top));
  });

  testWidgets("a snackbar clears the keyboard", (tester) async {
    late BuildContext bodyContext;
    const keyboardInset = 180.0;
    final devicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: PregoGlassScaffold(
          title: "Title",
          automaticallyImplyLeading: false,
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  bodyContext = context;
                  return const TextField();
                },
              ),
            ),
          ],
        ),
      ),
    );

    tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset * devicePixelRatio);
    ScaffoldMessenger.of(bodyContext).showSnackBar(const SnackBar(content: Text("Notice")));
    await tester.pumpAndSettle();

    final logicalHeight = tester.view.physicalSize.height / devicePixelRatio;
    expect(tester.getRect(find.byType(SnackBar)).bottom, lessThanOrEqualTo(logicalHeight - keyboardInset));
  });
}
