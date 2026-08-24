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

  const factory starting({required Set<String> pluginIds}) = CatalogRescanStarting;

  const factory running({
    required String activePluginName,
    required int sessionsSeen,
    required Set<String> pluginIds,
  }) = CatalogRescanRunning;

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

  /// Whether a rescan is in flight. Leaving this is what tells a list to
  /// refresh, since a committed import raises no invalidation of its own.
  bool get isLive => this is CatalogRescanStarting || this is CatalogRescanRunning;
}

final class const CatalogRescanIdle() extends CatalogRescanState;

/// Requests are dispatched but no progress has arrived yet.
///
/// Separate from [CatalogRescanRunning] because between dispatch and the first
/// progress event there is no active harness and no session count, and a single
/// running state carrying both would have to invent them.
final class const CatalogRescanStarting({required final Set<String> pluginIds})
    extends CatalogRescanState;

final class const CatalogRescanRunning({
  required final String activePluginName,
  required final int sessionsSeen,
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
final class const CatalogRescanFailed({required final int harnessCount})
    extends CatalogRescanState;

/// This bridge cannot rescan at all, because it predates the import route.
final class const CatalogRescanUnsupported() extends CatalogRescanState;

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
final class const CatalogRescanStartFailed({required final ApiError cause})
    extends CatalogRescanStartResult;
