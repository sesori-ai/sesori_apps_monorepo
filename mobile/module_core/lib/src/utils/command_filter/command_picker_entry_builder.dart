import "package:sesori_shared/sesori_shared.dart";

/// A command row in the command picker, pre-shaped for display.
class CommandPickerEntry {
  /// The command reported back when the entry is selected.
  final CommandInfo command;

  /// Trimmed description, `null` when absent or blank. Capped in length so
  /// pathological multi-kilobyte strings never reach text layout.
  final String? displayDescription;

  /// Non-blank hints joined for display, `null` when there are none.
  final String? displayHints;

  /// Lowercase search haystack (command name, description, hints) matched
  /// against the lowercased search query with a plain `contains`.
  final String searchText;

  const CommandPickerEntry({
    required this.command,
    required this.displayDescription,
    required this.displayHints,
    required this.searchText,
  });
}

/// Shapes raw [CommandInfo] catalogs into the entries displayed by the
/// command picker sheet.
///
/// Pure transformation with no side effects, extracted from the picker
/// widget so it can run in a background isolate: sorting and display-string
/// preparation for large command/skill catalogs would otherwise run during
/// the sheet's opening frame (and again on every rebuild).
class CommandPickerEntryBuilder {
  const CommandPickerEntryBuilder();

  /// Caps precomputed display strings. The tiles show at most two ellipsized
  /// lines, which can never render this many characters — but without a cap
  /// the text engine lays out the full string before truncating, and some
  /// skill/MCP descriptions are multiple kilobytes long.
  static const _maxDisplayLength = 1000;

  /// Builds the picker entries, sorted by command name.
  List<CommandPickerEntry> build({required List<CommandInfo> commands}) {
    final sorted = commands.toList()..sort((a, b) => a.name.compareTo(b.name));
    return [
      for (final command in sorted)
        CommandPickerEntry(
          command: command,
          displayDescription: _displayDescription(command: command),
          displayHints: _displayHints(command: command),
          searchText: _searchText(command: command),
        ),
    ];
  }

  String? _displayDescription({required CommandInfo command}) {
    final description = command.description?.trim();
    if (description == null || description.isEmpty) return null;
    return _truncate(value: description);
  }

  String? _displayHints({required CommandInfo command}) {
    final hints = (command.hints ?? []).where((hint) => hint.trim().isNotEmpty).join("  •  ");
    if (hints.isEmpty) return null;
    return _truncate(value: hints);
  }

  String _searchText({required CommandInfo command}) {
    final hintsText = (command.hints ?? []).join(" ");
    return "${command.name} ${command.description ?? ""} $hintsText".toLowerCase();
  }

  String _truncate({required String value}) =>
      value.length <= _maxDisplayLength ? value : value.substring(0, _maxDisplayLength);
}
