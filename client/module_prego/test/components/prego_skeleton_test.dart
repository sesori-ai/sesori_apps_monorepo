import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Behavioural guards for the skeleton loading primitives.
///
/// The shimmer sweep is an infinite repeating animation, so these tests pump
/// fixed durations and never `pumpAndSettle`.
void main() {
  Widget harness(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 402, child: child),
        ),
      ),
    );
  }

  /// Pumps past the anti-flash appear delay (300ms) and the fade-in (200ms).
  /// The extra frame lets the fade ticker anchor its start time before the
  /// completing pump.
  Future<void> pumpVisible(WidgetTester tester, Widget child, {bool disableAnimations = false}) async {
    await tester.pumpWidget(harness(child, disableAnimations: disableAnimations));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Finder titleBars() => find.byWidgetPredicate((w) => w is PregoSkeletonBar && w.height == 20);
  Finder detailBars() => find.byWidgetPredicate((w) => w is PregoSkeletonBar && w.height == 14);

  group("PregoSkeletonList", () {
    testWidgets("renders six two-line rows with the designed width rhythm", (tester) async {
      await pumpVisible(tester, const PregoSkeletonList());

      expect(find.byType(PregoSkeletonListTile), findsNWidgets(6));
      expect(titleBars(), findsNWidgets(6));
      expect(detailBars(), findsNWidgets(6));

      // Content width: 402 - 2*16 (list padding) - 2*12 (row padding) = 346.
      const contentWidth = 402.0 - 32.0 - 24.0;
      const fractions = [0.74, 0.51, 0.51, 0.83, 1.0, 0.51];
      final widths = titleBars()
          .evaluate()
          .map((e) => (e.renderObject! as RenderBox).size.width)
          .toList();
      for (var i = 0; i < fractions.length; i++) {
        expect(widths[i], moreOrLessEquals(fractions[i] * contentWidth, epsilon: 1.0));
      }

      // Detail bars are fixed-size 99x14 pills.
      for (final element in detailBars().evaluate()) {
        expect((element.renderObject! as RenderBox).size, const Size(99, 14));
      }
    });

    testWidgets("the width pattern cycles past six rows", (tester) async {
      // Scrollable: eight rows are taller than the test viewport.
      await pumpVisible(tester, const SingleChildScrollView(child: PregoSkeletonList(itemCount: 8)));

      expect(find.byType(PregoSkeletonListTile), findsNWidgets(8));
      final widths = titleBars()
          .evaluate()
          .map((e) => (e.renderObject! as RenderBox).size.width)
          .toList();
      expect(widths[6], moreOrLessEquals(widths[0], epsilon: 0.1));
      expect(widths[7], moreOrLessEquals(widths[1], epsilon: 0.1));
    });

    testWidgets("announces the semantic label and hides the decorative rows", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpVisible(tester, const PregoSkeletonList(semanticLabel: "Loading projects"));

      expect(find.bySemanticsLabel("Loading projects"), findsOneWidget);
      expect(find.byType(ExcludeSemantics), findsWidgets);
      semantics.dispose();
    });
  });

  group("PregoShimmer", () {
    testWidgets("stays invisible during the appear delay, then fades in and sweeps", (tester) async {
      await tester.pumpWidget(harness(const PregoSkeletonList()));

      // Before the appear delay: laid out but fully transparent, no sweep.
      final opacityFinder = find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == 0.0);
      expect(opacityFinder, findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(PregoSkeletonListTile), findsNWidgets(6));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byWidgetPredicate((w) => w is AnimatedOpacity && w.opacity == 1.0),
        findsOneWidget,
      );
      // One mask for the whole region, and the sweep is running.
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets("shows immediately when the appear delay is zero", (tester) async {
      await tester.pumpWidget(
        harness(
          const PregoShimmer(
            appearDelay: Duration.zero,
            child: PregoSkeletonBar(height: 20, width: 100),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });

    testWidgets("reduced motion keeps the static bars but never sweeps", (tester) async {
      await pumpVisible(tester, const PregoSkeletonList(), disableAnimations: true);

      expect(find.byType(PregoSkeletonListTile), findsNWidgets(6));
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets("enabled: false renders the bars without a sweep", (tester) async {
      await pumpVisible(
        tester,
        const PregoShimmer(
          enabled: false,
          appearDelay: Duration.zero,
          child: PregoSkeletonBar(height: 20, width: 100),
        ),
      );

      expect(find.byType(PregoSkeletonBar), findsOneWidget);
      expect(find.byType(ShaderMask), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets("sweeps under RTL without errors", (tester) async {
      await tester.pumpWidget(
        harness(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: PregoSkeletonList(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));
      // A few sweep frames must paint cleanly with the mirrored gradient.
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(ShaderMask), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group("PregoSkeletonBar", () {
    testWidgets("paints a fully rounded pill fading from the quaternary foreground", (tester) async {
      await pumpVisible(
        tester,
        const PregoShimmer(
          appearDelay: Duration.zero,
          // Align loosens the harness's tight width, as list rows do.
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: PregoSkeletonBar(height: 20, width: 120),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(of: find.byType(PregoSkeletonBar), matching: find.byType(Container)),
      );
      final box = container.decoration! as BoxDecoration;
      final gradient = box.gradient! as LinearGradient;
      expect(gradient.colors.first, PregoDesignSystem.light.colors.fgQuaternary);
      expect(gradient.colors.last.a, 0.0);
      expect(gradient.begin, AlignmentDirectional.centerStart);
      expect(box.borderRadius, BorderRadius.circular(PregoRadius.full));
      expect(tester.getSize(find.byType(PregoSkeletonBar)), const Size(120, 20));
    });
  });
}
