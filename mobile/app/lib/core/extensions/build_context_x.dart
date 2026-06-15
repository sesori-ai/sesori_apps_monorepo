import "package:flutter/material.dart";
import "package:intl/intl.dart";

import "../../l10n/app_localizations.dart";

extension BuildContextLocalization on BuildContext {
  bool get isDarkMode {
    return brightness == Brightness.dark;
  }

  bool get isLightMode {
    return brightness == Brightness.light;
  }

  Brightness get brightness {
    return Theme.of(this).brightness;
  }

  /// True when OS accessibility settings ask to minimize motion; used to
  /// skip decorative animations.
  ///
  /// Backed solely by the OS reduce-motion preference
  /// (`MediaQuery.disableAnimations`). Screen-reader presence
  /// (`accessibleNavigation`) is intentionally excluded: it is a separate
  /// preference, and screen-reader users may rely on motion for spatial
  /// orientation.
  bool get isReducedMotion {
    return MediaQuery.maybeDisableAnimationsOf(this) ?? false;
  }

  AppLocalizations get loc {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw StateError("AppLocalizations not found in BuildContext");
    }
    return localizations;
  }

  String formatTimestamp(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return loc.timestampJustNow;
    if (diff.inHours < 1) return loc.timestampMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return loc.timestampHoursAgo(diff.inHours);
    if (diff.inDays < 30) return loc.timestampDaysAgo(diff.inDays);
    return DateFormat.yMd(loc.localeName).format(date);
  }

  /// Compact, glanceable timestamp for an individual chat message
  /// (revealed by swiping the transcript). Shows the localized
  /// time-of-day (e.g. "9:41 AM") for messages from today, prefixes the
  /// localized short date (e.g. "Jun 14, 9:41 AM") for earlier days this
  /// year, and includes the year (e.g. "Jun 14, 2025, 9:41 AM") for
  /// messages from previous years so the date is never ambiguous.
  String formatMessageTimestamp(int ms) {
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final locale = loc.localeName;
    final time = DateFormat.jm(locale).format(date);

    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    if (isToday) return time;
    // Include the year for previous-year messages so "Jun 14" can't be
    // mistaken for the current year.
    final datePattern = date.year == now.year ? DateFormat.MMMd(locale) : DateFormat.yMMMd(locale);
    return "${datePattern.format(date)}, $time";
  }
}
