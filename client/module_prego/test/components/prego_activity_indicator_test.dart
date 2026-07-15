import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
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

  void usePlatform(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
  }

  testWidgets("uses the Flutter Android spinner without a platform view", (tester) async {
    usePlatform(TargetPlatform.android);
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
    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(PlatformViewLink), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    final data = tester.getSemantics(find.byType(PregoActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);

    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("uses the native iOS spinner without scheduling Flutter animation", (tester) async {
    usePlatform(TargetPlatform.iOS);
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );

    final platformView = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(platformView.viewType, "sesori/native-activity-indicator");
    expect(platformView.creationParams, color.toARGB32());
    expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("uses the Flutter macOS spinner without a platform view", (tester) async {
    usePlatform(TargetPlatform.macOS);
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNull,
    );
    expect(find.byType(AppKitView), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("gives a loosely constrained Flutter spinner a 36 pixel square", (tester) async {
    usePlatform(TargetPlatform.android);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            constraints: BoxConstraints.tightFor(width: 72, height: 72),
          ),
        ),
        home: const Center(
          child: PregoActivityIndicator(color: color),
        ),
      ),
    );

    expect(tester.getSize(find.byType(CircularProgressIndicator)), const Size.square(36));

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("reduced motion uses a static Flutter arc", (tester) async {
    usePlatform(TargetPlatform.android);
    await tester.pumpWidget(
      wrap(
        const PregoActivityIndicator(color: color),
        reduceMotion: true,
      ),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(PlatformViewLink), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("disabled TickerMode uses a static Flutter arc", (tester) async {
    usePlatform(TargetPlatform.macOS);
    await tester.pumpWidget(
      wrap(
        const TickerMode(
          enabled: false,
          child: PregoActivityIndicator(color: color),
        ),
      ),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );
    expect(find.byType(AppKitView), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("unsupported targets keep the animated Flutter fallback", (tester) async {
    usePlatform(TargetPlatform.linux);
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(AppKitView), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    debugDefaultTargetPlatformOverride = null;
  });
}
