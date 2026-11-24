import "package:sesori_bridge/src/repositories/models/scheduled_command_result.dart";
import "package:sesori_bridge/src/services/scheduled_command_result_formatter.dart";
import "package:test/test.dart";

const _formatter = ScheduledCommandResultFormatter();

CommandStreamOutput _stream({required int words, required bool kept}) {
  final text = List.filled(words, "w").join(" ");
  return CommandStreamOutput(
    path: "/out/stdout.txt",
    wordCount: words,
    lastLines: ["second to last", "last"],
    text: kept ? "$text\n" : null,
  );
}

const _empty = CommandStreamOutput(path: "/out/stderr.txt", wordCount: 0, lastLines: [], text: "");

void main() {
  test("leads with the exit code and shows a short stream whole", () {
    final text = _formatter.format(
      result: ScheduledCommandExited(exitCode: 1, stdout: _stream(words: 500, kept: true), stderr: _empty),
    );

    expect(text, startsWith("command exited 1\n\nstdout:\n```\nw w"));
    expect(text, endsWith("w\n```\n\nstderr: empty"));
  });

  test("names the file, the word count and the last lines of a longer stream", () {
    for (final kept in [true, false]) {
      final text = _formatter.format(
        result: ScheduledCommandExited(
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
        result: ScheduledCommandExited(exitCode: 0, stdout: _stream(words: 501, kept: true), stderr: _empty),
      ),
      contains("stdout 501 words; full output at"),
    );
    expect(
      _formatter.format(
        result: const ScheduledCommandExited(
          exitCode: 0,
          stdout: CommandStreamOutput(path: null, wordCount: 600, lastLines: ["last"], text: null),
          stderr: _empty,
        ),
      ),
      contains("stdout 600 words; the full output could not be saved\nIts last line:"),
    );
  });

  test("says when a command timed out, was stopped or could not start", () {
    expect(
      _formatter.format(
        result: const ScheduledCommandTimedOut(timeout: Duration(minutes: 10), stdout: _empty, stderr: _empty),
      ),
      startsWith("timed out after 10 minutes and was stopped\n\nstdout: empty"),
    );
    expect(
      _formatter.format(
        result: const ScheduledCommandStopped(stdout: _empty, stderr: _empty),
      ),
      startsWith("stopped by a bridge shutdown\n\nstdout: empty"),
    );
    expect(
      _formatter.format(result: const ScheduledCommandCouldNotStart(error: "no such directory")),
      "could not start: no such directory",
    );
  });
}
