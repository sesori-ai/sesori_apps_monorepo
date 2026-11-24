import "../api/shell_command_api.dart";
import "scheduled_task_change_description_builder.dart";

/// Writes the block that reports a command's result to the agent: how it
/// ended first, then stdout and stderr in their own sections. A short stream
/// is shown whole; a longer one by its file's path, its word count and its
/// last lines.
class const ScheduledCommandResultFormatter() {
  /// The most words a stream may have to be shown whole.
  static const int inlineWordLimit = 500;

  String format({required ShellCommandResult result}) {
    return switch (result) {
      ShellCommandExited(:final exitCode, :final stdout, :final stderr) => [
        "command exited $exitCode",
        _stream(name: "stdout", output: stdout),
        _stream(name: "stderr", output: stderr),
      ].join("\n\n"),
      ShellCommandTimedOut(:final timeout, :final stdout, :final stderr) => [
        "timed out after ${timeout.inMinutes} minutes and was stopped",
        _stream(name: "stdout", output: stdout),
        _stream(name: "stderr", output: stderr),
      ].join("\n\n"),
      ShellCommandCouldNotStart(:final error) => "could not start: $error",
    };
  }

  String _stream({required String name, required ShellStreamOutput output}) {
    if (output.wordCount == 0) return "$name: empty";
    if (output.text case final text? when output.wordCount <= inlineWordLimit) {
      return "$name:\n${_fenced(text: text.trimRight())}";
    }
    final lines = output.lastLines;
    return "$name ${_grouped(count: output.wordCount)} words; full output at ${output.path}\n"
        "Its last ${lines.length == 1 ? "line" : "${lines.length} lines"}:\n${_fenced(text: lines.join("\n"))}";
  }

  String _fenced({required String text}) {
    final marker = ScheduledTaskChangeDescriptionBuilder.fence(text: text);
    return "$marker\n$text\n$marker";
  }

  /// [count] with commas between thousands, as in 32,131.
  String _grouped({required int count}) {
    final digits = count.toString();
    final groups = <String>[];
    for (var end = digits.length; end > 0; end -= 3) {
      groups.insert(0, digits.substring(end - 3 < 0 ? 0 : end - 3, end));
    }
    return groups.join(",");
  }
}
