import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Behavioural guards for the skeleton loading primitives.
///
/// The shimmer sweep is an infinite repeating animation, so these tests pump
/// fixed durations and never `pumpAndSettle`.
void main() {
  Widget harness(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: 402, child: child),
            ),
          ),
        ),
      ),
    );
  }

  /// A small two-bar skeleton under one shimmer, standing in for a screen's
  /// loading layout.
  Widget skeleton({bool leaving = false, String? semanticLabel}) => PregoShimmer(
    leaving: leaving,
    semanticLabel: semanticLabel,
    child: const Column(
      spacing: 10,
      children: [
        PregoSkeletonBar(height: 20),
        PregoSkeletonBar(height: 14, width: 99),
      ],
    ),
  );

  /// Pumps past the anti-flash appear delay (300ms) and the fade-in (200ms).
  /// The extra frame lets the fade ticker anchor its start time before the
  /// completing pump.
  Future<void> pumpVisible(WidgetTester tester, Widget child, {bool disableAnimations = false}) async {
    await tester.pumpWidget(harness(child, disableAnimations: disableAnimations));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 250));
  }

  double shimmerOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.descendant(of: find.byType(PregoShimmer), matching: find.byType(FadeTransition)))
      .opacity
      .value;

  group("PregoShimmer", () {
    testWidgets("stays invisible during the appear delay, then fades in and sweeps", (tester) async {
      await tester.pumpWidget(harness(skeleton()));

      // Before the appear delay: laid out but fully transparent, no sweep.
      expect(shimmerOpacity(tester), 0);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(PregoSkeletonBar), findsNWidgets(2));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 200));

      expect(shimmerOpacity(tester), 1);
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

    testWidgets("announces the semantic label and hides the decorative bars", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpVisible(tester, skeleton(semanticLabel: "Loading projects"));

      expect(find.bySemanticsLabel("Loading projects"), findsOneWidget);
      expect(find.byType(ExcludeSemantics), findsWidgets);
      semantics.dispose();
    });

    testWidgets("reduced motion keeps the static bars but never sweeps", (tester) async {
      await pumpVisible(tester, skeleton(), disableAnimations: true);

      expect(find.byType(PregoSkeletonBar), findsNWidgets(2));
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

    testWidgets("leaving before it shows keeps it hidden, with nothing animating", (tester) async {
      await tester.pumpWidget(harness(skeleton()));
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pumpWidget(harness(skeleton(leaving: true)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(shimmerOpacity(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final (name, shownFor) in [("still fading in", 20), ("fully shown", 300)]) {
      testWidgets("leaving while $name fades out from there, never brightening, then stops", (tester) async {
        await tester.pumpWidget(harness(skeleton()));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(Duration(milliseconds: shownFor));
        final start = shimmerOpacity(tester);
        expect(start, greaterThan(0));

        await tester.pumpWidget(harness(skeleton(leaving: true)));
        var last = start;
        for (var elapsed = 0; elapsed < 200; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          final opacity = shimmerOpacity(tester);
          expect(opacity, lessThanOrEqualTo(last));
          last = opacity;
        }
        await tester.pump(const Duration(milliseconds: 10));

        expect(shimmerOpacity(tester), 0);
        // Gone, so the sweep has stopped too.
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets("built leaving never appears", (tester) async {
      await tester.pumpWidget(harness(skeleton(leaving: true)));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(shimmerOpacity(tester), 0);
      expect(tester.hasRunningAnimations, isFalse);
    });

    for (final (name, shownFor) in [("before it showed", 0), ("mid fade-out", 500)]) {
      testWidgets("needed again after leaving $name, it comes back and sweeps", (tester) async {
        await tester.pumpWidget(harness(skeleton()));
        await tester.pump(Duration(milliseconds: shownFor));
        await tester.pumpWidget(harness(skeleton(leaving: true)));
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(harness(skeleton()));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 250));

        expect(shimmerOpacity(tester), 1);
        expect(find.byType(ShaderMask), findsOneWidget);
        expect(tester.hasRunningAnimations, isTrue);
      });
    }

    testWidgets("sweeps under RTL without errors", (tester) async {
      await tester.pumpWidget(
        harness(
          Directionality(
            textDirection: TextDirection.rtl,
            child: skeleton(),
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

  group("PregoNavSubtitleSkeleton", () {
    testWidgets("shimmers one slug-width pill inside the subtitle row's line box", (tester) async {
      await pumpVisible(
        tester,
        // Align loosens the harness's tight width.
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: PregoNavSubtitleSkeleton(),
        ),
      );

      // Self-contained sweep region: the bar slot sits outside any page-body
      // skeleton, so the widget carries its own shimmer.
      expect(
        find.descendant(of: find.byType(PregoNavSubtitleSkeleton), matching: find.byType(ShaderMask)),
        findsOneWidget,
      );
      expect(tester.hasRunningAnimations, isTrue);

      // The block spans the real row's 18px text-xs line box (so the title
      // block keeps its height when data lands), with the 12px pill centred
      // in it rather than stretched to fill it.
      expect(tester.getSize(find.byType(PregoNavSubtitleSkeleton)), const Size(120, 18));
      expect(
        tester.getSize(
          find.descendant(of: find.byType(PregoNavSubtitleSkeleton), matching: find.byType(PregoSkeletonBar)),
        ),
        const Size(120, 12),
      );
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
      final box = container.decoration;
      if (box is! BoxDecoration) fail("Expected a BoxDecoration, got $box");
      final gradient = box.gradient;
      if (gradient is! LinearGradient) fail("Expected a LinearGradient, got $gradient");
      expect(gradient.colors.first, PregoDesignSystem.light.colors.fgQuaternary);
      expect(gradient.colors.last.a, 0.0);
      expect(gradient.begin, AlignmentDirectional.centerStart);
      expect(box.borderRadius, BorderRadius.circular(PregoRadius.full));
      expect(tester.getSize(find.byType(PregoSkeletonBar)), const Size(120, 20));
    });
  });
}
