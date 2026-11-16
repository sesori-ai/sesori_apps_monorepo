import "package:sesori_shared/sesori_shared.dart";

extension ScheduledTaskDefinitionEditability on ScheduledTaskDefinition {
  /// Whether this app knows every part of the definition, so it can send the
  /// definition back whole. A part from a newer peer decodes to an `unknown`
  /// fallback that cannot be sent back, so such a task is shown read-only
  /// ("Edit on a newer app"); running, pausing and deleting it name only its id.
  bool get isEditableHere =>
      switch (prompt) {
        ScheduledTaskPromptText() => true,
        ScheduledTaskPromptCommand(:final source) => source != CommandSource.unknown,
        ScheduledTaskPromptUnknown() => false,
      } &&
      schedule is! TaskScheduleUnknown &&
      runMode is! TaskRunModeUnknown &&
      missedRunPolicy != TaskMissedRunPolicy.unknown &&
      approvalMode != TaskApprovalMode.unknown;
}
