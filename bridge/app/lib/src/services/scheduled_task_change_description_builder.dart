import "dart:math";

import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/agent_approval_change.dart";
import "../repositories/models/agent_approval_outcome.dart";
import "../repositories/models/session_notice.dart";
import "../repositories/models/task_command_edit.dart";

/// Writes the Markdown a user reads before allowing an agent's task change,
/// and the notice its session gets once they answered.
///
/// The security model relies on this text: it opens with the Approve
/// everything warning whenever the resulting task acts without asking, names
/// the project before the action, and shows every field the change sets: an
/// update's old values struck through, and its prompt and command as line
/// diffs that mark the words each changed line changed. Agent-written names,
/// prompts and commands are escaped, so they cannot fake a line.
class const ScheduledTaskChangeDescriptionBuilder() {
  /// Unchanged prompt lines a request shows around each changed one.
  static const _diffContext = 2;

  /// The units a changed line pair is compared in: a word, a run of
  /// whitespace, or any other single character.
  static final _tokens = RegExp(r"[\p{L}\p{N}_]+|\s+|.", unicode: true);

  /// A token that is a word.
  static final _word = RegExp(r"^[\p{L}\p{N}_]", unicode: true);

  /// The most token pairs a changed line pair's word diff compares: its
  /// table takes memory and time in proportion. A longer change shows its
  /// lines without word marks.
  static const _wordDiffBudget = 250000;

  /// Invisible characters that can reorder or hide what a command shows:
  /// bidi marks, embeddings, overrides and isolates, and zero-width ones.
  static final RegExp _invisible = RegExp("[\u061C\u200B-\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]");

  static const String _invisibleNote =
      "It contains invisible characters, which the command above shows as their Unicode codes.";

  String build({
    required ScheduledTaskAgentChange change,
    required String projectName,
    required AgentRequester requester,
  }) {
    final (:approvesEverything, :turnsOnApproveEverything) = switch (change) {
      CreateTaskChange(:final definition) => (
        approvesEverything: definition.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
      UpdateTaskChange(:final before, :final after) => (
        approvesEverything: after.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything:
            after.approvalMode == TaskApprovalMode.approveAll && before.approvalMode != TaskApprovalMode.approveAll,
      ),
      SetTaskEnabledChange(:final before, :final enabled) => (
        approvesEverything: enabled && before.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
      RunTaskNowChange(:final before) => (
        approvesEverything: before.approvalMode == TaskApprovalMode.approveAll,
        turnsOnApproveEverything: false,
      ),
    };
    return [
      if (turnsOnApproveEverything)
        "**Turns on Approve everything: this task's runs will act without asking you.**"
      else if (approvesEverything)
        "**Approve everything: this task's runs act without asking you.**",
      "Project: ${inline(text: projectName)}",
      ..._body(change: change),
      switch (requester) {
        RequestedByOwnRun() => "Asked by a scheduled run of this task.",
        RequestedByTaskRun(:final taskName) => "Asked by a scheduled run of task ${quoted(text: taskName)}.",
        RequestedFromSession(:final title?) => "Asked from session ${quoted(text: title)}.",
        RequestedFromSession(title: null) => "Asked from an untitled session.",
      },
    ].join("\n\n");
  }

  /// What the session that asked for [change] is told once the user answered:
  /// a short line for the user and the agent's guidance. [bySubagent] means a
  /// sub-agent asked, so the notice lands on its root session.
  SessionNotice outcome({
    required ScheduledTaskAgentChange change,
    required AgentApprovalOutcome outcome,
    required bool bySubagent,
  }) {
    final (action, name) = switch (change) {
      CreateTaskChange(:final definition) => ("creating", definition.name),
      UpdateTaskChange(:final before, :final after, command: TaskCommandUnchanged())
          when before.copyWith(name: after.name) == after =>
        (
          "renaming",
          before.name,
        ),
      UpdateTaskChange(:final before) => ("changing", before.name),
      SetTaskEnabledChange(:final before, enabled: true) => ("resuming", before.name),
      SetTaskEnabledChange(:final before, enabled: false) => ("pausing", before.name),
      RunTaskNowChange(:final before) => ("running", before.name),
    };
    final request = "$action ${quoted(text: name)}${change is RunTaskNowChange ? " now" : ""}";
    final (summary, guidance) = switch (outcome) {
      AgentApprovalCreated(:final taskId) => (
        "You allowed $request.",
        "The change is saved and applies from the next run. The new task's id is $taskId.",
      ),
      AgentApprovalApplied() => (
        "You allowed $request.",
        switch (change) {
          RunTaskNowChange() => "The run started.",
          SetTaskEnabledChange(enabled: false) => "The change is saved.",
          CreateTaskChange() ||
          UpdateTaskChange() ||
          SetTaskEnabledChange() => "The change is saved and applies from the next run.",
        },
      ),
      AgentApprovalStale() => (
        "You allowed $request, but it had changed since, so nothing was applied.",
        "Read it with get_task before proposing anything else.",
      ),
      AgentApprovalRunNotStarted(outcome: final run) => (
        "You allowed $request, but it didn’t start.",
        "${_notStartedReason(outcome: run)}.",
      ),
      AgentApprovalRejected() => (
        "You didn’t allow $request.",
        "Nothing changed. Don't propose it again unless they ask.",
      ),
    };
    return SessionNotice(
      summary: summary,
      guidance: [
        if (bySubagent) "A sub-agent of this session made this request.",
        guidance,
        "Reply in one short line.",
      ].join(" "),
      pageRequestId: null,
    );
  }

  String _notStartedReason({required ScheduledTaskRunOutcome outcome}) => switch (outcome) {
    ScheduledTaskRunSkipped() => "The previous run was still going",
    ScheduledTaskRunMissed() => "The bridge was off or asleep",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.projectMissing) => "The project folder is missing",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.harnessUnavailable) => "The harness is unavailable",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.modelUnavailable) => "The task's model is no longer offered",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.startFailed) => "The session failed to start",
    ScheduledTaskRunFailed(reason: TaskRunFailureReason.unknown) ||
    ScheduledTaskRunStarted() ||
    ScheduledTaskRunOutcomeUnknown() => "Its run history shows why",
  };

  /// The schedule in plain words, with its time zone.
  String schedule({required ScheduledTaskDefinition definition}) =>
      scheduleIn(schedule: definition.schedule, timeZone: definition.timeZone);

  /// [schedule] in plain words, with [timeZone].
  String scheduleIn({required TaskSchedule schedule, required String timeZone}) {
    final words = switch (schedule) {
      TaskScheduleOnce(:final at) => "once at ${_localDateTime(at: at)}",
      TaskScheduleDaily(:final time) => "daily at ${_time(time: time)}",
      TaskScheduleWeekdays(:final time) => "Monday to Friday at ${_time(time: time)}",
      TaskScheduleWeekly(:final days, :final time) =>
        "weekly on ${(days.toList()..sort((a, b) => a.isoWeekday.compareTo(b.isoWeekday))).map((day) => day.name).join(", ")} at ${_time(time: time)}",
      TaskScheduleEveryHours(:final hours, :final start) => "every $hours hours from ${_localDateTime(at: start)}",
      TaskScheduleUnknown() => "a schedule this bridge does not know",
    };
    return "$words ($timeZone)";
  }

  List<String> _body({required ScheduledTaskAgentChange change}) {
    switch (change) {
      case CreateTaskChange(:final definition, :final command):
        return [
          "**Create ${quoted(text: definition.name)}**",
          if (command case final command?) ..._runsCommand(command: command),
          for (final field in _Field.values)
            if (field != _Field.name)
              "${field.label}: ${inline(
                text: _value(field: field, definition: definition),
              )}",
          ..._prompt(label: "Prompt", prompt: definition.prompt),
        ];
      case UpdateTaskChange(:final before, :final after, :final beforeCommand, :final afterCommand):
        return [
          "**Update ${quoted(text: before.name)}**",
          for (final field in _Field.values)
            if (_value(field: field, definition: before) case final old
                when old != _value(field: field, definition: after))
              "${field.label}: ~~${inline(text: old)}~~ → ${inline(
                text: _value(field: field, definition: after),
              )}",
          if (before.prompt != after.prompt)
            ...switch ((_promptText(prompt: before.prompt), _promptText(prompt: after.prompt))) {
              // Only the prompt's kind changed, so a diff would show nothing.
              (final old, final updated) when old == updated => _prompt(label: "New prompt", prompt: after.prompt),
              (final old, final updated) => _lineDiffBlock(label: "Prompt changes:", before: old, after: updated),
            },
          ...switch ((beforeCommand, afterCommand)) {
            (null, null) => const <String>[],
            (null, final added?) => ["Adds a command, run before each run's prompt:", ...commandBlock(command: added)],
            (final removed?, null) => ["Stops running this command:", ...commandBlock(command: removed)],
            (final old?, final updated?) when old == updated => const <String>[],
            (final old?, final updated?) => [
              ..._lineDiffBlock(
                label: "Command changes:",
                before: _shown(command: old),
                after: _shown(command: updated),
              ),
              if (_shown(command: old) != old || _shown(command: updated) != updated)
                "It contains invisible characters, which the changes above show as their Unicode codes.",
            ],
          },
        ];
      case SetTaskEnabledChange(:final before, :final beforeCommand, enabled: true):
        return [
          "**Resume ${quoted(text: before.name)}**",
          "Schedule: ${inline(text: schedule(definition: before))}",
          if (beforeCommand case final command?) ..._runsCommand(command: command),
        ];
      case SetTaskEnabledChange(:final before, enabled: false):
        return ["**Pause ${quoted(text: before.name)}**"];
      case RunTaskNowChange(:final before, :final beforeCommand):
        return [
          "**Run ${quoted(text: before.name)} now**",
          if (beforeCommand case final command?) ..._runsCommand(command: command),
        ];
    }
  }

  String _value({required _Field field, required ScheduledTaskDefinition definition}) {
    return switch (field) {
      _Field.approvalMode => switch (definition.approvalMode) {
        TaskApprovalMode.ask => "Ask",
        TaskApprovalMode.approveAll => "Approve everything",
        TaskApprovalMode.unknown => "Unknown",
      },
      _Field.schedule => schedule(definition: definition),
      _Field.model => switch (definition.model) {
        PromptModel(:final providerID, :final modelID) => "$providerID/$modelID",
        null => "Harness default",
      },
      _Field.effort => definition.variant?.id ?? "Harness default",
      _Field.name => definition.name,
      _Field.missedRunPolicy => switch (definition.missedRunPolicy) {
        TaskMissedRunPolicy.runWhenBack => "Run once when the bridge is back",
        TaskMissedRunPolicy.waitForNext => "Wait for the next time",
        TaskMissedRunPolicy.unknown => "Unknown",
      },
      _Field.runMode => switch (definition.runMode) {
        TaskRunModeNewSession() => "A new session each run",
        TaskRunModeSameSession(autoCompact: false) => "One session for every run",
        TaskRunModeSameSession(autoCompact: true) => "One session for every run, compacted before each run",
        TaskRunModeUnknown() => "Unknown",
      },
      _Field.harness => definition.pluginId,
      _Field.agent => definition.agent ?? "Harness default",
      _Field.fastMode => definition.fastMode ? "On" : "Off",
      _Field.worktree => definition.dedicatedWorktree ? "A new worktree each run" : "The project folder",
      _Field.projectId => definition.projectId,
    };
  }

  List<String> _prompt({required String label, required ScheduledTaskPrompt prompt}) {
    final text = _promptText(prompt: prompt);
    final marker = fence(text: text);
    return ["$label:", "$marker\n$text\n$marker"];
  }

  String _promptText({required ScheduledTaskPrompt prompt}) => switch (prompt) {
    ScheduledTaskPromptText(:final text) => text,
    ScheduledTaskPromptCommand(:final name, :final arguments) => "/$name${arguments == null ? "" : " $arguments"}",
    ScheduledTaskPromptUnknown() => "(a prompt kind this bridge does not know)",
  };

  List<String> _runsCommand({required String command}) => [
    "Runs this command before each run's prompt:",
    ...commandBlock(command: command),
  ];

  /// [command] fenced as the shell gets it, except that each invisible
  /// character shows as its code, so it cannot make the command read
  /// differently; a note follows when it has any.
  static List<String> commandBlock({required String command}) {
    final shown = _shown(command: command);
    final marker = fence(text: shown);
    return ["$marker\n$shown\n$marker", if (shown != command) _invisibleNote];
  }

  static String _shown({required String command}) => command.replaceAllMapped(
    _invisible,
    (match) => "<U+${command.codeUnitAt(match.start).toRadixString(16).toUpperCase().padLeft(4, "0")}>",
  );

  /// A git-style line diff, under [label]: every removed and added line, with
  /// [_diffContext] unchanged lines around each change. Each text line starts
  /// with "-", "+" or a space, so none can pass for the "@@" line that stands
  /// for unchanged lines left out.
  ///
  /// The fence's info string carries the words that changed within each
  /// removed line and the added line that replaces it, as
  /// `diff words=<line>:<start>-<end>,…;…`: a line's index in the block, then
  /// the character ranges of its text after the marker. An app that does not
  /// read it still shows the plain line diff.
  List<String> _lineDiffBlock({required String label, required String before, required String after}) {
    final lines = _lineDiff(before: before.split("\n"), after: after.split("\n"));
    final changes = [
      for (final (index, line) in lines.indexed)
        if (!line.startsWith(" ")) index,
    ];
    bool shown(int index) => changes.any((change) => (change - index).abs() <= _diffContext);
    final out = <String>[];
    final skipped = <String>[];
    void flushSkipped() {
      // One left-out line takes as much room as its marker, so show it.
      if (skipped.length == 1) {
        out.add(skipped.single);
      } else if (skipped.isNotEmpty) {
        out.add("@@ ${skipped.length} unchanged lines @@");
      }
      skipped.clear();
    }

    for (final (index, line) in lines.indexed) {
      if (shown(index)) {
        flushSkipped();
        out.add(line);
      } else {
        skipped.add(line);
      }
    }
    flushSkipped();
    final words = [
      for (final (index, spans) in _changedWords(lines: out).indexed)
        if (spans.isNotEmpty) "$index:${spans.map((span) => "${span.start}-${span.end}").join(",")}",
    ];
    final text = out.join("\n");
    final marker = fence(text: text);
    return [label, "${marker}diff${words.isEmpty ? "" : " words=${words.join(";")}"}\n$text\n$marker"];
  }

  /// [before] turned into [after], as lines marked " " (kept), "-" (removed)
  /// or "+" (added).
  List<String> _lineDiff({required List<String> before, required List<String> after}) {
    final lines = <String>[];
    var i = 0;
    var j = 0;
    for (final edit in _diff(before: before, after: after)) {
      switch (edit) {
        case _Edit.keep:
          lines.add(" ${before[i++]}");
          j++;
        case _Edit.remove:
          lines.add("-${before[i++]}");
        case _Edit.add:
          lines.add("+${after[j++]}");
      }
    }
    return lines;
  }

  /// For each of [lines], the ranges of its text (after the marker) whose
  /// words changed. In every run of removed lines followed by added lines, the
  /// first removed line pairs with the first added one, and so on, as in a
  /// split diff; unpaired lines and pairs that share no word stay plain,
  /// because the whole line changed.
  List<List<_Span>> _changedWords({required List<String> lines}) {
    final spans = [for (final _ in lines) <_Span>[]];
    var index = 0;
    while (index < lines.length) {
      if (!lines[index].startsWith("-")) {
        index++;
        continue;
      }
      final removed = index;
      while (index < lines.length && lines[index].startsWith("-")) {
        index++;
      }
      final added = index;
      while (index < lines.length && lines[index].startsWith("+")) {
        index++;
      }
      for (var pair = 0; pair < min(added - removed, index - added); pair++) {
        if (_wordDiff(before: lines[removed + pair].substring(1), after: lines[added + pair].substring(1)) case (
          :final before,
          :final after,
        )) {
          spans[removed + pair] = before;
          spans[added + pair] = after;
        }
      }
    }
    return spans;
  }

  /// The ranges of [before] and of [after] whose words a word-level diff
  /// removes or adds, with ranges that only whitespace separates joined;
  /// null when the two share no word, or when the part between their shared
  /// start and end is too long to compare within [_wordDiffBudget].
  ({List<_Span> before, List<_Span> after})? _wordDiff({required String before, required String after}) {
    final oldTokens = _tokens.allMatches(before).toList();
    final newTokens = _tokens.allMatches(after).toList();
    String text({required String line, required Match token}) => line.substring(token.start, token.end);
    final oldTexts = [for (final token in oldTokens) text(line: before, token: token)];
    final newTexts = [for (final token in newTokens) text(line: after, token: token)];
    // Only the part between a shared start and end needs comparing, which
    // keeps a small edit to a long line cheap.
    var prefix = 0;
    while (prefix < oldTexts.length && prefix < newTexts.length && oldTexts[prefix] == newTexts[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < oldTexts.length - prefix &&
        suffix < newTexts.length - prefix &&
        oldTexts[oldTexts.length - 1 - suffix] == newTexts[newTexts.length - 1 - suffix]) {
      suffix++;
    }
    final oldMiddle = oldTexts.sublist(prefix, oldTexts.length - suffix);
    final newMiddle = newTexts.sublist(prefix, newTexts.length - suffix);
    if (oldMiddle.length * newMiddle.length > _wordDiffBudget) return null;
    final removed = <_Span>[];
    final added = <_Span>[];
    void mark({required List<_Span> spans, required String line, required Match token}) {
      if (spans.lastOrNull case final last? when line.substring(last.end, token.start).trim().isEmpty) {
        spans.last = (start: last.start, end: token.end);
      } else {
        spans.add((start: token.start, end: token.end));
      }
    }

    var sharesWord = false;
    var i = 0;
    var j = 0;
    for (final edit in [
      for (var k = 0; k < prefix; k++) _Edit.keep,
      ..._diff(before: oldMiddle, after: newMiddle),
      for (var k = 0; k < suffix; k++) _Edit.keep,
    ]) {
      switch (edit) {
        case _Edit.keep:
          sharesWord = sharesWord || _word.hasMatch(text(line: before, token: oldTokens[i]));
          i++;
          j++;
        case _Edit.remove:
          mark(spans: removed, line: before, token: oldTokens[i++]);
        case _Edit.add:
          mark(spans: added, line: after, token: newTokens[j++]);
      }
    }
    return sharesWord ? (before: removed, after: added) : null;
  }

  /// [before] turned into [after] through a longest common subsequence.
  /// Removals come before the additions that replace them, as in git.
  List<_Edit> _diff<T>({required List<T> before, required List<T> after}) {
    // common[i][j]: the length of the longest common subsequence of
    // before[i..] and after[j..].
    final common = List.generate(before.length + 1, (_) => List.filled(after.length + 1, 0));
    for (var i = before.length - 1; i >= 0; i--) {
      for (var j = after.length - 1; j >= 0; j--) {
        common[i][j] = before[i] == after[j] ? common[i + 1][j + 1] + 1 : max(common[i + 1][j], common[i][j + 1]);
      }
    }
    final edits = <_Edit>[];
    var i = 0;
    var j = 0;
    while (i < before.length || j < after.length) {
      if (i < before.length && j < after.length && before[i] == after[j]) {
        edits.add(_Edit.keep);
        i++;
        j++;
      } else if (i < before.length && (j == after.length || common[i + 1][j] >= common[i][j + 1])) {
        edits.add(_Edit.remove);
        i++;
      } else {
        edits.add(_Edit.add);
        j++;
      }
    }
    return edits;
  }

  /// A fence longer than any backtick run in [text], so the text stays verbatim.
  static String fence({required String text}) {
    final longestRun = RegExp("`+").allMatches(text).fold(0, (longest, match) {
      final length = match.end - match.start;
      return length > longest ? length : longest;
    });
    return "`" * (longestRun < 3 ? 3 : longestRun + 1);
  }

  /// [text] escaped by [inline], in curly quotes.
  static String quoted({required String text}) => "“${inline(text: text)}”";

  /// [text] on one line with Markdown syntax escaped.
  static String inline({required String text}) {
    return text
        .replaceAll(RegExp(r"\s+"), " ")
        .trim()
        .replaceAllMapped(RegExp(r"[\\`*_\[\]<>~|#!]"), (match) => "\\${match[0]}");
  }

  String _localDateTime({required TaskLocalDateTime at}) =>
      "${at.year.toString().padLeft(4, "0")}-${_two(value: at.month)}-${_two(value: at.day)} "
      "${_two(value: at.hour)}:${_two(value: at.minute)}";

  String _time({required TaskTimeOfDay time}) => "${_two(value: time.hour)}:${_two(value: time.minute)}";

  String _two({required int value}) => value.toString().padLeft(2, "0");
}

/// The definition fields a request lists, in the order it lists them: the
/// ones that decide what a run may do first.
enum _Field({required final String label}) {
  approvalMode(label: "Permissions"),
  schedule(label: "Schedule"),
  model(label: "Model"),
  effort(label: "Effort"),
  name(label: "Name"),
  missedRunPolicy(label: "When a run is missed"),
  runMode(label: "Runs in"),
  harness(label: "Harness"),
  agent(label: "Agent"),
  fastMode(label: "Fast mode"),
  worktree(label: "Works in"),
  projectId(label: "Project folder"),
}

/// One step of a longest-common-subsequence diff.
enum _Edit() {
  keep,
  remove,
  add,
}

/// A range of a line's characters, [end] exclusive.
typedef _Span = ({int start, int end});

/// Who proposed a change, as the request's last line names them.
sealed class const AgentRequester();

/// A scheduled run of the task the change is about.
final class const RequestedByOwnRun() extends AgentRequester;

/// A scheduled run of another task.
final class const RequestedByTaskRun({required final String taskName}) extends AgentRequester;

/// An ordinary session; [title] is null while it has none.
final class const RequestedFromSession({required final String? title}) extends AgentRequester;
