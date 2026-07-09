import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Bottom-anchors the sheet with loose constraints so it wraps to its content
/// height — matching how a modal route lays it out (and making the height
/// measurable).
Widget _harness(Widget child) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  home: Scaffold(
    body: Align(alignment: Alignment.bottomCenter, child: child),
  ),
);

Widget _sheet({
  String title = "Sheet title",
  String? subtitle,
  PregoSheetTitleAlignment alignment = PregoSheetTitleAlignment.center,
  VoidCallback? onClose,
  VoidCallback? onBack,
  List<Widget>? actions,
  Widget? child,
}) => PregoBottomSheet(
  title: title,
  subtitle: subtitle,
  alignment: alignment,
  onClose: onClose,
  onBack: onBack,
  actions: actions,
  child: child ?? const SizedBox(height: 120),
);

void main() {
  group("PregoBottomSheet", () {
    testWidgets("renders the header title, subtitle, and grabber", (tester) async {
      await tester.pumpWidget(_harness(_sheet(title: "Why", subtitle: "Because")));
      await tester.pump();

      expect(find.text("Why"), findsOneWidget);
      expect(find.text("Because"), findsOneWidget);
      expect(find.byType(PregoTopNavigationSheets), findsOneWidget);
    });

    testWidgets("close button is labelled and invokes onClose", (tester) async {
      var closed = 0;
      await tester.pumpWidget(_harness(_sheet(onClose: () => closed++)));
      await tester.pump();

      expect(find.byIcon(TablerRegular.x), findsOneWidget);
      // Uses the platform's localized close tooltip — no bespoke string.
      expect(find.bySemanticsLabel("Close"), findsOneWidget);

      await tester.tap(find.byIcon(TablerRegular.x));
      await tester.pump();
      expect(closed, 1);
    });

    testWidgets("onBack swaps the close button for a back button", (tester) async {
      var backs = 0;
      await tester.pumpWidget(_harness(_sheet(onClose: () {}, onBack: () => backs++)));
      await tester.pump();

      expect(find.byIcon(TablerRegular.chevron_left), findsOneWidget);
      expect(find.byIcon(TablerRegular.x), findsNothing);

      await tester.tap(find.byIcon(TablerRegular.chevron_left));
      await tester.pump();
      expect(backs, 1);
    });

    testWidgets("renders trailing actions", (tester) async {
      await tester.pumpWidget(
        _harness(
          _sheet(
            actions: [PregoButtonsIconGlass(icon: TablerRegular.bell, onPressed: () {})],
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(TablerRegular.bell), findsOneWidget);
    });

    testWidgets("centre alignment centres the title; start alignment leads it", (tester) async {
      // The default test surface is 800pt wide, so mid-screen is x=400.
      await tester.pumpWidget(_harness(_sheet(title: "Centered")));
      await tester.pump();
      expect((tester.getCenter(find.text("Centered")).dx - 400).abs(), lessThan(40));

      await tester.pumpWidget(_harness(_sheet(title: "Leading", alignment: PregoSheetTitleAlignment.start)));
      await tester.pump();
      expect(tester.getCenter(find.text("Leading")).dx, lessThan(300));
    });

    testWidgets("wraps to its content when short", (tester) async {
      await tester.pumpWidget(_harness(_sheet(child: const SizedBox(height: 100))));
      await tester.pump();

      // header (60) + content (100) with no insets — well below the 600pt cap.
      expect(tester.getSize(find.byType(PregoBottomSheet)).height, lessThan(300));
    });

    testWidgets("caps at the screen height and scrolls when tall", (tester) async {
      await tester.pumpWidget(_harness(_sheet(child: const SizedBox(height: 2000))));
      await tester.pump();

      // Capped just below the (zero-height) status bar: the full 600pt surface.
      expect(tester.getSize(find.byType(PregoBottomSheet)).height, closeTo(600, 0.5));

      final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(position.maxScrollExtent, greaterThan(0));
    });

    testWidgets("reserves topInset so a full-height sheet clears the status bar", (tester) async {
      // The modal strips the sheet's own top padding, so the inset is passed in.
      await tester.pumpWidget(
        _harness(const PregoBottomSheet(title: "T", topInset: 50, child: SizedBox(height: 2000))),
      );
      await tester.pump();

      // 600pt surface - 50pt reserved inset = 550pt cap (header stays clear).
      expect(tester.getSize(find.byType(PregoBottomSheet)).height, closeTo(550, 0.5));
    });
  });

  group("showPregoBottomSheet", () {
    testWidgets("opens the sheet and the close button pops it", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => showPregoBottomSheet<void>(
                    context: context,
                    title: "Info",
                    builder: (_) => const Text("Body content"),
                  ),
                  child: const Text("Open"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open"));
      await tester.pumpAndSettle();
      expect(find.text("Info"), findsOneWidget);
      expect(find.text("Body content"), findsOneWidget);

      // The glass close button works with no GlassPage ancestor (modal route).
      await tester.tap(find.byIcon(TablerRegular.x));
      await tester.pumpAndSettle();
      expect(find.text("Info"), findsNothing);
    });
  });
}
