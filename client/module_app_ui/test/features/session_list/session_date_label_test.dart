import "package:flutter_test/flutter_test.dart";
import "package:intl/date_symbol_data_local.dart";
import "package:sesori_app_ui/src/features/session_list/session_date_label.dart";
import "package:sesori_app_ui/src/l10n/app_localizations_en.dart";

void main() {
  setUpAll(() => initializeDateFormatting("en"));
  test("session headings use non-overlapping calendar weeks and months", () {
    final loc = AppLocalizationsEn();
    final now = DateTime(2026, 9, 16, 15);
    final cases = {
      DateTime(2026, 9, 16): "Today",
      DateTime(2026, 9, 15): "Yesterday",
      DateTime(2026, 9, 14): "This week",
      DateTime(2026, 9, 13): "Last week",
      DateTime(2026, 9, 7): "Last week",
      DateTime(2026, 9, 6): "This month",
      DateTime(2026, 8, 31): "One month ago",
      DateTime(2026, 7, 31): "July 2026",
    };
    for (final entry in cases.entries) {
      expect(sessionDateLabel(date: entry.key, now: now, loc: loc), entry.value);
    }
    expect(
      sessionDateLabel(date: DateTime(2025, 12, 31), now: DateTime(2026, 1, 1), loc: loc),
      "Yesterday",
    );
    expect(
      sessionDateLabel(date: DateTime(2026, 8, 31), now: DateTime(2026, 9, 2), loc: loc),
      "This week",
    );
  });

  test("missing session timestamps use an explicit unknown-date heading", () {
    expect(sessionDateLabel(date: null, now: DateTime(2026, 9, 16), loc: AppLocalizationsEn()), "Unknown date");
  });
}
