import "package:intl/intl.dart";

import "../l10n/app_localizations.dart";

/// The bridge's UTC instant as a date and time in the viewer's zone.
String sessionAutoContinuationLocalTime({required AppLocalizations loc, required int milliseconds}) =>
    DateFormat.yMMMd(loc.localeName).add_jm().format(DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal());
