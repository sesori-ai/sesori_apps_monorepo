import "dart:async";

import "package:clock/clock.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/session_prompt_cache_chip.dart";
import "package:theme_prego/module_prego.dart";

/// Runs [callback] with `clock` reading the test's fake time.
void _clockTestWidgets(String description, WidgetTesterCallback callback) => testWidgets(
  description,
  (tester) => withClock(Clock(() => tester.binding.clock.now()), () => callback(tester)),
);

Widget _harness({required Widget child}) => MaterialApp(
  theme: ThemeData(extensions: [PregoDesignSystem.light]),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

/// Pumps a chip going cold [left] from now, recording every timer it starts.
Future<List<Timer>> _pumpChip({required WidgetTester tester, required Duration left}) async {
  final timers = <Timer>[];
  final coldAt = tester.binding.clock.now().add(left);
  await runZoned(
    () => tester.pumpWidget(
      _harness(
        child: SessionPromptCacheChip(surfaceStyle: PregoComposerSurfaceStyle.subtle, coldAt: coldAt),
      ),
    ),
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        final timer = parent.createTimer(zone, duration, callback);
        timers.add(timer);
        return timer;
      },
    ),
  );
  return timers;
}

void main() {
  final loc = AppLocalizationsEn();

  _clockTestWidgets("shows floored minutes and drops one exactly at the minute boundary", (tester) async {
    await _pumpChip(tester: tester, left: const Duration(minutes: 12, seconds: 30));
    expect(find.text(loc.sessionPromptCacheWarm(12)), findsOneWidget);
    expect(find.text("Cache warm · 12 min"), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text("Cache warm · 12 min"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text("Cache warm · 11 min"), findsOneWidget);
    expect(find.text("Cache warm · 12 min"), findsNothing);

    await tester.pumpWidget(_harness(child: const SizedBox()));
  });

  _clockTestWidgets("reads under a minute in the final minute and cold exactly at coldAt", (tester) async {
    final timers = await _pumpChip(tester: tester, left: const Duration(seconds: 40));
    expect(find.text(loc.sessionPromptCacheWarmUnderMinute), findsOneWidget);
    expect(find.text("Cache warm · <1 min"), findsOneWidget);
    expect(timers.where((timer) => timer.isActive), hasLength(1));

    await tester.pump(const Duration(seconds: 39));
    expect(find.text("Cache warm · <1 min"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(loc.sessionPromptCacheCold), findsOneWidget);
    expect(find.text("Cache cold"), findsOneWidget);
    expect(find.text("Cache warm · <1 min"), findsNothing);

    // Once cold the chip schedules nothing more.
    expect(timers.where((timer) => timer.isActive), isEmpty);

    await tester.pumpWidget(_harness(child: const SizedBox()));
  });

  _clockTestWidgets("starts cold without scheduling a timer", (tester) async {
    final timers = await _pumpChip(tester: tester, left: const Duration(seconds: -5));
    expect(find.text("Cache cold"), findsOneWidget);
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });
}
