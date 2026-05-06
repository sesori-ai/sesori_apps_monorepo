import "package:flutter/material.dart";

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

  AppLocalizations get loc {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw StateError("AppLocalizations not found in BuildContext");
    }
    return localizations;
  }
}
