import "package:sesori_shared/sesori_shared.dart";

/// Projects a stored message for a transcript page.
extension DuplicatedShellTitleMapping on MessageWithParts {
  /// This message with each shell tool's title dropped when it only repeats
  /// the tool's `shellCommand`. Apps since v1.8.4 render the command from
  /// `shellCommand`, so the duplicate only costs page bytes. Live events keep
  /// the title for older apps that read the command from it.
  MessageWithParts withoutDuplicatedShellTitles() => copyWith(
    parts: [
      for (final part in parts)
        switch (part) {
          MessagePartTool(state: ToolState(:final title, shellCommand: final String command) && final state)
              when title == command =>
            part.copyWith(state: state.copyWith(title: null)),
          _ => part,
        },
    ],
  );
}
