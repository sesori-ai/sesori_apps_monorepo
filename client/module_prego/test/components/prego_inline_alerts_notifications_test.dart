import "dart:ui" as ui;

import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  Widget harness({
    PregoDesignSystem? designSystem,
    bool disableAnimations = false,
    VoidCallback? onClose,
    String title = "Scanning all harnesses",
    String supportingText = "Starting…",
  }) {
    final system = designSystem ?? PregoDesignSystem.dark;
    return MaterialApp(
      theme: ThemeData(
        colorScheme: system.colors.toFlutterColorScheme(),
        textTheme: system.textTheme.asFlutterTextTheme(),
        fontFamily: PregoTextTheme.fontFamily,
        fontFamilyFallback: PregoTextTheme.fontFamilyFallback,
        extensions: [system],
      ),
      home: Scaffold(
        body: MediaQuery(
          data: const MediaQueryData(size: Size(402, 874)).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: SizedBox(
            width: 402,
            child: RepaintBoundary(
              key: const ValueKey("loading-alert-boundary"),
              child: PregoInlineAlertsNotifications(
                type: PregoInlineAlertsNotificationsType.loading,
                title: title,
                supportingText: supportingText,
                onClose: onClose,
                closeSemanticLabel: "Cancel scan",
              ),
            ),
          ),
        ),
      ),
    );
  }

  RotationTransition loader(WidgetTester tester) => tester.widget<RotationTransition>(
    find.byKey(const ValueKey("prego-deep-scan-loader")),
  );

  Transform beam(WidgetTester tester) => tester.widget<Transform>(
    find.byKey(const ValueKey("prego-deep-scan-beam")),
  );

  double beamX(WidgetTester tester) => beam(tester).transform.getTranslation().x;

  Future<Color> renderedPixel(WidgetTester tester, Offset logicalOffset) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey("loading-alert-boundary")),
    );
    late Color pixel;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      final x = (logicalOffset.dx * 3).round();
      final y = (logicalOffset.dy * 3).round();
      final at = (y * image.width + x) * 4;
      pixel = Color.fromARGB(data[at + 3], data[at], data[at + 1], data[at + 2]);
      image.dispose();
    });
    return pixel;
  }

  testWidgets("matches the 402 by 101 Figma frame and token-sized marks", (tester) async {
    await tester.pumpWidget(harness(onClose: () {}));
    await tester.pump();

    expect(
      tester.getSize(find.byType(PregoInlineAlertsNotifications)),
      const Size(402, 101),
    );
    expect(tester.getSize(find.byType(PregoAiLoader)), const Size.square(20));
    expect(
      tester.getSize(find.byKey(const ValueKey("prego-deep-scan-panel"))),
      const Size(142, 104),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey("prego-deep-scan-panel"))),
      const Offset(223, 2),
    );
    expect(
      tester.widget<PregoAiLoader>(find.byType(PregoAiLoader)).fillMode,
      PregoAiLoaderFillMode.outline,
    );
    expect(tester.getSize(find.bySemanticsLabel("Cancel scan")), const Size.square(36));

    final card = tester.widget<Container>(
      find.byKey(const ValueKey("prego-deep-scan-card")),
    );
    final decoration = card.decoration! as ShapeDecoration;
    final outline = card.foregroundDecoration! as ShapeDecoration;
    expect(card.clipBehavior, Clip.antiAlias);
    expect(decoration.color, PregoColorsDark.bgSurface5);
    expect(decoration.shape, isA<RoundedRectangleBorder>());
    expect(
      (decoration.shape as RoundedRectangleBorder).borderRadius,
      const BorderRadius.all(Radius.circular(PregoRadius.x4l)),
    );
    expect((outline.shape as RoundedRectangleBorder).side.color, PregoColorsDark.borderPrimary);
  });

  testWidgets("keeps the skeleton rows and scan beam visible in the light theme", (tester) async {
    await tester.pumpWidget(
      harness(
        designSystem: PregoDesignSystem.light,
        onClose: () {},
      ),
    );
    await tester.pump();

    // This point crosses the second row's left inset border. Figma's light
    // surface fill is white, so its tokenized border/shadows—not a gray
    // substitute fill—must keep the row distinguishable from the card.
    final skeleton = await renderedPixel(tester, const Offset(270, 35));
    expect(skeleton.r, lessThan(250 / 255));
    expect(skeleton.g, lessThan(250 / 255));
    expect(skeleton.b, lessThan(250 / 255));

    await tester.pump(const Duration(milliseconds: 1250));
    // At 1.25 seconds the beam crosses this column. The updated light graphic
    // uses Blue/400 rather than the dark theme's white beam.
    final beam = await renderedPixel(tester, const Offset(302, 60));
    expect(beam.b, greaterThan(beam.g));
    expect(beam.g, greaterThan(beam.r));
    expect(beam.r, lessThan(0.9));
  });

  testWidgets("truncates long scan labels on both text rows without overflow", (tester) async {
    const longTitle = "Scanning all harnesses connected to this unusually descriptive workspace";
    const longDetail = "An extremely long plugin display name that must stay within one row — 12,345 sessions";
    await tester.pumpWidget(
      harness(
        onClose: () {},
        title: longTitle,
        supportingText: longDetail,
      ),
    );
    await tester.pump();

    for (final label in [longTitle, longDetail]) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets("repeats the two Figma motions on one exact ten-second timeline", (tester) async {
    await tester.pumpWidget(harness(onClose: () {}));
    await tester.pump();

    expect(loader(tester).turns.value, 0);
    expect(beamX(tester), -18);

    await tester.pump(const Duration(milliseconds: 1250));
    expect(loader(tester).turns.value, closeTo(0.625, 0.0001));
    expect(beamX(tester), closeTo(55.0905, 0.001));

    await tester.pump(const Duration(milliseconds: 1250));
    expect(loader(tester).turns.value, closeTo(1.25, 0.0001));
    expect(beamX(tester), closeTo(128.181, 0.001));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(loader(tester).turns.value, closeTo(2, 0.0001));
    expect(beamX(tester), closeTo(128.181, 0.001));

    await tester.pump(const Duration(seconds: 2));
    expect(loader(tester).turns.value, closeTo(3, 0.0001));
    expect(beamX(tester), closeTo(128.181, 0.001));

    await tester.pump(const Duration(seconds: 4));
    expect(loader(tester).turns.value, closeTo(0, 0.0001));
    expect(beamX(tester), closeTo(-18, 0.001));

    await tester.pump(const Duration(milliseconds: 1250));
    expect(loader(tester).turns.value, closeTo(0.625, 0.0001));
    expect(beamX(tester), closeTo(55.0905, 0.001));
  });

  testWidgets("rests on Figma's first frame when the platform reduces motion", (tester) async {
    await tester.pumpWidget(harness(disableAnimations: true, onClose: () {}));
    await tester.pump(const Duration(seconds: 2));

    expect(tester.hasRunningAnimations, isFalse);
    expect(loader(tester).turns.value, 0);
    expect(beamX(tester), -18);
  });

  testWidgets("exposes and invokes the localized icon-only cancel action", (tester) async {
    var closeCount = 0;
    await tester.pumpWidget(harness(onClose: () => closeCount++));
    await tester.pump();

    expect(find.text("Cancel scan"), findsNothing);
    await tester.tap(find.bySemanticsLabel("Cancel scan"));
    expect(closeCount, 1);
  });

  testWidgets(
    "uses 24px circular Android and continuous iOS corners",
    (tester) async {
      await tester.pumpWidget(harness(onClose: () {}));
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text("Scanning all harnesses"), findsOneWidget);
      expect(find.text("Starting…"), findsOneWidget);
      expect(find.byType(PregoAiLoader), findsOneWidget);
      expect(find.bySemanticsLabel("Cancel scan"), findsOneWidget);
      final card = tester.widget<Container>(
        find.byKey(const ValueKey("prego-deep-scan-card")),
      );
      final decoration = card.decoration! as ShapeDecoration;
      final outline = card.foregroundDecoration! as ShapeDecoration;
      final platform = Theme.of(tester.element(find.byKey(const ValueKey("prego-deep-scan-card")))).platform;
      final radius = switch (decoration.shape) {
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        final shape => throw TestFailure("Unexpected Deep Scan shape: $shape"),
      };

      expect(card.clipBehavior, Clip.antiAlias);
      expect(radius, const BorderRadius.all(Radius.circular(PregoRadius.x4l)));
      expect(
        decoration.shape,
        platform == TargetPlatform.iOS ? isA<RoundedSuperellipseBorder>() : isA<RoundedRectangleBorder>(),
      );
      expect(outline.shape.runtimeType, decoration.shape.runtimeType);
      expect((outline.shape as OutlinedBorder).side.color, PregoColorsDark.borderPrimary);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
  );
}
