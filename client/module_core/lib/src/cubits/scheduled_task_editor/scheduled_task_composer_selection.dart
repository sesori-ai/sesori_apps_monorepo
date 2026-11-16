import "package:sesori_shared/sesori_shared.dart";

import "../../services/models/new_session_selection_intent.dart";
import "../new_session/new_session_purpose.dart";
import "../new_session/new_session_state.dart";

/// A new task's composer: the harness the computer offers first, with its
/// defaults, and no prompt yet.
TaskComposerSelection newTaskComposerSelection({required NewSessionProject project}) => TaskComposerSelection(
  project: project,
  harness: null,
  dedicatedWorktree: false,
  prompt: "",
  commandName: null,
);

extension ScheduledTaskDefinitionComposerSelection on ScheduledTaskDefinition {
  /// The composer for editing this task in [project], the one it runs in.
  TaskComposerSelection composerSelection({required NewSessionProject project}) => TaskComposerSelection(
    project: project,
    harness: TaskComposerHarnessChoice(
      pluginId: pluginId,
      picks: NewSessionSelectionIntent(
        agentName: agent,
        model: switch (model) {
          PromptModel(:final providerID, :final modelID) => NewSessionModelIntent(
            providerId: providerID,
            modelId: modelID,
          ),
          null => null,
        },
        variant: switch (variant) {
          SessionVariant(:final id) => NewSessionVariantIntent(id: id),
          null => null,
        },
        fastMode: fastMode,
      ),
    ),
    dedicatedWorktree: dedicatedWorktree,
    prompt: switch (prompt) {
      ScheduledTaskPromptText(:final text) => text,
      ScheduledTaskPromptCommand(:final arguments) => arguments ?? "",
      // The editor only opens tasks whose every part this app knows.
      ScheduledTaskPromptUnknown() => "",
    },
    commandName: switch (prompt) {
      ScheduledTaskPromptCommand(:final name) => name,
      ScheduledTaskPromptText() || ScheduledTaskPromptUnknown() => null,
    },
  );
}
