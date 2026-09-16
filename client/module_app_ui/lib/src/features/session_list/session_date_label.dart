import "package:intl/intl.dart";

import "../../l10n/app_localizations.dart";

/// Non-overlapping calendar buckets, evaluated from a session timestamp.
String sessionDateLabel({required DateTime? date, required DateTime now, required AppLocalizations loc}) {
  if (date == null) return loc.sessionListUnknownDate;

  final today = DateTime(now.year, now.month, now.day);
  final calendarDate = DateTime(date.year, date.month, date.day);
  final week = DateTime(today.year, today.month, today.day - today.weekday + 1);
  final lastWeek = DateTime(week.year, week.month, week.day - 7);
  if (!calendarDate.isBefore(today)) return loc.archivedSessionsToday;
  if (calendarDate == DateTime(today.year, today.month, today.day - 1)) return loc.archivedSessionsYesterday;
  if (!calendarDate.isBefore(week)) return loc.archivedSessionsThisWeek;
  if (!calendarDate.isBefore(lastWeek)) return loc.archivedSessionsLastWeek;
  if (!calendarDate.isBefore(DateTime(today.year, today.month))) return loc.archivedSessionsThisMonth;
  if (!calendarDate.isBefore(DateTime(today.year, today.month - 1))) return loc.archivedSessionsLastMonth;
  return DateFormat.yMMMM(loc.localeName).format(calendarDate);
}
