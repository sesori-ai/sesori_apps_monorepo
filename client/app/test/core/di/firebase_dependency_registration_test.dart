import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_core/firebase_core.dart";
import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:firebase_messaging/firebase_messaging.dart";
import "package:flutter_test/flutter_test.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/di/injection.dart";
import "package:sesori_mobile/core/platform/firebase/firebase_messaging_static_adapter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_firebase_analytics_adapter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_firebase_app_adapter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_firebase_crashlytics_adapter.dart";
import "package:sesori_mobile/core/platform/firebase/no_op_firebase_messaging_adapter.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  test("disabled Firebase environment registers safe SDK substitutes", () async {
    configureDependencies(firebaseEnabled: false);

    expect(getIt<FirebaseApp>(), isA<NoOpFirebaseAppAdapter>());
    expect(getIt<FirebaseMessaging>(), isA<NoOpFirebaseMessagingAdapter>());
    expect(getIt<FirebaseAnalytics>(), isA<NoOpFirebaseAnalyticsAdapter>());
    expect(getIt<FirebaseCrashlytics>(), isA<NoOpFirebaseCrashlyticsAdapter>());

    final staticAdapter = getIt<FirebaseMessagingStaticAdapter>();
    staticAdapter.registerBackgroundHandler(handler: (_) async {});
    await expectLater(staticAdapter.foregroundMessageStream, emitsDone);
    await expectLater(staticAdapter.notificationOpenedStream, emitsDone);

    final messaging = getIt<FirebaseMessaging>();
    expect(await messaging.isSupported(), isFalse);
    expect(await messaging.getToken(), isNull);
    expect(
      (await messaging.requestPermission()).authorizationStatus,
      AuthorizationStatus.denied,
    );

    final analytics = getIt<FirebaseAnalytics>();
    expect(await analytics.isSupported(), isFalse);
    await analytics.logEvent(name: "ignored");
    await analytics.setUserId(id: "ignored");

    final crashlytics = getIt<FirebaseCrashlytics>();
    expect(await crashlytics.checkForUnsentReports(), isFalse);
    await crashlytics.recordError(Exception("ignored"), StackTrace.current);

    final pushMessagingSource = getIt<PushMessagingSource>();
    await pushMessagingSource.initialize();
    expect(await pushMessagingSource.getToken(), isNull);
    await pushMessagingSource.deleteToken();
  });
}
