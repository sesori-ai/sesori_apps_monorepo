/// The note that stands, in a user's message, for a file the bridge saved from
/// a prompt: `Attached file "NAME":` followed by the path as inline code. The
/// bridge writes it and the app reads it back, so both use this one format.
///
/// The path is inline code, so the app opens it as a file preview. In [name],
/// a backtick would end that code early and a double quote would end the
/// quoted name, so both become `'`; a line break or other control character
/// becomes a space.
String savedFileNote({required String name, required String path}) {
  final shownName = name.replaceAll(_quoteBreakers, "'").replaceAll(_controlCharacters, " ");
  return 'Attached file "$shownName": `$path`';
}

final _quoteBreakers = RegExp('[`"]');
final _controlCharacters = RegExp(r"[\x00-\x1F\x7F]");
final _noteLine = RegExp(r'^Attached file "([^"`\x00-\x1F\x7F]+)": `([^`\x00-\x1F\x7F]+)`$');

/// A saved file a note names. [path] is on the bridge's computer.
final class const SavedFileNote({required final String name, required final String path});

/// A message's text split into what the user wrote and the saved-file notes
/// the bridge added to it, in order.
final class const SavedFileNoteSplit({
  /// The text without the notes, or empty when the message held only notes.
  required final String text,
  required final List<SavedFileNote> notes,
});

/// Splits [text] into what the user wrote and the saved-file notes in it.
///
/// A note is a whole line written by [savedFileNote]. Harnesses join a
/// prompt's parts with a line break or a blank line, so the blank line that
/// set a note apart goes with it, and blank lines left at either end are
/// dropped. Text with no note comes back unchanged.
SavedFileNoteSplit splitSavedFileNotes({required String text}) {
  final kept = <String>[];
  final notes = <SavedFileNote>[];
  for (final line in text.split("\n")) {
    final match = _noteLine.firstMatch(line);
    final name = match?.group(1);
    final path = match?.group(2);
    if (name != null && path != null) {
      notes.add(SavedFileNote(name: name, path: path));
      if (kept.isNotEmpty && kept.last.trim().isEmpty) kept.removeLast();
      continue;
    }
    kept.add(line);
  }
  if (notes.isEmpty) return SavedFileNoteSplit(text: text, notes: const []);
  while (kept.isNotEmpty && kept.first.trim().isEmpty) {
    kept.removeAt(0);
  }
  while (kept.isNotEmpty && kept.last.trim().isEmpty) {
    kept.removeLast();
  }
  return SavedFileNoteSplit(text: kept.join("\n"), notes: List.unmodifiable(notes));
}
