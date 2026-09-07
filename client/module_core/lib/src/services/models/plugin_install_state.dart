import "package:meta/meta.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Connection-scoped managed installation. Absence means no retained operation.
@immutable
sealed class const PluginInstallState() {
  const factory inProgress({required PluginInstallProgress progress}) = PluginInstallInProgress;
  const factory failed() = PluginInstallFailed;
}

final class const PluginInstallInProgress({required final PluginInstallProgress progress}) extends PluginInstallState {
  @override
  bool operator ==(Object other) => other is PluginInstallInProgress && other.progress == progress;

  @override
  int get hashCode => progress.hashCode;
}

final class const PluginInstallFailed() extends PluginInstallState {
  @override
  bool operator ==(Object other) => other is PluginInstallFailed;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The last reported phase, not a percentage of the entire installation.
@immutable
class const PluginInstallProgress({
  required final PluginInstallPhase phase,

  /// Download completion, only present while downloading with a known total.
  required final int? percent,
}) {
  @override
  bool operator ==(Object other) => other is PluginInstallProgress && other.phase == phase && other.percent == percent;

  @override
  int get hashCode => Object.hash(phase, percent);
}
