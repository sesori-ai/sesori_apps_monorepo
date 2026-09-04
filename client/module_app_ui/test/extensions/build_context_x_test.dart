import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";

Future<BuildContext> _pumpContext(
  WidgetTester tester, {
  Locale platformLocale = const Locale("en", "US"),
}) async {
  tester.platformDispatcher.localeTestValue = platformLocale;
  addTearDown(tester.platformDispatcher.clearLocaleTestValue);

  late BuildContext captured;
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale("en"),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          captured = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return captured;
}

void main() {
  group("formatTimestampCompact", () {
    testWidgets("uses the user's full platform locale for old session dates", (tester) async {
      final date = DateTime(DateTime.now().year - 1, 7, 8);

      final britishContext = await _pumpContext(tester, platformLocale: const Locale("en", "GB"));
      final britishLabel = britishContext.formatTimestampCompact(ms: date.millisecondsSinceEpoch);

      expect(britishLabel, "08/07/${date.year}");

      final americanContext = await _pumpContext(tester);
      final americanLabel = americanContext.formatTimestampCompact(ms: date.millisecondsSinceEpoch);

      expect(americanLabel, "7/8/${date.year}");
    });
  });

  group("formatMessageTimestamp", () {
    testWidgets("shows time only for messages from today", (tester) async {
      final context = await _pumpContext(tester);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 9, 41);

      final label = context.formatMessageTimestamp(today.millisecondsSinceEpoch);

      // "9:41 AM" — a bare time, with no date prefix.
      expect(label, isNot(contains(",")));
      expect(label, isNot(contains("${now.year}")));
    });

    testWidgets("shows the date without the year for earlier days this year", (tester) async {
      final context = await _pumpContext(tester);
      final now = DateTime.now();
      // A different day in the same year (guaranteed not today).
      final otherDay = now.day == 1 ? DateTime(now.year, now.month, 2, 9, 41) : DateTime(now.year, now.month, 1, 9, 41);

      final label = context.formatMessageTimestamp(otherDay.millisecondsSinceEpoch);

      expect(label, contains(","), reason: "non-today dates carry a date prefix");
      expect(label, isNot(contains("${now.year}")), reason: "this-year dates omit the year");
    });

    testWidgets("includes the year for messages from previous years", (tester) async {
      final context = await _pumpContext(tester);
      final now = DateTime.now();
      final lastYear = DateTime(now.year - 1, 6, 14, 9, 41);

      final label = context.formatMessageTimestamp(lastYear.millisecondsSinceEpoch);

      expect(label, contains("${now.year - 1}"), reason: "cross-year dates must be unambiguous");
    });
  });
}
