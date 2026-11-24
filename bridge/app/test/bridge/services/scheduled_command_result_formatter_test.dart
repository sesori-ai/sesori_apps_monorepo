import "package:sesori_bridge/src/api/shell_command_api.dart";
import "package:sesori_bridge/src/services/scheduled_command_result_formatter.dart";
import "package:test/test.dart";

const _formatter = ScheduledCommandResultFormatter();

ShellStreamOutput _stream({required int words, required bool kept}) {
  final text = List.filled(words, "w").join(" ");
  return ShellStreamOutput(
    path: "/out/stdout.txt",
    wordCount: words,
    lastLines: ["second to last", "last"],
    text: kept ? "$text\n" : null,
  );
}

const _empty = ShellStreamOutput(path: "/out/stderr.txt", wordCount: 0, lastLines: [], text: "");

void main() {
  test("leads with the exit code and shows a short stream whole", () {
    final text = _formatter.format(
      result: ShellCommandExited(exitCode: 1, stdout: _stream(words: 500, kept: true), stderr: _empty),
    );

    expect(text, startsWith("command exited 1\n\nstdout:\n```\nw w"));
    expect(text, endsWith("w\n```\n\nstderr: empty"));
  });

  test("names the file, the word count and the last lines of a longer stream", () {
    for (final kept in [true, false]) {
      final text = _formatter.format(
        result: ShellCommandExited(
          exitCode: 0,
          stdout: _empty,
          stderr: _stream(words: 32131, kept: kept),
        ),
      );

      expect(
        text,
        endsWith(
          "stderr 32,131 words; full output at /out/stdout.txt\nIts last 2 lines:\n```\nsecond to last\nlast\n```",
        ),
      );
    }
    expect(
      _formatter.format(
        result: ShellCommandExited(exitCode: 0, stdout: _stream(words: 501, kept: true), stderr: _empty),
      ),
      contains("stdout 501 words; full output at"),
    );
  });

  test("says when a command timed out or could not start", () {
    expect(
      _formatter.format(
        result: const ShellCommandTimedOut(timeout: Duration(minutes: 10), stdout: _empty, stderr: _empty),
      ),
      startsWith("timed out after 10 minutes and was stopped\n\nstdout: empty"),
    );
    expect(
      _formatter.format(result: const ShellCommandCouldNotStart(error: "no such directory")),
      "could not start: no such directory",
    );
  });
}
