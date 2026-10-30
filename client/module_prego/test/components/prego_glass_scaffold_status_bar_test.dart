import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

Widget _harness({required PregoDesignSystem prego}) {
  return MaterialApp(
    theme: ThemeData(extensions: [prego]),
    home: const PregoGlassScaffold(
      title: "Title",
      automaticallyImplyLeading: false,
      slivers: [SliverToBoxAdapter(child: SizedBox(height: 10))],
    ),
  );
}

SystemUiOverlayStyle _statusBarStyle(WidgetTester tester) {
  final AnnotatedRegion<SystemUiOverlayStyle> region = tester.widget(
    find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
  );
  return region.value;
}

void main() {
  // The scaffold paints the app's own theme, so the status-bar icons have to
  // contrast with that — not with the device's appearance setting, which an
  // in-app light/dark choice deliberately overrides.

  testWidgets("provides standalone Material and Scaffold ancestors", (tester) async {
    late BuildContext scaffoldContext;
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
                  scaffoldContext = context;
                  return const TextField();
                },
              ),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    ScaffoldMessenger.of(scaffoldContext).showSnackBar(const SnackBar(content: Text("Notice")));
    await tester.pump();
    expect(find.text("Notice"), findsOneWidget);
  });

  group("on iOS", () {
    const statusBarHeight = 47.0;
    var tapped = <int>[];

    Future<void> pumpLongList(WidgetTester tester) async {
      tapped = [];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS, extensions: [PregoDesignSystem.light]),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(top: statusBarHeight)),
              child: PregoGlassScaffold(
                title: "Title",
                automaticallyImplyLeading: false,
                slivers: [
                  SliverList.builder(
                    itemCount: 100,
                    itemBuilder: (context, index) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => tapped.add(index),
                      child: SizedBox(height: 80, child: Text("Row $index")),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pumpAndSettle();
    }

    double offset(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position.pixels;

    testWidgets("a status-bar tap scrolls the page to the top", (tester) async {
      await pumpLongList(tester);
      expect(offset(tester), greaterThan(0));

      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.statusBar.name,
        SystemChannels.statusBar.codec.encodeMethodCall(const MethodCall("handleScrollToTop")),
        (_) {},
      );
      await tester.pumpAndSettle();

      expect(offset(tester), 0);
    });

    testWidgets("a touch on the status bar does not reach the row under it", (tester) async {
      await pumpLongList(tester);

      await tester.tapAt(const Offset(200, statusBarHeight / 2));
      await tester.pumpAndSettle();

      expect(tapped, isEmpty);
    });
  });

  testWidgets("a light app keeps dark status-bar icons on a dark device", (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_harness(prego: PregoDesignSystem.light));
    await tester.pump();

    expect(_statusBarStyle(tester), SystemUiOverlayStyle.dark);
  });

  testWidgets("a dark app keeps light status-bar icons on a light device", (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await tester.pumpWidget(_harness(prego: PregoDesignSystem.dark));
    await tester.pump();

    expect(_statusBarStyle(tester), SystemUiOverlayStyle.light);
  });
}
