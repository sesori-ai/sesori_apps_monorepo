import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Rendering guards for [PregoNavLeadingTitle] composed with its canonical
/// subtitle content, [PregoNavSubtitle] — the pairing the top bar's
/// back-leading mode renders: which subtitle adornments render for which
/// inputs, the status-dot colours, the info popover, and that the two-line
/// block clears the 54pt bar.
void main() {
  Future<void> pumpBlock(
    WidgetTester tester, {
    required String title,
    String? subtitle,
    IconData? icon,
    PregoNavStatus? status,
    String? infoMessage,
    String? infoSemanticLabel,
    double? slotHeight,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child ?? const SizedBox.shrink(),
        ),
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
                subtitle: subtitle == null
                    ? null
                    : PregoNavSubtitle(
                        text: subtitle,
                        icon: icon,
                        status: status,
                        infoMessage: infoMessage,
                        infoSemanticLabel: infoSemanticLabel,
                      ),
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
      icon: TablerSolid.brand_github,
      status: PregoNavStatus.online,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
      infoSemanticLabel: "Show full repository name",
    );

    expect(find.text("Sesori_app_monorepo"), findsOneWidget);
    expect(find.text("sesori-ai/Sesori_app_mo"), findsOneWidget);
    expect(find.byIcon(TablerSolid.brand_github), findsOneWidget);
    expect(find.byIcon(TablerRegular.chevron_down), findsOneWidget);
    expect(dotFinder, findsOneWidget);
  });

  testWidgets("renders the title alone when there is no subtitle widget", (tester) async {
    await pumpBlock(tester, title: "Just a project", icon: TablerSolid.brand_github, status: PregoNavStatus.online);

    expect(find.text("Just a project"), findsOneWidget);
    // Nothing of the row renders — the block has no second line at all.
    expect(dotFinder, findsNothing);
    expect(find.byIcon(TablerSolid.brand_github), findsNothing);
    expect(find.byType(PregoNavSubtitle), findsNothing);
  });

  testWidgets("status dot colour follows the reported status", (tester) async {
    await pumpBlock(tester, title: "P", subtitle: "org/repo", status: PregoNavStatus.online);
    expect(dotColor(tester), PregoDesignSystem.light.colors.fgSuccessSecondary);

    await pumpBlock(tester, title: "P", subtitle: "org/repo", status: PregoNavStatus.offline);
    expect(dotColor(tester), PregoDesignSystem.light.colors.fgDisabledSubtle);

    // The bridge onboarding's waiting state, where not being connected is what
    // the page is about.
    await pumpBlock(tester, title: "P", subtitle: "org/repo", status: PregoNavStatus.error);
    expect(dotColor(tester), PregoDesignSystem.light.colors.fgErrorPrimary);
  });

  testWidgets("no status dot when the status is null", (tester) async {
    await pumpBlock(tester, title: "P", subtitle: "org/repo");
    expect(dotFinder, findsNothing);
  });

  testWidgets("the title is 18 bold primary and the subtitle 12 tertiary", (tester) async {
    await pumpBlock(tester, title: "Projects", subtitle: "Waiting for the bridge...");
    final colors = PregoDesignSystem.light.colors;

    final title = tester.widget<Text>(find.text("Projects")).style!;
    expect(title.fontSize, 18);
    expect(title.fontWeight, FontWeight.bold);
    expect(title.color, colors.textPrimary);

    final subtitle = tester.widget<Text>(find.text("Waiting for the bridge...")).style!;
    expect(subtitle.fontSize, 12);
    expect(subtitle.color, colors.textTertiary);
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
      icon: TablerSolid.brand_github,
      status: PregoNavStatus.online,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
    );
    // Intrinsic height must clear the bar with margin so platform text-metric
    // differences can't tip it into an overflow.
    expect(tester.getSize(find.byType(PregoNavLeadingTitle)).height, lessThan(50));

    await pumpBlock(
      tester,
      title: "Sesori_app_monorepo",
      subtitle: "sesori-ai/Sesori_app_monorepo",
      icon: TablerSolid.brand_github,
      status: PregoNavStatus.online,
      infoMessage: "sesori-ai/Sesori_app_monorepo",
      slotHeight: PregoTopNavigation.barHeight,
    );
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.3, 2.5]) {
    testWidgets("fits the 54pt bar at ${textScale}x text, with and without a subtitle", (tester) async {
      await pumpBlock(
        tester,
        title: "Sesori_app_monorepo",
        slotHeight: PregoTopNavigation.barHeight,
        textScale: textScale,
      );
      expect(tester.takeException(), isNull);

      await pumpBlock(
        tester,
        title: "Sesori_app_monorepo",
        subtitle: "sesori-ai/Sesori_app_monorepo",
        icon: TablerSolid.brand_github,
        status: PregoNavStatus.online,
        slotHeight: PregoTopNavigation.barHeight,
        textScale: textScale,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(Column).first).height, lessThanOrEqualTo(PregoTopNavigation.barHeight));
    });
  }
}
