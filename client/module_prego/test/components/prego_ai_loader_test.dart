import "dart:ui" as ui;

import "package:clock/clock.dart";
import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

/// Behavioural guards for the AI activity sparkle.
///
/// The rotation has a repeating 25ms timer, so these tests pump fixed
/// durations and never `pumpAndSettle` — the loop would keep it from settling.
///
/// The painter tests pin a platform without a native rotation renderer (Linux):
/// on iOS and macOS the animated sparkle is a platform view, which cannot
/// paint pixels in a widget test. The `native rotation` group covers those
/// branches and the deliberate Android fallback explicitly.
void main() {
  void clockTestWidgets(
    String description,
    WidgetTesterCallback callback, {
    TestVariant<Object?> variant = const DefaultTestVariant(),
  }) {
    testWidgets(
      description,
      (tester) => withClock(Clock(() => tester.binding.clock.now()), () => callback(tester)),
      variant: variant,
    );
  }

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
  /// The states differ in fill, not just tint: an unread sparkle has
  /// an opaque brand-coloured body, while the working outline leaves
  /// the middle transparent. Reading the pixel therefore says which state is
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

  Future<Uint8List> sparklePixels(WidgetTester tester, Finder loader) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.descendant(of: loader, matching: find.byType(RepaintBoundary)),
    );
    late Uint8List pixels;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3);
      pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      image.dispose();
    });
    return pixels;
  }

  /// A non-cardinal rotation, so a jump to the resting angle is visible.
  const loadingSample = Duration(milliseconds: 250);

  clockTestWidgets("steps the synchronized loop at 40 FPS without a repeating ticker", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(CustomPaint)),
        )
        .painter!;
    var repaints = 0;
    void countRepaint() => repaints++;
    painter.addListener(countRepaint);
    addTearDown(() => painter.removeListener(countRepaint));

    // Reach one device-clock boundary, then measure from that known boundary.
    await tester.pump(const Duration(milliseconds: 25));
    repaints = 0;
    await tester.pump(const Duration(milliseconds: 24));
    expect(repaints, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(repaints, 1);
    await tester.pump(const Duration(milliseconds: 225));

    expect(repaints, 10);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  clockTestWidgets("staggered mounts share one synchronized loop phase", (tester) async {
    const first = PregoAiLoader(key: ValueKey("first"));
    await tester.pumpWidget(harness(const Row(mainAxisSize: MainAxisSize.min, children: [first])));
    await tester.pump(const Duration(milliseconds: 137));
    await tester.pumpWidget(
      harness(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            first,
            PregoAiLoader(key: ValueKey("second")),
          ],
        ),
      ),
    );

    final firstPainter = tester
        .widget<CustomPaint>(
          find.descendant(of: find.byKey(const ValueKey("first")), matching: find.byType(CustomPaint)),
        )
        .painter!;
    final secondPainter = tester
        .widget<CustomPaint>(
          find.descendant(of: find.byKey(const ValueKey("second")), matching: find.byType(CustomPaint)),
        )
        .painter!;
    var firstRepaints = 0;
    var secondRepaints = 0;
    void countFirst() => firstRepaints++;
    void countSecond() => secondRepaints++;
    firstPainter.addListener(countFirst);
    secondPainter.addListener(countSecond);
    addTearDown(() {
      firstPainter.removeListener(countFirst);
      secondPainter.removeListener(countSecond);
    });

    await tester.pump(const Duration(milliseconds: 25));
    firstRepaints = 0;
    secondRepaints = 0;
    await tester.pump(const Duration(milliseconds: 100));
    expect((firstRepaints, secondRepaints), (4, 4));

    final firstPixels = await sparklePixels(tester, find.byKey(const ValueKey("first")));
    final secondPixels = await sparklePixels(tester, find.byKey(const ValueKey("second")));
    expect(listEquals(firstPixels, secondPixels), isTrue);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  clockTestWidgets("a restarted sparkle rejoins the synchronized phase after its smooth clear", (tester) async {
    const restartingKey = ValueKey("restarting");
    const synchronizedKey = ValueKey("synchronized");
    await tester.pumpWidget(
      harness(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PregoAiLoader(key: restartingKey, animate: false),
            PregoAiLoader(key: synchronizedKey),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(
      harness(
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PregoAiLoader(key: restartingKey),
            PregoAiLoader(key: synchronizedKey),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 151));

    final restarted = await sparklePixels(tester, find.byKey(restartingKey));
    final synchronized = await sparklePixels(tester, find.byKey(synchronizedKey));
    expect(listEquals(restarted, synchronized), isTrue);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  clockTestWidgets("stops loop scheduling while backgrounded and after disposal", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 30));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(harness(const SizedBox.shrink()));
    await tester.pump();
    await tester.binding.delayed(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isFalse);
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

  testWidgets("keeps the working sparkle hollow through the loop", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(loadingSample);

    expect((await sparkleCentre(tester)).a, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("settles back on the solid keyframe when the loop is switched off", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(loadingSample);

    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();

    expect(tester.hasRunningAnimations, isTrue);
    expect((await sparkleCentre(tester)).a, 0);
    await tester.pump(const Duration(milliseconds: 175));
    final filling = await sparkleCentre(tester);
    expect(filling.a, greaterThan(0));
    expect(filling.a, lessThan(1));
    await tester.pump(const Duration(milliseconds: 526));
    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("holds still when the platform removes animations", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(), disableAnimations: true));
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.hasRunningAnimations, isFalse);
    expect((await sparkleCentre(tester)).a, 0);
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false), disableAnimations: true));
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

    expect(tester.hasRunningAnimations, isFalse);
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

  testWidgets("a new turn interrupts the completion without flashing the fill", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(loadingSample);
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    final beforeRestart = await sparkleCentre(tester);
    final beforeRestartPixels = await sparklePixels(tester, find.byType(PregoAiLoader));

    await tester.pumpWidget(harness(const PregoAiLoader()));
    expect(await sparkleCentre(tester), beforeRestart);
    expect(listEquals(await sparklePixels(tester, find.byType(PregoAiLoader)), beforeRestartPixels), isTrue);
    await tester.pump(const Duration(milliseconds: 75));
    final clearing = await sparkleCentre(tester);
    expect(clearing.a, greaterThan(0));
    expect(clearing.a, lessThan(beforeRestart.a));
    // Finishing again mid-clear must preserve this exact displayed colour.
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    expect(await sparkleCentre(tester), clearing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 701));
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("starting a new turn clears idle without replaying the completion highlight", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 75));
    final clearing = await sparkleCentre(tester);
    expect(clearing.a, greaterThan(0));
    expect(clearing.a, lessThan(1));
    await tester.pump(const Duration(milliseconds: 76));
    expect((await sparkleCentre(tester)).a, 0);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("changing Reduce Motion during completion settles without replay", (tester) async {
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump(loadingSample);
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 175));
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false), disableAnimations: true));
    expect(tester.hasRunningAnimations, isFalse);
    expect(await sparkleCentre(tester), PregoColorsLight.textPrimaryOnBrand);

    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

  testWidgets("sends completion and restart to the same native view without Flutter ticks", (tester) async {
    const channel = MethodChannel("sesori/native-ai-loader/99");
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    await tester.pumpWidget(harness(const PregoAiLoader()));
    final original = tester.state(find.byType(AppKitView));
    tester.widget<AppKitView>(find.byType(AppKitView)).onPlatformViewCreated!(99);
    await tester.pump();
    await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
    await tester.pump();
    await tester.pumpWidget(harness(const PregoAiLoader()));
    await tester.pump();

    expect(tester.state(find.byType(AppKitView)), same(original));
    expect(calls.map((call) => call.method), everyElement("setLoading"));
    expect(calls.map((call) => call.arguments), [true, false, true]);
    expect(tester.hasRunningAnimations, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  group("native rotation", () {
    final expectedParams = <String, Object>{
      "solid": PregoColorsLight.textPrimaryOnBrand.toARGB32(),
      "outline": PregoColorsLight.textPrimary.toARGB32(),
      "loading": true,
    };

    Finder painter() => find.descendant(of: find.byType(PregoAiLoader), matching: find.byType(CustomPaint));

    testWidgets("animates natively on macOS without scheduling Flutter frames", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader()));

      final platformView = tester.widget<AppKitView>(find.byType(AppKitView));
      expect(platformView.viewType, "sesori/native-ai-loader");
      expect(platformView.creationParams, expectedParams);
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(painter(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("animates natively on iOS without scheduling Flutter frames", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader()));

      final platformView = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(platformView.viewType, "sesori/native-ai-loader");
      expect(platformView.creationParams, expectedParams);
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(painter(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets("Android keeps the animated Flutter painter in list rows", (tester) async {
      // Deliberate: a platform view per visible session row wrecks Android
      // scroll performance (measured on-device), so Android rotations in Flutter.
      await tester.pumpWidget(harness(const PregoAiLoader()));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppKitView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(painter(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets("reduced motion keeps the static painter, not a platform view", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(), disableAnimations: true));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(AppKitView), findsNothing);
      expect(painter(), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect((await sparkleCentre(tester)).a, 0);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets("an initially unread sparkle uses a static native view", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));

      final view = tester.widget<AppKitView>(find.byType(AppKitView));
      expect((view.creationParams! as Map)["loading"], isFalse);
      expect(painter(), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
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

    testWidgets("retains the native view through completion", (tester) async {
      await tester.pumpWidget(harness(const PregoAiLoader()));
      final firstKey = tester
          .widget<KeyedSubtree>(
            find.ancestor(of: find.byType(AppKitView), matching: find.byType(KeyedSubtree)).first,
          )
          .key;

      await tester.pumpWidget(harness(const PregoAiLoader(animate: false)));
      final secondKey = tester
          .widget<KeyedSubtree>(
            find.ancestor(of: find.byType(AppKitView), matching: find.byType(KeyedSubtree)).first,
          )
          .key;

      expect(secondKey, firstKey);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  });
}
