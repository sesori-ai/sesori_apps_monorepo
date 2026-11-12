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
Future<List<Timer>> _pumpChip({required WidgetTester tester, required Duration left, bool inUse = false}) async {
  final timers = <Timer>[];
  final coldAt = tester.binding.clock.now().add(left);
  await runZoned(
    () => tester.pumpWidget(
      _harness(
        child: SessionPromptCacheChip(surfaceStyle: PregoComposerSurfaceStyle.subtle, coldAt: coldAt, inUse: inUse),
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
    expect(find.text("12 min"), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text("12 min"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text("11 min"), findsOneWidget);
    expect(find.text("12 min"), findsNothing);

    await tester.pumpWidget(_harness(child: const SizedBox()));
  });

  _clockTestWidgets("reads under a minute in the final minute and cold exactly at coldAt", (tester) async {
    final timers = await _pumpChip(tester: tester, left: const Duration(seconds: 40));
    expect(find.text(loc.sessionPromptCacheWarmUnderMinute), findsOneWidget);
    expect(find.text("<1 min"), findsOneWidget);
    expect(timers.where((timer) => timer.isActive), hasLength(1));

    await tester.pump(const Duration(seconds: 39));
    expect(find.text("<1 min"), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text(loc.sessionPromptCacheCold), findsOneWidget);
    expect(find.text("Cold"), findsOneWidget);
    expect(find.text("<1 min"), findsNothing);

    // Once cold the chip schedules nothing more.
    expect(timers.where((timer) => timer.isActive), isEmpty);

    await tester.pumpWidget(_harness(child: const SizedBox()));
  });

  _clockTestWidgets("starts cold without scheduling a timer", (tester) async {
    final timers = await _pumpChip(tester: tester, left: const Duration(seconds: -5));
    expect(find.text("Cold"), findsOneWidget);
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });

  _clockTestWidgets("reads warm without counting down while a turn uses the cache", (tester) async {
    final timers = await _pumpChip(tester: tester, left: const Duration(minutes: 12, seconds: 30), inUse: true);
    expect(find.text(loc.sessionPromptCacheInUse), findsOneWidget);
    expect(find.text("Warm"), findsOneWidget);
    expect(find.text("12 min"), findsNothing);
    expect(timers.where((timer) => timer.isActive), isEmpty);
  });

  _clockTestWidgets("keeps the same size in every state", (tester) async {
    Future<Size> sizeFor({required Duration left, required bool inUse}) async {
      await _pumpChip(tester: tester, left: left, inUse: inUse);
      await tester.pumpAndSettle();
      final size = tester.getSize(find.byType(SessionPromptCacheChip));
      await tester.pumpWidget(_harness(child: const SizedBox()));
      return size;
    }

    final warm = await sizeFor(left: const Duration(minutes: 12, seconds: 30), inUse: false);
    final underMinute = await sizeFor(left: const Duration(seconds: 40), inUse: false);
    final cold = await sizeFor(left: const Duration(seconds: -5), inUse: false);
    final inUse = await sizeFor(left: const Duration(minutes: 12, seconds: 30), inUse: true);

    expect(underMinute, warm);
    expect(cold, warm);
    expect(inUse, warm);
  });
}
