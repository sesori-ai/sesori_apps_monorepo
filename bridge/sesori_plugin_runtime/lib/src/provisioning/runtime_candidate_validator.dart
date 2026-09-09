import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show StartAbortSignal;

/// Disposable, installer-owned context for validating one managed-runtime
/// candidate before it can be placed or trusted from cache.
///
/// [workingDirectory] and [stateDirectory] are private children of managed
/// staging. Validators may create files only within those directories and must
/// settle any work they start before returning. The installer awaits validation
/// and removes the complete context afterwards.
class const RuntimeCandidateValidationContext({
  required final String executablePath,
  required final String workingDirectory,
  required final String stateDirectory,
  required final Map<String, String> environment,
  required final StartAbortSignal abortSignal,
});

/// Backend-neutral pre-placement validation supplied by each managed runtime.
///
/// Implementations own their process protocol and must return `true` only when
/// the candidate satisfies that runtime's pinned contract. They receive the
/// bridge abort signal so validators with cancellable process ownership can
/// stop and await teardown. Bounded run-to-completion command validators may
/// instead observe abort at command boundaries.
abstract interface class RuntimeCandidateValidator() {
  Future<bool> validate({required RuntimeCandidateValidationContext context});
}
