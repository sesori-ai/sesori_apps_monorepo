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

class _MockNotificationPreferencesRepository extends Mock implements NotificationPreferencesRepository {}

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
  late _MockNotificationPreferencesRepository repository;

  setUpAll(() {
    registerFallbackValue(NotificationCategory.aiInteraction);
  });

  setUp(() async {
    repository = _MockNotificationPreferencesRepository();
    when(() => repository.getAll()).thenAnswer(
      (_) async => {for (final category in NotificationCategory.values) category: true},
    );
    when(
      () => repository.setEnabled(category: any(named: "category"), enabled: any(named: "enabled")),
    ).thenAnswer((_) async {});

    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<NotificationPreferencesRepository>(repository);
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
      () => repository.setEnabled(category: NotificationCategory.aiInteraction, enabled: false),
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
}
