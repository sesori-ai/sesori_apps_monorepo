import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  const color = Color(0xFF123456);

  Widget wrap(Widget child, {bool reduceMotion = false}) {
    return MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: MaterialApp(
        home: Center(
          child: SizedBox.square(dimension: 20, child: child),
        ),
      ),
    );
  }

  // The override must be cleared inside the test body: the binding verifies
  // foundation debug variables before tearDown callbacks run.
  Future<void> onPlatform(TargetPlatform platform, Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  // MaterialApp leaves follow-up frames scheduled after its first pump; flush
  // them (without elapsing fake time, so no timer step fires) before judging
  // what the spinner itself schedules.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5 && tester.binding.hasScheduledFrame; i++) {
      await tester.pump();
    }
  }

  testWidgets("Android uses the stepped Flutter spinner, deliberately", (tester) async {
    // A hybrid-composition platform view idles Flutter on a static screen but
    // wrecks scroll performance (measured on-device), so Android never gets a
    // native spinner branch; it gets the timer-stepped Cupertino derivative.
    await onPlatform(TargetPlatform.android, () async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      expect(
        find.descendant(
          of: find.byType(PregoActivityIndicator),
          matching: find.byType(RepaintBoundary),
        ),
        findsOneWidget,
      );
      expect(find.byType(PlatformViewLink), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<PregoSteppedActivityIndicator>(find.byType(PregoSteppedActivityIndicator)).animating,
        isTrue,
      );

      final data = tester.getSemantics(find.byType(PregoActivityIndicator)).getSemanticsData();
      expect(data.role, SemanticsRole.loadingSpinner);

      handle.dispose();
    });
  });

  testWidgets("the stepped spinner repaints once per step and schedules nothing in between", (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      // No ticker: a Flutter animation would register a transient frame callback
      // and keep a frame scheduled at every vsync.
      await settle(tester);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);

      await tester.binding.delayed(const Duration(milliseconds: 110));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: "no frame before the first step");

      await tester.binding.delayed(const Duration(milliseconds: 20));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: "the step marks the painter dirty");

      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.binding.delayed(const Duration(milliseconds: 110));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: "one repaint per step, none between");
    });
  });

  testWidgets("the stepped spinner pauses in the background and resumes in the foreground", (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await settle(tester);
      await tester.binding.delayed(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse, reason: "a background app must not keep stepping");

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await settle(tester);
      await tester.binding.delayed(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue, reason: "stepping resumes with the app");
    });
  });

  testWidgets("uses the native iOS spinner without scheduling Flutter animation", (tester) async {
    await onPlatform(TargetPlatform.iOS, () async {
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      final platformView = tester.widget<UiKitView>(find.byType(UiKitView));
      expect(platformView.viewType, "sesori/native-activity-indicator");
      expect(platformView.creationParams, color.toARGB32());
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(find.byType(PregoSteppedActivityIndicator), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets("uses the native macOS spinner without scheduling Flutter animation", (tester) async {
    await onPlatform(TargetPlatform.macOS, () async {
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      final platformView = tester.widget<AppKitView>(find.byType(AppKitView));
      expect(platformView.viewType, "sesori/native-activity-indicator");
      expect(platformView.creationParams, color.toARGB32());
      expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
      expect(find.byType(PregoSteppedActivityIndicator), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  testWidgets("recreates the native view when the colour changes", (tester) async {
    await onPlatform(TargetPlatform.iOS, () async {
      const other = Color(0xFF654321);
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );
      expect(find.byKey(ValueKey(color.toARGB32())), findsOneWidget);

      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: other)),
      );
      expect(find.byKey(ValueKey(color.toARGB32())), findsNothing);
      expect(find.byKey(ValueKey(other.toARGB32())), findsOneWidget);
      expect(
        tester.widget<UiKitView>(find.byType(UiKitView)).creationParams,
        other.toARGB32(),
      );
    });
  });

  testWidgets("gives a loosely constrained Flutter spinner a 36 pixel square", (tester) async {
    await onPlatform(TargetPlatform.linux, () async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PregoActivityIndicator(color: color),
          ),
        ),
      );

      expect(tester.getSize(find.byType(PregoSteppedActivityIndicator)), const Size.square(36));
    });
  });

  testWidgets("reduced motion shows a static stepped frame", (tester) async {
    await onPlatform(TargetPlatform.android, () async {
      await tester.pumpWidget(
        wrap(
          const PregoActivityIndicator(color: color),
          reduceMotion: true,
        ),
      );

      expect(
        tester.widget<PregoSteppedActivityIndicator>(find.byType(PregoSteppedActivityIndicator)).animating,
        isFalse,
      );
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(PlatformViewLink), findsNothing);
      await settle(tester);
      await tester.binding.delayed(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets("disabled TickerMode shows a static stepped frame", (tester) async {
    await onPlatform(TargetPlatform.macOS, () async {
      await tester.pumpWidget(
        wrap(
          const TickerMode(
            enabled: false,
            child: PregoActivityIndicator(color: color),
          ),
        ),
      );

      expect(
        tester.widget<PregoSteppedActivityIndicator>(find.byType(PregoSteppedActivityIndicator)).animating,
        isFalse,
      );
      expect(find.byType(AppKitView), findsNothing);
      await settle(tester);
      await tester.binding.delayed(const Duration(seconds: 1));
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  testWidgets("unsupported targets use the stepped Flutter spinner", (tester) async {
    await onPlatform(TargetPlatform.linux, () async {
      await tester.pumpWidget(
        wrap(const PregoActivityIndicator(color: color)),
      );

      expect(
        tester.widget<PregoSteppedActivityIndicator>(find.byType(PregoSteppedActivityIndicator)).animating,
        isTrue,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AndroidView), findsNothing);
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(AppKitView), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
