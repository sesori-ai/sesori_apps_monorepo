import "package:flutter/widgets.dart";
import "../../l10n/app_localizations.dart";

extension BuildContextLocalization on BuildContext {
  AppLocalizations get loc {
    final localizations = AppLocalizations.of(this);
    if (localizations == null) {
      throw StateError("AppLocalizations not found in BuildContext");
    }
    return localizations;
  }
}
