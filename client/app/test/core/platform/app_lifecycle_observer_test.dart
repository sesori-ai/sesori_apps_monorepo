import "package:flutter/widgets.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/platform/app_lifecycle_observer.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("hidden reports backgrounding", () {
    final observer = AppLifecycleObserver();
    addTearDown(observer.onDispose);
    observer.didChangeAppLifecycleState(AppLifecycleState.hidden);

    expect(observer.lifecycleState, LifecycleState.hidden);
  });
}
