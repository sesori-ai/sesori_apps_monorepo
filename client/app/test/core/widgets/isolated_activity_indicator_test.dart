import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_mobile/core/widgets/isolated_activity_indicator.dart";

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

  testWidgets("uses the native Android spinner without scheduling Flutter animation", (tester) async {
    usePlatform(TargetPlatform.android);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const IsolatedActivityIndicator(strokeWidth: 2, color: color)),
    );

    expect(
      find.descendant(
        of: find.byType(IsolatedActivityIndicator),
        matching: find.byType(RepaintBoundary),
      ),
      findsOneWidget,
    );
    final platformView = tester.widget<AndroidView>(find.byType(AndroidView));
    expect(platformView.viewType, "sesori/native-activity-indicator");
    expect(platformView.creationParams, color.toARGB32());
    expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    final data = tester.getSemantics(find.byType(IsolatedActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);

    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("uses the native iOS spinner without scheduling Flutter animation", (tester) async {
    usePlatform(TargetPlatform.iOS);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(const IsolatedActivityIndicator(strokeWidth: 2, color: color)),
    );

    final platformView = tester.widget<UiKitView>(find.byType(UiKitView));
    expect(platformView.viewType, "sesori/native-activity-indicator");
    expect(platformView.creationParams, color.toARGB32());
    expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    final data = tester.getSemantics(find.byType(IsolatedActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);

    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("reduced motion uses a static Flutter arc", (tester) async {
    usePlatform(TargetPlatform.android);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(
        const IsolatedActivityIndicator(strokeWidth: 2, color: color),
        reduceMotion: true,
      ),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    final data = tester.getSemantics(find.byType(IsolatedActivityIndicator)).getSemanticsData();
    expect(data.role, SemanticsRole.loadingSpinner);
    expect(data.value, isEmpty);

    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("disabled TickerMode uses a static Flutter arc", (tester) async {
    usePlatform(TargetPlatform.iOS);
    await tester.pumpWidget(
      wrap(
        const TickerMode(
          enabled: false,
          child: IsolatedActivityIndicator(strokeWidth: 2, color: color),
        ),
      ),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNotNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("unshipped targets keep the animated Flutter fallback", (tester) async {
    usePlatform(TargetPlatform.linux);
    await tester.pumpWidget(
      wrap(const IsolatedActivityIndicator(strokeWidth: 2, color: color)),
    );

    expect(
      tester.widget<CircularProgressIndicator>(find.byType(CircularProgressIndicator)).value,
      isNull,
    );
    expect(find.byType(AndroidView), findsNothing);
    expect(find.byType(UiKitView), findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    debugDefaultTargetPlatformOverride = null;
  });
}
