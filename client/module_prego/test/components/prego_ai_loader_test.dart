import "dart:ui" as ui;

import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

/// Behavioural guards for the AI activity sparkle.
///
/// The twinkle is an infinite repeating animation, so these tests pump fixed
/// durations and never `pumpAndSettle` — it would pump to its timeout and throw.
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

  /// Where in the loop the sparkle is at its hollowest.
  const outlineKeyframe = Duration(milliseconds: 560);

  testWidgets("twinkles by default", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isTrue);
  });

  testWidgets("rests on the solid brand sparkle", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  });

  testWidgets("hollows out mid-twinkle", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(outlineKeyframe);

    expect((await sparkleCentre(tester)).a, 0);
  });

  testWidgets("settles back on the solid keyframe when the loop is switched off", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(outlineKeyframe);

    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
    // Stopping a controller leaves it wherever it was — a sparkle frozen
    // half-faded would read as a rendering bug.
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  });

  testWidgets("a phase offset moves it through the loop, but never off its resting frame", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.4)));
    await tester.pump();

    // Phase 0.4 starts where an unoffset sparkle would be at its hollowest.
    expect((await sparkleCentre(tester)).a, 0);

    await tester.pumpWidget(harness(const PregoAiLoader(phase: 0.4, animate: false)));
    await tester.pump();

    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  });

  testWidgets("holds still when the platform removes animations", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(), disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
  });

  testWidgets("holds still under iOS Reduce Motion, which never reaches MediaQuery", (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      reduceMotion: true,
    );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
  });

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
  });

  testWidgets("is decorative, and isolates its repaints from the surrounding layer", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));

    expect(find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(ExcludeSemantics)), findsOneWidget);
    expect(find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(RepaintBoundary)), findsOneWidget);
  });

  testWidgets("paints into the requested square", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(size: 24, animate: false)));

    expect(tester.getSize(find.byType(PregoAiLoader)), const Size(24, 24));
  });
}
