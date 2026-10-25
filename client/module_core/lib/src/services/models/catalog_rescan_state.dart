/// What a completed rescan found, as one aggregate across every harness that
/// took part.
///
/// Two variants rather than nullable counts, because "the bridge reported a
/// delta" and "the bridge reports no delta" need different wording and a
/// consumer must not be able to confuse them.
sealed class const CatalogRescanCounts() {
  const factory delta({required int newProjects, required int newSessions}) = CatalogRescanDelta;

  const factory totals({required int projects, required int sessions}) = CatalogRescanTotals;
}

/// Summed new-item counts, reported when every succeeded harness supplied one.
final class const CatalogRescanDelta({
  required final int newProjects,
  required final int newSessions,
}) extends CatalogRescanCounts {
  bool get isEmpty => newProjects == 0 && newSessions == 0;
}

/// Summed published totals, used when at least one harness omitted its delta.
///
/// A delta missing one harness's contribution would understate the result while
/// still reading as authoritative, so the whole row falls back rather than
/// mixing the two.
final class const CatalogRescanTotals({
  required final int projects,
  required final int sessions,
}) extends CatalogRescanCounts;

/// The aggregate rescan shown as a single row, whatever the harness count.
sealed class const CatalogRescanState() {
  const factory idle() = CatalogRescanIdle;

  const factory preparingOne({
    required String pendingPluginName,
    required int finishedHarnessCount,
    required Set<String> pluginIds,
  }) = CatalogRescanPreparingOne;

  const factory starting({
    required String activePluginName,
    required int finishedHarnessCount,
    required Set<String> pluginIds,
  }) = CatalogRescanStarting;

  const factory reading({
    required String activePluginName,
    required int sessionsSeen,
    required int finishedHarnessCount,
    required Set<String> pluginIds,
  }) = CatalogRescanReading;

  const factory saving({
    required String activePluginName,
    required int finishedHarnessCount,
    required Set<String> pluginIds,
  }) = CatalogRescanSaving;

  const factory succeeded({
    required int harnessCount,
    required CatalogRescanCounts counts,
  }) = CatalogRescanSucceeded;

  const factory partlyFailed({
    required int succeededCount,
    required Set<String> failedPluginIds,
  }) = CatalogRescanPartlyFailed;

  const factory failed({required Set<String> failedPluginIds}) = CatalogRescanFailed;

  /// Whether a rescan is in flight. Leaving this is what tells a list to
  /// refresh, since a committed import raises no invalidation of its own.
  bool get isLive =>
      this is CatalogRescanPreparingOne ||
      this is CatalogRescanStarting ||
      this is CatalogRescanReading ||
      this is CatalogRescanSaving;
}

final class const CatalogRescanIdle() extends CatalogRescanState;

/// The first scan member that has not reported a terminal progress state yet.
final class const CatalogRescanPreparingOne({
  required final String pendingPluginName,
  required final int finishedHarnessCount,
  required final Set<String> pluginIds,
}) extends CatalogRescanState;

/// One scan member is authoritatively reported as starting by this bridge's
/// fresh management snapshot.
final class const CatalogRescanStarting({
  required final String activePluginName,
  required final int finishedHarnessCount,
  required final Set<String> pluginIds,
}) extends CatalogRescanState;

/// One scan member is enumerating its catalog.
final class const CatalogRescanReading({
  required final String activePluginName,
  required final int sessionsSeen,
  required final int finishedHarnessCount,
  required final Set<String> pluginIds,
}) extends CatalogRescanState;

/// One scan member is committing its catalog snapshot.
final class const CatalogRescanSaving({
  required final String activePluginName,
  required final int finishedHarnessCount,
  required final Set<String> pluginIds,
}) extends CatalogRescanState;

final class const CatalogRescanSucceeded({
  required final int harnessCount,
  required final CatalogRescanCounts counts,
}) extends CatalogRescanState;

/// Some harnesses succeeded and some did not. [failedPluginIds] name the
/// harnesses that failed, so the alert can say which.
///
/// Deliberately carries no counts: a partial total would invite the reader to
/// trust it as the whole result.
final class const CatalogRescanPartlyFailed({
  required final int succeededCount,
  required final Set<String> failedPluginIds,
}) extends CatalogRescanState {
  int get failedCount => failedPluginIds.length;
}

/// Every harness failed. Carries no message: `CatalogImportFailed.message` is
/// the bridge's raw `error.toString()` and is never lifted into client state.
final class const CatalogRescanFailed({required final Set<String> failedPluginIds}) extends CatalogRescanState;
