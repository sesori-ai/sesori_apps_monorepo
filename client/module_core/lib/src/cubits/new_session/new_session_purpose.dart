import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/new_session_selection_intent.dart";
import "new_session_state.dart";

/// What the new-session composer is open for.
sealed class const NewSessionPurpose() {
  /// Starts a session in [project]: the new-session screen.
  const factory startSession({required NewSessionProject project}) = NewSessionStartSession;

  /// Chooses what a scheduled task runs, starting from [initialSelection]. The
  /// composer never writes the new-session screen's draft or picks (it still
  /// reports the computer it reaches, as every composer does), offers no
  /// attachments, and Save hands back a [TaskComposerSubmission] instead of
  /// starting a session.
  const factory editTask({required TaskComposerSelection initialSelection}) = NewSessionEditTask;

  /// The project the composer opens in.
  NewSessionProject get project;
}

final class const NewSessionStartSession({@override required final NewSessionProject project})
    extends NewSessionPurpose;

final class const NewSessionEditTask({required final TaskComposerSelection initialSelection})
    extends NewSessionPurpose {
  @override
  NewSessionProject get project => initialSelection.project;
}

/// A harness and the picks made on it.
final class const TaskComposerHarnessChoice({
  required final String pluginId,

  /// The agent, model, effort and fast mode; an empty pick takes the harness'
  /// default, as on the new-session screen.
  required final NewSessionSelectionIntent picks,
});

/// What a task's composer opens with: a saved task's choices, or a new task's
/// defaults.
final class const TaskComposerSelection({
  required final NewSessionProject project,

  /// Null starts on the harness the computer offers first.
  required final TaskComposerHarnessChoice? harness,
  required final bool dedicatedWorktree,
  required final String prompt,

  /// The slash command staged with [prompt], by name; it stays unstaged when
  /// the harness no longer offers it.
  required final String? commandName,
});

/// What the composer held when the user saved the task.
///
/// Each Save is its own submission, so saving the same choices again still
/// reaches a listener: this class keeps identity equality on purpose.
final class const TaskComposerSubmission({
  required final NewSessionProject project,
  required final String pluginId,

  /// Null where the harness offers no choice, which runs on its default.
  required final String? agent,
  required final PromptModel? model,
  required final SessionVariant? variant,
  required final bool fastMode,

  /// Whether each run gets its own worktree; never true for a project that
  /// cannot have one.
  required final bool dedicatedWorktree,

  /// The trimmed text; empty only when [command] carries the prompt.
  required final String prompt,
  required final CommandInfo? command,
});
