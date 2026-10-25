import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// `CupertinoSliverRefreshControl` triggers at 100 logical px by default.
const double _trigger = 100;

void main() {
  group("PregoSliverRefreshControl", () {
    late int refreshes;

    setUp(() => refreshes = 0);

    Widget harness() {
      return MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              PregoSliverRefreshControl(
                onRefresh: () async => refreshes++,
                decorate: null,
                onPulledExtentChanged: null,
              ),
              SliverList.list(
                children: [for (var i = 0; i < 20; i++) SizedBox(height: 80, child: Text("row $i"))],
              ),
            ],
          ),
        ),
      );
    }

    testWidgets("a pull past the trigger refreshes once, after the finger lifts", (tester) async {
      await tester.pumpWidget(harness());

      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, _trigger + 140));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(refreshes, 0, reason: "the refresh waits for the release");

      await gesture.up();
      await tester.pumpAndSettle();
      expect(refreshes, 1);
    });

    testWidgets("a pull abandoned before the trigger does not refresh", (tester) async {
      await tester.pumpWidget(harness());

      final gesture = await tester.startGesture(const Offset(200, 100));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();
      await gesture.moveBy(const Offset(0, -60));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(refreshes, 0);
    });
  });
}
