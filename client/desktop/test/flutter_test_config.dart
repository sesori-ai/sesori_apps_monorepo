import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// Global harness for every test in this package.
///
/// Widget tests render `PregoActivityIndicator`'s native platform views since
/// the Android/macOS branches landed; without a channel handler the create
/// call fails with a `MissingPluginException` in every loading-state test. A
/// null reply satisfies every method this suite's platform views send.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    // Only widget-test suites have a binding (`testWidgets` initializes it at
    // declaration time, before setUp runs). Plain test() suites must not get
    // one forced on them: TestWidgetsFlutterBinding installs HttpOverrides
    // that answer every real HttpClient request with a 400, which breaks
    // suites exercising a local HTTP server.
    if (BindingBase.debugBindingType() == null) return;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async => null);
  });
  await testMain();
}
