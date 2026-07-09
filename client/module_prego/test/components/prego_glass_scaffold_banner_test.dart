import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:theme_prego/module_prego.dart";

const _bannerKey = Key("banner");
const _contentKey = Key("content");
const _bannerHeight = 48.0;

/// A fixed-height stand-in for the inline alert hosted in the banner slot.
Widget _banner() => const SizedBox(
  key: _bannerKey,
  height: _bannerHeight,
  child: Center(child: Text("banner-content")),
);

Widget _harness({
  required Widget? banner,
  bool extendBodyBehindBar = true,
  bool reserveBarSpace = true,
  List<Widget>? extraSlivers,
}) {
  return MaterialApp(
    theme: ThemeData(extensions: [PregoDesignSystem.light]),
    home: PregoGlassScaffold(
      title: "Title",
      inlineTitle: true,
      automaticallyImplyLeading: false,
      banner: banner,
      extendBodyBehindBar: extendBodyBehindBar,
      reserveBarSpace: reserveBarSpace,
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(key: _contentKey, height: 10, width: double.infinity)),
        ...?extraSlivers,
      ],
    ),
  );
}

void main() {
  // The test viewport has no status-bar inset, so the top-bar geometry is:
  // bar row top == banner height, first content top == banner height + 54.

  testWidgets("without a banner the bar sits at the top and content clears it", (tester) async {
    await tester.pumpWidget(_harness(banner: null));
    await tester.pump();

    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, 0);
    expect(tester.getTopLeft(find.byKey(_contentKey)).dy, PregoTopNavigation.barHeight);
  });

  testWidgets("a banner mounted with the scaffold shifts the bar and content down by its height", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner()));
    // Settled geometry needs a second frame: the slot's measured height reaches
    // the inset consumers via a post-frame notification.
    await tester.pump();
    await tester.pump();

    expect(find.text("banner-content"), findsOneWidget);
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, _bannerHeight);
    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      _bannerHeight + PregoTopNavigation.barHeight,
    );
  });

  testWidgets("banner entrance animates the bar down and the content inset follows", (tester) async {
    await tester.pumpWidget(_harness(banner: null));
    await tester.pump();

    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pump(); // start the AnimatedSize transition
    await tester.pump(const Duration(milliseconds: 150));

    final midBarTop = tester.getTopLeft(find.byType(GlassAppBar)).dy;
    expect(midBarTop, greaterThan(0));
    expect(midBarTop, lessThan(_bannerHeight));
    // The measured inset trails the animation by one frame (measure → notify →
    // rebuild). After a zero-duration frame the animation hasn't advanced, so
    // the content must sit exactly one bar height below the mid-animation bar.
    await tester.pump(Duration.zero);
    final midContentTop = tester.getTopLeft(find.byKey(_contentKey)).dy;
    expect(midContentTop, moreOrLessEquals(midBarTop + PregoTopNavigation.barHeight));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, _bannerHeight);
    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      _bannerHeight + PregoTopNavigation.barHeight,
    );
  });

  testWidgets("banner exit keeps the content visible while sliding away, then restores the layout", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_harness(banner: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-exit the retained copy still renders (it is what slides away) …
    expect(find.text("banner-content"), findsOneWidget);
    final midBarTop = tester.getTopLeft(find.byType(GlassAppBar)).dy;
    expect(midBarTop, greaterThan(0));
    expect(midBarTop, lessThan(_bannerHeight));

    // … and once the collapse lands the retained subtree is dropped entirely.
    await tester.pumpAndSettle();
    expect(find.text("banner-content"), findsNothing);
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, 0);
    expect(tester.getTopLeft(find.byKey(_contentKey)).dy, PregoTopNavigation.barHeight);
  });

  testWidgets("PregoTopBarInsetBuilder tracks the banner height inside the scaffold", (tester) async {
    final capturedInsets = <double>[];
    final probe = SliverToBoxAdapter(
      child: PregoTopBarInsetBuilder(
        builder: (context, topInset, _) {
          capturedInsets.add(topInset);
          return const SizedBox(height: 1, width: double.infinity);
        },
      ),
    );

    await tester.pumpWidget(_harness(banner: _banner(), extraSlivers: [probe]));
    await tester.pumpAndSettle();
    expect(capturedInsets.last, PregoTopNavigation.barHeight + _bannerHeight);

    await tester.pumpWidget(_harness(banner: null, extraSlivers: [probe]));
    await tester.pumpAndSettle();
    expect(capturedInsets.last, PregoTopNavigation.barHeight);
  });

  testWidgets("PregoTopBarInsetBuilder falls back to the static bar inset without a scaffold", (tester) async {
    double? capturedInset;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: PregoTopBarInsetBuilder(
          builder: (context, topInset, _) {
            capturedInset = topInset;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(capturedInset, PregoTopNavigation.barHeight);
  });

  testWidgets("extendBodyBehindBar: false insets the body below the banner and bar", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner(), extendBodyBehindBar: false));
    await tester.pump();
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      _bannerHeight + PregoTopNavigation.barHeight,
    );
  });

  testWidgets("with a status-bar inset the banner sits below it and the bar row keeps its 54px height", (tester) async {
    // 60 physical px at DPR 3.0 = a 20-logical-px status bar.
    tester.view.padding = const FakeViewPadding(left: 0, top: 60, right: 0, bottom: 0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const topPad = 20.0;

    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pump();
    await tester.pump();

    // Banner below the status bar, bar row below the banner.
    expect(tester.getTopLeft(find.byKey(_bannerKey)).dy, topPad);
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, topPad + _bannerHeight);
    // The slot's leading SizedBox owns the status-bar inset, so GlassAppBar's
    // internal SafeArea must contribute 0 top — if MediaQuery.removePadding
    // were dropped, the bar would re-apply the inset and grow by topPad.
    expect(tester.getSize(find.byType(GlassAppBar)).height, PregoTopNavigation.barHeight);
    expect(
      tester.getTopLeft(find.byKey(_contentKey)).dy,
      topPad + _bannerHeight + PregoTopNavigation.barHeight,
    );
  });

  testWidgets("horizontal safe-area insets keep the banner clear of landscape cutouts", (tester) async {
    // 132 physical px at DPR 3.0 = a 44-logical-px side inset, as on a Face ID
    // iPhone in landscape. The floating banner this slot replaced sat in a
    // SafeArea, so the inline slot must keep the card out of the cutout region.
    tester.view.padding = const FakeViewPadding(left: 132, top: 0, right: 132, bottom: 0);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const sideInset = 44.0;
    final logicalWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;

    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pump();
    await tester.pump();

    expect(tester.getTopLeft(find.byKey(_bannerKey)).dx, sideInset);
    expect(tester.getTopRight(find.byKey(_bannerKey)).dx, logicalWidth - sideInset);
    // The inset is horizontal only — the vertical geometry is untouched.
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, _bannerHeight);
  });

  testWidgets("the bar's removePadding sits under its own leaf Builder", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pump();

    // MediaQuery.removePadding reads MediaQuery.of, which registers an
    // aspect-less "depend on everything" MediaQuery dependency on the element
    // that builds it. Hosted directly in the scaffold's build, that would
    // rebuild the entire scaffold on every keyboard viewInsets tick; the
    // Builder keeps the dependency on a leaf element instead. Geometry cannot
    // detect the difference, hence this structural guard.
    final barMediaQuery = find.ancestor(of: find.byType(GlassAppBar), matching: find.byType(MediaQuery)).first;
    Element? parent;
    tester.element(barMediaQuery).visitAncestorElements((element) {
      parent = element;
      return false;
    });
    expect(parent?.widget, isA<Builder>());
  });

  testWidgets("the scroll-edge gradient spans the banner and the bar", (tester) async {
    final gradientFinder = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration?)?.gradient is LinearGradient,
    );

    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pumpAndSettle();
    expect(
      tester.getSize(gradientFinder).height,
      PregoTopNavigation.barHeight + _bannerHeight,
    );

    await tester.pumpWidget(_harness(banner: null));
    await tester.pumpAndSettle();
    expect(tester.getSize(gradientFinder).height, PregoTopNavigation.barHeight);
  });

  testWidgets("the banner slot clips through a ClipRect around its AnimatedSize", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner()));
    await tester.pump();

    // RenderAnimatedSize only clips while its animated size is smaller than
    // the child's target size, so the exit collapse (target zero, retained
    // content overflowing upward) relies on this ClipRect being AnimatedSize's
    // direct parent — without it the departing banner paints over the status
    // bar. Layout geometry cannot detect a missing clip, hence this structural
    // guard.
    final animatedSize = find.ancestor(of: find.byKey(_bannerKey), matching: find.byType(AnimatedSize)).first;
    Element? parent;
    tester.element(animatedSize).visitAncestorElements((element) {
      parent = element;
      return false;
    });
    expect(parent?.widget, isA<ClipRect>());
  });

  testWidgets("the departing banner copy is inert: not tappable and excluded from semantics", (tester) async {
    var taps = 0;
    Widget tappableBanner() => SizedBox(
      key: _bannerKey,
      height: _bannerHeight,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++),
    );

    await tester.pumpWidget(_harness(banner: tappableBanner()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_bannerKey));
    expect(taps, 1);

    await tester.pumpWidget(_harness(banner: null));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-exit the retained copy still paints in the collapsing slot, but a
    // tap inside its visible slice must fall through.
    final slotHeight = tester.getSize(find.ancestor(of: find.byKey(_bannerKey), matching: find.byType(ClipRect)).first).height;
    expect(slotHeight, greaterThan(0));
    await tester.tapAt(Offset(tester.getSize(find.byType(GlassAppBar)).width / 2, slotHeight / 2));
    expect(taps, 1);

    final excludeSemantics = tester.widget<ExcludeSemantics>(
      find.ancestor(of: find.byKey(_bannerKey), matching: find.byType(ExcludeSemantics)).first,
    );
    expect(excludeSemantics.excluding, isTrue);
  });

  testWidgets("reserveBarSpace: false leaves the body inset to the content", (tester) async {
    await tester.pumpWidget(_harness(banner: _banner(), reserveBarSpace: false));
    await tester.pump();
    await tester.pump();

    // No auto spacer: the first sliver fills from the very top, behind the
    // banner and bar (self-inset is the body's job via PregoTopBarInsetBuilder).
    expect(tester.getTopLeft(find.byKey(_contentKey)).dy, 0);
    expect(tester.getTopLeft(find.byType(GlassAppBar)).dy, _bannerHeight);
  });
}
