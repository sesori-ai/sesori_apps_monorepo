import "package:flutter/foundation.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
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

  void usePlatform(TargetPlatform platform) {
    debugDefaultTargetPlatformOverride = platform;
  }

  testWidgets("uses the native Android spinner without scheduling Flutter animation", (tester) async {
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
    expect(find.byType(PlatformViewLink), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

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

  testWidgets("uses the native macOS spinner without scheduling Flutter animation", (tester) async {
    usePlatform(TargetPlatform.macOS);
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );

    final platformView = tester.widget<AppKitView>(find.byType(AppKitView));
    expect(platformView.viewType, "sesori/native-activity-indicator");
    expect(platformView.creationParams, color.toARGB32());
    expect(platformView.hitTestBehavior, PlatformViewHitTestBehavior.transparent);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("creates the Android platform view with the requested colour", (tester) async {
    usePlatform(TargetPlatform.android);
    final creates = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async {
        if (call.method == "create") creates.add(call);
        return null;
      },
    );
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );
    await tester.pump();

    expect(creates, hasLength(1));
    final arguments = creates.single.arguments;
    if (arguments is! Map) {
      fail("create arguments were not a map: $arguments");
    }
    expect(arguments["viewType"], "sesori/native-activity-indicator");
    expect(arguments["hybrid"], isTrue);
    final params = arguments["params"];
    if (params is! Uint8List) {
      fail("creation params were not encoded bytes: $params");
    }
    expect(
      const StandardMessageCodec().decodeMessage(ByteData.sublistView(params)),
      color.toARGB32(),
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("Android indicator survives a rebuild with an unchanged colour", (tester) async {
    usePlatform(TargetPlatform.android);
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );
    // The link's state re-invokes surfaceFactory with its original controller;
    // a second identical pump must not crash the surface build.
    await tester.pumpWidget(
      wrap(const PregoActivityIndicator(color: color)),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(PlatformViewLink), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("recreates the native view when the colour changes", (tester) async {
    usePlatform(TargetPlatform.iOS);
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

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets("gives a loosely constrained Flutter spinner a 36 pixel square", (tester) async {
    usePlatform(TargetPlatform.linux);
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
