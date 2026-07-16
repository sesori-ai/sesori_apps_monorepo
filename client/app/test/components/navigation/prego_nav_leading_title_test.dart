import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Rendering guards for [PregoNavLeadingTitle], the left-aligned title block
/// of the top bar's back-leading mode: which subtitle adornments render for
/// which inputs, the status-dot colours, the info popover, and that the
/// two-line block clears the 54pt bar.
void main() {
  Future<void> pumpBlock(
    WidgetTester tester, {
    required String title,
    String? subtitle,
    IconData? subtitleIcon,
    bool? online,
    String? infoMessage,
    String? infoSemanticLabel,
    double? slotHeight,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              // A null height lets the block adopt its own intrinsic height; a
              // fixed [slotHeight] reproduces the bar's constrained slot.
              height: slotHeight,
              child: PregoNavLeadingTitle(
                title: title,
                subtitle: subtitle,
                subtitleIcon: subtitleIcon,
                online: online,
                infoMessage: infoMessage,
                infoSemanticLabel: infoSemanticLabel,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  final dotFinder = find.byWidgetPredicate(
    (widget) =>
        widget is Container &&
        widget.decoration is BoxDecoration &&
        (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
  );

  Color dotColor(WidgetTester tester) {
    final container = tester.widget<Container>(dotFinder);
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets("renders the title with the full subtitle row: dot, icon, text and chevron", (tester) async {
    await pumpBlock(
      tester,
      title: "Sesori_app_monorepo",
      subtitle: "sesori-ai/Sesori_app_mo",
      subtitleIcon: TablerSolid.brand_github,
      online: true,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
      infoSemanticLabel: "Show full repository name",
    );

    expect(find.text("Sesori_app_monorepo"), findsOneWidget);
    expect(find.text("sesori-ai/Sesori_app_mo"), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_down), findsOneWidget);
    expect(dotFinder, findsOneWidget);
  });

  testWidgets("renders the title alone when there is no subtitle", (tester) async {
    await pumpBlock(tester, title: "Just a project", subtitleIcon: TablerSolid.brand_github, online: true);

    expect(find.text("Just a project"), findsOneWidget);
    // The whole row is hidden — dot and icon included — not just the text.
    expect(dotFinder, findsNothing);
    expect(find.byIcon(TablerSolid.brand_github), findsNothing);
  });

  testWidgets("status dot is green when online and muted when offline", (tester) async {
    await pumpBlock(tester, title: "P", subtitle: "org/repo", online: true);
    expect(dotColor(tester), PregoDesignSystem.light.colors.fgSuccessSecondary);

    await pumpBlock(tester, title: "P", subtitle: "org/repo", online: false);
    expect(dotColor(tester), PregoDesignSystem.light.colors.fgDisabledSubtle);
  });

  testWidgets("no status dot when online is null", (tester) async {
    await pumpBlock(tester, title: "P", subtitle: "org/repo", online: null);
    expect(dotFinder, findsNothing);
  });

  testWidgets("no chevron when there is no info message", (tester) async {
    await pumpBlock(tester, title: "P", subtitle: "org/repo");
    expect(find.byIcon(TablerRegular.chevron_down), findsNothing);
  });

  testWidgets("tapping the subtitle row opens a popover with the full message", (tester) async {
    await pumpBlock(
      tester,
      title: "P",
      subtitle: "sesori-ai/Sesori_app_mo",
      infoMessage: "sesori-ai/Sesori_app_monorepo",
      infoSemanticLabel: "Show full repository name",
    );
    expect(find.text("sesori-ai/Sesori_app_monorepo"), findsNothing);

    await tester.tap(find.text("sesori-ai/Sesori_app_mo"));
    await tester.pumpAndSettle();

    expect(find.text("sesori-ai/Sesori_app_monorepo"), findsOneWidget);
  });

  testWidgets("the tappable subtitle row exposes button semantics with the given label", (tester) async {
    await pumpBlock(
      tester,
      title: "P",
      subtitle: "org/repo",
      infoMessage: "org/full-repo",
      infoSemanticLabel: "Show full repository name",
    );

    expect(find.bySemanticsLabel("Show full repository name"), findsOneWidget);
  });

  testWidgets("two-line block fits the 54pt bar without overflowing", (tester) async {
    await pumpBlock(
      tester,
      title: "Sesori_app_monorepo",
      subtitle: "sesori-ai/Sesori_app_monorepo",
      subtitleIcon: TablerSolid.brand_github,
      online: true,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
    );
    // Intrinsic height must clear the bar with margin so platform text-metric
    // differences can't tip it into an overflow.
    expect(tester.getSize(find.byType(PregoNavLeadingTitle)).height, lessThan(50));

    await pumpBlock(
      tester,
      title: "Sesori_app_monorepo",
      subtitle: "sesori-ai/Sesori_app_monorepo",
      subtitleIcon: TablerSolid.brand_github,
      online: true,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
      slotHeight: PregoTopNavigation.barHeight,
    );
    expect(tester.takeException(), isNull);
  });
}
