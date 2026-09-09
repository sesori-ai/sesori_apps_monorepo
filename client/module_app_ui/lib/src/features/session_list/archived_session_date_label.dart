import "package:intl/intl.dart";

import "../../l10n/app_localizations.dart";

/// Non-overlapping calendar buckets, evaluated from the archive timestamp.
String archivedSessionDateLabel({required DateTime archivedAt, required DateTime now, required AppLocalizations loc}) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(archivedAt.year, archivedAt.month, archivedAt.day);
  final week = DateTime(today.year, today.month, today.day - today.weekday + 1);
  final lastWeek = DateTime(week.year, week.month, week.day - 7);
  if (!date.isBefore(today)) return loc.archivedSessionsToday;
  if (date == DateTime(today.year, today.month, today.day - 1)) return loc.archivedSessionsYesterday;
  if (!date.isBefore(week)) return loc.archivedSessionsThisWeek;
  if (!date.isBefore(lastWeek)) return loc.archivedSessionsLastWeek;
  if (!date.isBefore(DateTime(today.year, today.month))) return loc.archivedSessionsThisMonth;
  if (!date.isBefore(DateTime(today.year, today.month - 1))) return loc.archivedSessionsLastMonth;
  return DateFormat.yMMMM(loc.localeName).format(date);
}
