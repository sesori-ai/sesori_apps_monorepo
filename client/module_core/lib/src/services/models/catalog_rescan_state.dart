import "package:sesori_auth/sesori_auth.dart";

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
    required int failedCount,
  }) = CatalogRescanPartlyFailed;

  const factory failed({required int harnessCount}) = CatalogRescanFailed;

  const factory unsupported() = CatalogRescanUnsupported;

  const factory noHarness() = CatalogRescanNoHarness;

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

/// Some harnesses succeeded and some did not.
///
/// Deliberately carries no counts: a partial total would invite the reader to
/// trust it as the whole result.
final class const CatalogRescanPartlyFailed({
  required final int succeededCount,
  required final int failedCount,
}) extends CatalogRescanState;

/// Every harness failed. Carries no message: `CatalogImportFailed.message` is
/// the bridge's raw `error.toString()` and is never lifted into client state.
final class const CatalogRescanFailed({required final int harnessCount}) extends CatalogRescanState;

/// This bridge cannot rescan at all, because it predates the import route.
final class const CatalogRescanUnsupported() extends CatalogRescanState;

/// There is no harness to rescan: either no management snapshot has arrived
/// yet, the one that arrived failed, or none of its harnesses is routable.
///
/// One variant for all three, because a rescan cannot start in any of them and
/// the user's next move is the same. Without it a fan-out over an empty set
/// would return silently, leaving the pull that asked for it with nothing to
/// show for itself.
final class const CatalogRescanNoHarness() extends CatalogRescanState;

/// Outcome of a rescan aimed at one named harness.
///
/// A targeted request reports back to the card that asked for it, unlike the
/// fan-out, which silently skips a harness that cannot import.
sealed class const CatalogRescanStartResult() {
  const factory accepted() = CatalogRescanStartAccepted;

  const factory notImportable() = CatalogRescanStartNotImportable;

  const factory unsupported() = CatalogRescanStartUnsupported;

  const factory failed({required ApiError cause}) = CatalogRescanStartFailed;
}

final class const CatalogRescanStartAccepted() extends CatalogRescanStartResult;

/// The bridge knows this harness but will not import from it right now.
final class const CatalogRescanStartNotImportable() extends CatalogRescanStartResult;

/// The bridge has no catalog import route.
final class const CatalogRescanStartUnsupported() extends CatalogRescanStartResult;

/// The request failed. [cause] is retained for the local log, because a
/// transport or decoding failure may never have reached the bridge and so
/// cannot be explained by the bridge's own log. It is not for display: the card
/// renders bounded text only.
final class const CatalogRescanStartFailed({required final ApiError cause}) extends CatalogRescanStartResult;
