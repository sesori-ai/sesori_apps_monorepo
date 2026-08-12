import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/features/settings/notification_settings_screen.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../helpers/test_helpers.dart";

class _MockNotificationPreferencesService extends Mock implements NotificationPreferencesService;

Widget _app() {
  return BlocProvider<ConnectionOverlayCubit>.value(
    value: StubConnectionOverlayCubit(),
    child: MaterialApp(
      theme: ThemeData(extensions: [PregoDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationSettingsScreen(),
    ),
  );
}

void main() {
  late _MockNotificationPreferencesService service;

  setUpAll(() {
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  setUp(() async {
    service = _MockNotificationPreferencesService();
    when(
      () => service.accountStatusStream,
    ).thenAnswer((_) => Stream.value(NotificationPreferencesAccountStatus.available));
    when(() => service.getAll()).thenAnswer(
      (_) async => {
        NotificationCategory.aiInteraction: true,
        NotificationCategory.sessionMessage: true,
        NotificationCategory.connectionStatus: true,
        NotificationCategory.systemUpdate: true,
      },
    );
    when(
      () => service.setEnabled(
        category: any(named: "category"),
        enabled: any(named: "enabled"),
      ),
    ).thenAnswer(
      (invocation) async => switch (invocation.namedArguments[#enabled]) {
        final bool enabled => enabled,
        _ => throw StateError("Expected a boolean notification preference"),
      },
    );

    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<NotificationPreferencesService>(service);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("tapping the row body toggles the preference", (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("AI Interactions"));
    await tester.pumpAndSettle();

    verify(
      () => service.setEnabled(category: NotificationCategory.aiInteraction, enabled: false),
    ).called(1);
  });

  testWidgets("row announces a single labelled toggle to assistive tech", (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.text("AI Interactions"));
    expect(node.label, contains("AI Interactions"));
    expect(node.label, contains("Questions and permission requests from active AI sessions"));
    expect(node, isSemantics(hasToggledState: true, isToggled: true, hasTapAction: true));

    handle.dispose();
  });

  testWidgets("signed-out state does not remain on an indefinite loader", (tester) async {
    when(
      () => service.accountStatusStream,
    ).thenAnswer((_) => Stream.value(NotificationPreferencesAccountStatus.unavailable));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text("Notification preferences unavailable"), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    verifyNever(() => service.getAll());
  });

  testWidgets("only the preference awaiting its API response shows inline loading", (tester) async {
    final aiResponse = Completer<bool>();
    when(
      () => service.setEnabled(
        category: NotificationCategory.aiInteraction,
        enabled: false,
      ),
    ).thenAnswer((_) => aiResponse.future);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text("AI Interactions"));
    await tester.pump();

    expect(find.byKey(const ValueKey("notification_preference_loading_aiInteraction")), findsOneWidget);
    expect(find.byKey(const ValueKey("notification_preference_switch_aiInteraction")), findsNothing);
    expect(find.byKey(const ValueKey("notification_preference_switch_sessionMessage")), findsOneWidget);

    await tester.tap(find.text("AI Interactions"));
    await tester.tap(find.text("Session Messages"));
    await tester.pump();

    verify(
      () => service.setEnabled(category: NotificationCategory.aiInteraction, enabled: false),
    ).called(1);
    verify(
      () => service.setEnabled(category: NotificationCategory.sessionMessage, enabled: false),
    ).called(1);

    aiResponse.complete(false);
    await tester.pumpAndSettle();

    final aiSwitch = tester.widget<PregoSwitch>(
      find.byKey(const ValueKey("notification_preference_switch_aiInteraction")),
    );
    expect(aiSwitch.value, isFalse);
  });

  testWidgets("failed initial load can be retried", (tester) async {
    var attempt = 0;
    when(() => service.getAll()).thenAnswer((_) async {
      attempt++;
      if (attempt == 1) throw Exception("network unavailable");
      return {
        NotificationCategory.aiInteraction: true,
        NotificationCategory.sessionMessage: true,
        NotificationCategory.connectionStatus: true,
        NotificationCategory.systemUpdate: true,
      };
    });
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load notification preferences"), findsOneWidget);

    await tester.tap(find.byKey(const Key("notification_preferences_retry")));
    await tester.pumpAndSettle();

    expect(find.text("AI Interactions"), findsOneWidget);
    verify(() => service.getAll()).called(2);
  });
}
