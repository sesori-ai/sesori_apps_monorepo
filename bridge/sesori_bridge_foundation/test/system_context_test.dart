import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  final note = buildWorktreeSystemContext(worktreePath: "/tmp/worktrees/blue-otter", baseBranch: "main");

  final runNote = buildScheduledRunContext(taskName: "Nightly deps", taskId: "task_1");

  group("buildScheduledRunContext", () {
    test("names the task and the tools from the Sesori server", () {
      expect(runNote, contains('the Sesori task "Nightly deps" (id task_1)'));
      expect(runNote, contains("update_task tool from the sesori_bridge server"));
      expect(runNote, contains("leaving out every field you are not changing"));
    });
  });

  group("stripSystemContext", () {
    test("drops a part that is only a run note", () {
      expect(stripSystemContext(text: runNote), isNull);
    });

    test("removes every leading note, joined or not", () {
      expect(stripSystemContext(text: "$note\n$runNote\nUpdate the deps"), "Update the deps");
      expect(stripSystemContext(text: "$note$runNote"), isNull);
      expect(stripSystemContext(text: "/review $note\n$runNote\nfocus on auth"), "/review focus on auth");
    });

    test("drops a part that is only the note", () {
      expect(stripSystemContext(text: note), isNull);
      expect(stripSystemContext(text: note.trimRight()), isNull);
    });

    test("keeps the user text after a note joined into the same text", () {
      expect(stripSystemContext(text: "$note\nFix the login bug"), "Fix the login bug");
      expect(stripSystemContext(text: "${note}Fix the login bug"), "Fix the login bug");
    });

    test("keeps a leading command token, with and without arguments", () {
      final arguments = "${note.trimRight()}\n\nfocus on auth";
      expect(stripSystemContext(text: "/review $arguments"), "/review focus on auth");
      const dollarCommand = r"$review";
      expect(stripSystemContext(text: "$dollarCommand $arguments"), "$dollarCommand focus on auth");
      expect(stripSystemContext(text: "/review ${note.trimRight()}"), "/review");
    });

    test("preserves authored whitespace after the note", () {
      expect(stripSystemContext(text: "$note  indented\ntext  "), "  indented\ntext  ");
    });

    test("leaves text that does not open with the note unchanged", () {
      const plain = "No note here";
      expect(identical(stripSystemContext(text: plain), plain), isTrue);
      final quoted = "Why does this show up?\n$note";
      expect(stripSystemContext(text: quoted), quoted);
      final unterminated = note.replaceFirst("\n---", "");
      expect(stripSystemContext(text: unterminated), unterminated);
    });
  });

  group("session notices", () {
    final notice = buildSessionNotice(
      summary: "You didn't allow pausing “Daily digest”.",
      guidance: "Don't propose it again unless they ask.",
    );

    test("frame the summary for the user and the guidance for the agent", () {
      expect(
        notice,
        "[SESORI NOTICE]\n"
        "You didn't allow pausing “Daily digest”.\n"
        "[FOR THE AGENT]\n"
        "Sesori wrote this message, not the user. The user sees only the line above,\n"
        "addressed to them.\n"
        "Don't propose it again unless they ask.\n"
        "[END SESORI NOTICE]",
      );
    });

    test("read back their summary, surrounding whitespace allowed", () {
      expect(parseSessionNotice(text: notice), "You didn't allow pausing “Daily digest”.");
      expect(parseSessionNotice(text: "\n  $notice\n\n"), "You didn't allow pausing “Daily digest”.");
    });

    test("match only text that is exactly one notice", () {
      expect(parseSessionNotice(text: "Please read: $notice"), isNull);
      expect(parseSessionNotice(text: "$notice\nAnd one more thing"), isNull);
      expect(parseSessionNotice(text: "$notice\n\n$notice"), isNull);
      expect(parseSessionNotice(text: notice.replaceFirst("[FOR THE AGENT]\n", "")), isNull);
      expect(parseSessionNotice(text: "Fix the login bug"), isNull);
    });
  });
}
