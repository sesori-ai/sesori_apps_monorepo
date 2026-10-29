import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/session_list/session_list_headings.dart";
import "package:sesori_app_ui/src/l10n/app_localizations_en.dart";

void main() {
  test("headings recompute only for other rows or another local day", () {
    final cache = SessionListHeadingCache<int>();
    final loc = AppLocalizationsEn();
    var computed = 0;
    List<String> headingsOf({required List<int> rows, required DateTime now}) => cache.headingsOf(
      rows: rows,
      now: now,
      loc: loc,
      headingOf: (row) {
        computed++;
        return "$row on ${now.day}";
      },
    );
    final rows = [1, 2];
    final morning = DateTime(2026, 10, 29, 8);

    expect(headingsOf(rows: rows, now: morning), ["1 on 29", "2 on 29"]);
    expect(computed, 2);

    expect(headingsOf(rows: rows, now: DateTime(2026, 10, 29, 23, 59)), ["1 on 29", "2 on 29"]);
    expect(computed, 2, reason: "the same rows on the same day");

    expect(headingsOf(rows: [1, 2], now: morning), ["1 on 29", "2 on 29"]);
    expect(computed, 4, reason: "another rows list");

    expect(headingsOf(rows: rows, now: DateTime(2026, 10, 30)), ["1 on 30", "2 on 30"]);
    expect(computed, 6, reason: "the next day");
  });
}
