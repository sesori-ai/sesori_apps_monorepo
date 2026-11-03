import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:test/test.dart";

/// Matches a [NewSessionComposing] state whose phase is [P].
TypeMatcher<NewSessionComposing> composingWith<P extends NewSessionPhase>() =>
    isA<NewSessionComposing>().having((state) => state.phase, "phase", isA<P>());

extension NewSessionComposerLoading on AgentModelData {
  /// Whether the composer still waits for its options or for the project's
  /// worktree capability; tests wait for this to settle.
  bool get isLoading =>
      optionsState.isLoading || projectWorktreeCapability == NewSessionProjectWorktreeCapability.loading;
}
