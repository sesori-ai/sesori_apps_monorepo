import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Layout guard for [PregoNavTitle], the centred two-line title block of the
/// glass top bar.
///
/// The bar is a fixed 54pt (`PregoTopNavigation.barHeight`). With the
/// design tokens' body-text line heights, a title + subtitle stack measured
/// 28 + 24 = 52pt — only 2pt under the bar — so Android's slightly taller text
/// metrics tipped the inner [Column] into a 3px bottom overflow on the
/// session-detail screen. The component now tightens both lines to a single-line
/// leading; these tests lock in that the two-line block stays compact enough to
/// clear the bar with margin.
void main() {
  Future<void> pumpTitle(
    WidgetTester tester, {
    required String title,
    String? subtitle,
    double? slotHeight,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              // A null height lets the block adopt its own intrinsic height; a
              // fixed [slotHeight] reproduces the bar's constrained middle slot.
              height: slotHeight,
              child: PregoNavTitle(title: title, subtitle: subtitle),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets("two-line title stays compact enough to clear the 54pt bar", (tester) async {
    await pumpTitle(tester, title: "Session title", subtitle: "feature/some-branch");

    expect(find.text("Session title"), findsOneWidget);
    expect(find.text("feature/some-branch"), findsOneWidget);
    // The body-text leading made this 52pt — only 2pt under the 54pt bar; the
    // tightened leading must keep it well clear so platform metrics can't push
    // the block past the bar.
    expect(tester.getSize(find.byType(PregoNavTitle)).height, lessThan(50));
  });

  testWidgets("renders title + subtitle without overflowing the bar's middle slot", (tester) async {
    // 49pt ≈ the slot height at which the old 52pt block overflowed by 3px on
    // Android (the reported bug). The tightened block must lay out cleanly here.
    await pumpTitle(tester, title: "Session title", subtitle: "feature/some-branch", slotHeight: 49);
    expect(tester.takeException(), isNull);
  });

  testWidgets("renders a title on its own when no subtitle is given", (tester) async {
    await pumpTitle(tester, title: "Just a title", slotHeight: 49);

    expect(tester.takeException(), isNull);
    expect(find.text("Just a title"), findsOneWidget);
  });
}
