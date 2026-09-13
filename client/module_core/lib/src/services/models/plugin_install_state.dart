import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Connection-scoped managed install or global runtime update. Absence means no
/// retained operation. The legacy type name remains local to avoid unrelated
/// presentation churn.
@immutable
sealed class const PluginInstallState() {
  const factory inProgress({required PluginInstallProgress progress}) = PluginInstallInProgress;
  const factory failed({required PluginRuntimeProvisionKind operation}) = PluginInstallFailed;
}

final class const PluginInstallInProgress({required final PluginInstallProgress progress}) extends PluginInstallState {
  @override
  bool operator ==(Object other) => other is PluginInstallInProgress && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

final class const PluginInstallFailed({required final PluginRuntimeProvisionKind operation})
    extends PluginInstallState {
  @override
  bool operator ==(Object other) => other is PluginInstallFailed && other.operation == operation;

  @override
  int get hashCode => operation.hashCode;
}

/// The last reported phase, not a percentage of the entire runtime operation.
@immutable
final class const PluginInstallProgress({
  required final PluginRuntimeProvisionKind operation,
  required final PluginInstallPhase phase,

  /// Download completion, only present while downloading with a known total.
  required final int? percent,
}) {
  @override
  bool operator ==(Object other) =>
      other is PluginInstallProgress &&
      other.operation == operation &&
      other.phase == phase &&
      other.percent == percent;

  @override
  int get hashCode => Object.hash(operation, phase, percent);
}
