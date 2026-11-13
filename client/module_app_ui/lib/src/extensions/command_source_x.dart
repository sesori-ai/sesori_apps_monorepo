import "package:material_ui/material_ui.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../l10n/app_localizations.dart";

/// How a command's kind shows wherever the app names it: the command picker,
/// a run's card in the transcript, its pin and its row on the Prompts screen.
extension CommandSourcePresentation on CommandSource {
  IconData get icon => switch (this) {
    CommandSource.command => TablerRegular.terminal,
    CommandSource.skill => TablerRegular.sparkles,
    CommandSource.mcp => TablerRegular.plug_connected,
    CommandSource.unknown => TablerRegular.slash,
  };

  /// The kind's name.
  String label({required AppLocalizations loc}) => switch (this) {
    CommandSource.command => loc.commandSourceCommand,
    CommandSource.skill => loc.commandSourceSkill,
    CommandSource.mcp => loc.commandSourceMcp,
    CommandSource.unknown => loc.commandSourceCustom,
  };
}
