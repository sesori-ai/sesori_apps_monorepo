import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/app_lifecycle_observer.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test("window occlusion on desktop is inactive, not backgrounded", () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final observer = AppLifecycleObserver();
    addTearDown(observer.onDispose);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);

    expect(observer.lifecycleState, LifecycleState.inactive);
  });

  test("hidden on mobile still reports backgrounding", () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final observer = AppLifecycleObserver();
    addTearDown(observer.onDispose);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);

    expect(observer.lifecycleState, LifecycleState.hidden);
  });
}
