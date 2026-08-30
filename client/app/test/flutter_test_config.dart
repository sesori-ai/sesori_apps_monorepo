import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

/// Global harness for every test in this package.
///
/// The test binding has no handler for the platform-views channel, so any
/// widget rendering a native view — such as `PregoActivityIndicator` on
/// Android, iOS, and macOS — would fail its create call with a
/// `MissingPluginException`. A null reply satisfies every method this suite's
/// platform views send.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async => null);
  });
  await testMain();
}
