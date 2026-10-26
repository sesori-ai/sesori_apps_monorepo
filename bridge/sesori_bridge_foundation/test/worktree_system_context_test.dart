import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  final note = buildWorktreeSystemContext(worktreePath: "/tmp/worktrees/blue-otter", baseBranch: "main");

  group("stripWorktreeSystemContext", () {
    test("drops a part that is only the note", () {
      expect(stripWorktreeSystemContext(text: note), isNull);
      expect(stripWorktreeSystemContext(text: note.trimRight()), isNull);
    });

    test("keeps the user text after a note joined into the same text", () {
      expect(stripWorktreeSystemContext(text: "$note\nFix the login bug"), "Fix the login bug");
      expect(stripWorktreeSystemContext(text: "${note}Fix the login bug"), "Fix the login bug");
    });

    test("keeps a leading command token, with and without arguments", () {
      final arguments = "${note.trimRight()}\n\nfocus on auth";
      expect(stripWorktreeSystemContext(text: "/review $arguments"), "/review focus on auth");
      const dollarCommand = r"$review";
      expect(stripWorktreeSystemContext(text: "$dollarCommand $arguments"), "$dollarCommand focus on auth");
      expect(stripWorktreeSystemContext(text: "/review ${note.trimRight()}"), "/review");
    });

    test("preserves authored whitespace after the note", () {
      expect(stripWorktreeSystemContext(text: "$note  indented\ntext  "), "  indented\ntext  ");
    });

    test("leaves text that does not open with the note unchanged", () {
      const plain = "No note here";
      expect(identical(stripWorktreeSystemContext(text: plain), plain), isTrue);
      final quoted = "Why does this show up?\n$note";
      expect(stripWorktreeSystemContext(text: quoted), quoted);
      final unterminated = note.replaceFirst("\n---", "");
      expect(stripWorktreeSystemContext(text: unterminated), unterminated);
    });
  });
}
