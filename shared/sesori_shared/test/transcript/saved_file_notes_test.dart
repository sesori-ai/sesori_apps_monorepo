import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("savedFileNote", () {
    test("names the file and its path as inline code", () {
      expect(
        savedFileNote(name: "My Report.pdf", path: "/uploads/ses_1/My Report.pdf"),
        'Attached file "My Report.pdf": `/uploads/ses_1/My Report.pdf`',
      );
    });

    test("keeps backticks, double quotes and line breaks in the name from breaking the note", () {
      expect(savedFileNote(name: "a`b.txt", path: "/u/a"), 'Attached file "a\'b.txt": `/u/a`');
      expect(
        savedFileNote(name: 'my "final"\r\nnotes.txt', path: "/u/b"),
        'Attached file "my \'final\'  notes.txt": `/u/b`',
      );
    });
  });

  group("splitSavedFileNotes", () {
    SavedFileNoteSplit split(String text) => splitSavedFileNotes(text: text);
    List<(String, String)> notesOf(SavedFileNoteSplit split) => [
      for (final note in split.notes) (note.name, note.path),
    ];

    test("reads back every note it writes, whatever the name held", () {
      for (final name in ["a.txt", "My Report.pdf", "a`b.txt", 'my "final"\r\nnotes.txt', "photo (1).png"]) {
        final result = split(savedFileNote(name: name, path: "/uploads/ses_1/2026-11-01-abc/x"));
        expect(result.text, isEmpty, reason: name);
        expect(result.notes.single.path, "/uploads/ses_1/2026-11-01-abc/x", reason: name);
        expect(
          savedFileNote(name: result.notes.single.name, path: result.notes.single.path),
          savedFileNote(name: name, path: "/uploads/ses_1/2026-11-01-abc/x"),
        );
      }
    });

    test("leaves text with no note exactly as it was", () {
      const text = "  Look at this\n\n\nand `that`\n";
      final result = split(text);

      expect(result.text, text);
      expect(result.notes, isEmpty);
    });

    test("drops notes joined by blank lines, as Codex and Pi show them", () {
      final result = split('Read these\n\nAttached file "a.txt": `/u/a.txt`\n\nAttached file "b.txt": `/u/b.txt`');

      expect(result.text, "Read these");
      expect(notesOf(result), [("a.txt", "/u/a.txt"), ("b.txt", "/u/b.txt")]);
    });

    test("drops notes joined by line breaks, as separate text parts show them", () {
      final result = split('Compare\nAttached file "a.txt": `/u/a.txt`\nAttached file "b.txt": `/u/b.txt`');

      expect(result.text, "Compare");
      expect(notesOf(result), [("a.txt", "/u/a.txt"), ("b.txt", "/u/b.txt")]);
    });

    test("keeps the text on both sides of a note with one blank line between", () {
      final result = split('Before\n\nAttached file "a.txt": `/u/a.txt`\n\nAfter');

      expect(result.text, "Before\n\nAfter");
      expect(notesOf(result), [("a.txt", "/u/a.txt")]);
    });

    test("leaves no text for a message that held only notes", () {
      final result = split('Attached file "a.txt": `/u/a.txt`\n\nAttached file "b.txt": `/u/b.txt`');

      expect(result.text, isEmpty);
      expect(result.notes, hasLength(2));
    });

    test("ignores a note quoted inside a line, or one with an empty name or path", () {
      const text = 'see Attached file "a.txt": `/u/a.txt`\nAttached file "": `/u/b`\nAttached file "c": ``';
      final result = split(text);

      expect(result.text, text);
      expect(result.notes, isEmpty);
    });
  });
}
