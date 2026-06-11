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
}
