import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/main.dart";

void main() {
  for (final disposalFails in [false, true]) {
    test("migration failure awaits disposal and renders recovery (disposal fails: $disposalFails)", () async {
      final events = <String>[];
      final disposalStarted = Completer<void>();
      final allowDisposal = Completer<void>();
      Widget? rendered;
      final failure = LegacyStorageMigrationException(
        operation: LegacyStorageMigrationOperation.copyValues,
        innerError: StateError("fixture-private-payload"),
        innerStackTrace: StackTrace.current,
      );
      final bootstrap = bootstrapSesoriApp(
        shouldInitializeFirebase: true,
        configureDependenciesFn: () async {
          events.add("configure");
          throw failure;
        },
        disposeDependenciesFn: () async {
          events.add("dispose-start");
          disposalStarted.complete();
          await allowDisposal.future;
          events.add("dispose-end");
          if (disposalFails) throw StateError("fixture-disposal-failure");
        },
        prepareSingularAttributionFn: () => fail("Attribution must not be prepared"),
        applySingularCrawlGateFn: ({required crawlGate}) => fail("Crawl gate must not run"),
        initializeDeepLinks: () => fail("Deep links must not start"),
        startAttributionFn: () => fail("Attribution must not start"),
        startProductAnalyticsFn: () async => fail("Analytics must not start"),
        startFeedbackPromptFn: () => fail("The feedback prompt must not start"),
        startAnalyticsRouteListenerFn: () async => fail("Analytics routes must not start"),
        startNotificationStartupFn: () async => fail("Notifications must not start"),
        readAppearanceFn: () async => fail("Preferences must not be read"),
        readChatInputModeFn: () async => fail("Preferences must not be read"),
        runAppFn: (app) {
          events.add("render");
          rendered = app;
        },
      );
      await disposalStarted.future;
      expect(rendered, isNull);
      expect(events, ["configure", "dispose-start"]);
      allowDisposal.complete();
      await bootstrap;

      expect(events, ["configure", "dispose-start", "dispose-end", "render"]);
      expect(rendered, isA<PersistenceStartupFailureApp>());
    });
  }
}
