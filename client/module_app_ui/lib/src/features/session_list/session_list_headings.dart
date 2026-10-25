import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../l10n/app_localizations.dart";
import "session_date_label.dart";

/// The date heading [session] sits under, without changing the list's order:
/// its archive date once archived, otherwise its last update. A running
/// session is a row of Today, whatever its stored time, and the row itself
/// says it is running.
String sessionListHeading({
  required Session session,
  required bool isRunning,
  required DateTime now,
  required AppLocalizations loc,
}) {
  final archived = session.time?.archived;
  if (archived == null && isRunning) return sessionDateLabel(date: now, now: now, loc: loc);

  final timestamp = archived ?? session.time?.updated;
  return sessionDateLabel(
    date: timestamp == null ? null : DateTime.fromMillisecondsSinceEpoch(timestamp),
    now: now,
    loc: loc,
  );
}

/// One entry of a date-grouped session list: a heading or an item under it.
///
/// Headings are entries of their own, so removing the first item of a group
/// animates only that row; the heading leaves only with its last item.
sealed class const SessionListEntry<T>();

final class const SessionListHeadingEntry<T>({
  required final String heading,

  /// How many earlier groups share [heading]. Only a running session placed
  /// out of date order repeats a heading, and it must not repeat the key.
  required final int occurrence,
}) extends SessionListEntry<T> {
  Key get key => SessionListHeadingKey((heading, occurrence));
}

final class const SessionListItemEntry<T>({required final T item}) extends SessionListEntry<T>;

final class const SessionListHeadingKey(super.value) extends ValueKey<(String, int)>;

/// [items] in their given order, with a heading before each run that shares
/// one.
List<SessionListEntry<T>> groupUnderHeadings<T>({
  required Iterable<T> items,
  required String Function(T item) headingOf,
}) {
  final entries = <SessionListEntry<T>>[];
  final occurrences = <String, int>{};
  String? previousHeading;
  for (final item in items) {
    final heading = headingOf(item);
    if (heading != previousHeading) {
      final occurrence = occurrences.update(heading, (count) => count + 1, ifAbsent: () => 0);
      entries.add(SessionListHeadingEntry(heading: heading, occurrence: occurrence));
      previousHeading = heading;
    }
    entries.add(SessionListItemEntry(item: item));
  }
  return entries;
}

/// A date heading row of a session list.
class const SessionListHeading({super.key, required final String heading, required final bool isFirst})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    // The first heading carries the list's top breathing room, so removing
    // the row below it leaves the heading where it is.
    padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, isFirst ? 20 : 12),
    child: Text(
      heading,
      style: context.prego.textTheme.textSm.medium.copyWith(color: context.prego.colors.textTertiary),
    ),
  );
}
