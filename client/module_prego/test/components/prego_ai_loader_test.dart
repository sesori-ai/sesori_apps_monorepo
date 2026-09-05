import "dart:ui" as ui;

import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Behavioural guards for the AI activity sparkle.
///
/// The twinkle is an infinite repeating animation, so these tests pump fixed
/// durations and never `pumpAndSettle` — it would pump to its timeout and throw.
///
/// The painter tests pin a platform without a native twinkle renderer (Linux):
/// on iOS and macOS the animated sparkle is a platform view, which cannot
/// paint pixels in a widget test. The `native twinkle` group covers those
/// branches and the deliberate Android fallback explicitly.
void main() {
  Widget harness(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: disableAnimations),
        child: child!,
      ),
      home: Scaffold(body: Center(child: child)),
    );
  }

  /// The colour actually painted at the middle of the sparkle.
  ///
  /// The keyframes differ in the fill, not just the tint: a solid sparkle has
  /// an opaque brand-coloured body, while the hollow outline keyframe leaves
  /// the middle transparent. Reading the pixel therefore says which keyframe is
  /// on screen — asserting the widget merely "renders" would not.
  Future<Color> sparkleCentre(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(RepaintBoundary)),
    );
    late Color centre;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final at = ((image.height ~/ 2) * image.width + (image.width ~/ 2)) * 4;
      centre = Color.fromARGB(pixels[at + 3], pixels[at], pixels[at + 1], pixels[at + 2]);
      image.dispose();
    });
    return centre;
  }

  /// Number of painted pixels in the sparkle's isolated layer.
  Future<int> sparkleVisiblePixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(RepaintBoundary)),
    );
    late int visiblePixels;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      visiblePixels = 0;
      for (var alpha = 3; alpha < pixels.length; alpha += 4) {
        if (pixels[alpha] > 0) visiblePixels++;
      }
      image.dispose();
    });
    return visiblePixels;
  }

  /// Where in the loop the sparkle is at its hollowest.
  const outlineKeyframe = Duration(milliseconds: 560);

  group("phaseFor", () {
    test("derives a stable phase in [0, 1) from a seed", () {
      final phase = PregoAiLoader.phaseFor("session-42");

      expect(phase, PregoAiLoader.phaseFor("session-42"));
      expect(phase, greaterThanOrEqualTo(0));
      expect(phase, lessThan(1));
    });

    test("staggers different seeds apart", () {
      // Not a hash-quality proof — just a guard that two neighbouring ids
      // don't collapse onto one phase, which is the whole point of the offset.
      expect(PregoAiLoader.phaseFor("session-1"), isNot(PregoAiLoader.phaseFor("session-2")));
    });
  });

  testWidgets("twinkles by default", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("rests on the solid brand sparkle", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("uses an explicit semantic colour for a caller-owned timeline", (tester) async {
    const override = Color(0xFF19A974);
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false, color: override)));
    await tester.pump();

    expect(await sparkleCentre(tester), override);
  });

  testWidgets("keeps the exact sparkle path hollow in outline mode", (tester) async {
    await tester.pumpWidget(
      harness(
        const PregoAiLoader(
          animate: false,
          fillMode: .outline,
          color: Color(0xFF19A974),
        ),
      ),
    );
    await tester.pump();

    expect((await sparkleCentre(tester)).a, 0);
    expect(await sparkleVisiblePixels(tester), greaterThan(0));
  });

  testWidgets("hollows out mid-twinkle", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(outlineKeyframe);

    expect((await sparkleCentre(tester)).a, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("settles back on the solid keyframe when the loop is switched off", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(outlineKeyframe);

    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    // Stopping a controller leaves it wherever it was — a sparkle frozen
    // half-faded would read as a rendering bug.
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("a phase offset moves it through the loop, but never off its resting frame", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.4)));
    await tester.pump();

    // Phase 0.4 starts where an unoffset sparkle would be at its hollowest.
    expect((await sparkleCentre(tester)).a, 0);

    await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.4, animate: false)));
    await tester.pump();

    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("holds still when the platform removes animations", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(), disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("holds still under iOS Reduce Motion, which never reaches MediaQuery", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      reduceMotion: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("picks the loop back up when Reduce Motion is switched off", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      reduceMotion: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);

    tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("is decorative, and isolates its repaints from the surrounding layer", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));

    expect(find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(ExcludeSemantics)), findsOneWidget);
    expect(find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(RepaintBoundary)), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("paints into the requested square", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(size: 24, animate: false)));

    expect(tester.getSize(find.byType(PregoAiLoader)), const Size(24, 24));
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  group("native twinkle", () {
    final expectedParams = <String, Object>{
      "solid": PregoColorsLight.textPrimaryOnBrand.toARGB32(),
      "outline": PregoColorsLight.textPrimary.toARGB32(),
      "faded": PregoColorsLight.textDisabled.toARGB32(),
      "phase": 0.25,
    };

    Finder painter() => find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(CustomPaint));

    testWidgets("animates natively on macOS without scheduling Flutter frames", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.25)));

      final platformView = tester.widget<AppKitView>(find.byType(AppKitView));
      expect(platformView.viewType, "sesori/native-ai-loader");
      expect(platformView.creationParams, expectedParams);
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(painter(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("animates natively on iOS without scheduling Flutter frames", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.25)));

      final platformView = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(platformView.viewType, "sesori/native-ai-loader");
      expect(platformView.creationParams, expectedParams);
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(painter(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("Android keeps the animated Flutter painter in list rows", (tester) async {
      // Deliberate: a platform view per visible session row wrecks Android
      // scroll performance (measured on-device), so Android twinkles in Flutter.
      await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.25)));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppKitView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(painter(), findsOneWidget);
      expect(tester.hasRunningAnimations, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("reduced motion keeps the static painter, not a platform view", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppKitView), findsNothing);
      expect(painter(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("a resting sparkle never creates a platform view", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));

      expect(find.byType(AppKitView), findsNothing);
      expect(painter(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("disabled TickerMode keeps the static painter", (tester) async {
      await tester.pumpWidget(
        harness(const TickerMode(enabled: false, child: PregoAiLoader())),
      );

      expect(find.byType(AppKitView), findsNothing);
      expect(painter(), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("recreates the native view when the phase changes", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.25)));
      final firstKey = tester
          .widget<KeyedSubtree>(
            find.ancestor(of: find.byType(AppKitView), matching: find.byType(KeyedSubtree)).first,
          )
          .key;

      await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.5)));
      final secondKey = tester
          .widget<KeyedSubtree>(
            find.ancestor(of: find.byType(AppKitView), matching: find.byType(KeyedSubtree)).first,
          )
          .key;

      expect(secondKey, isNot(firstKey));
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
