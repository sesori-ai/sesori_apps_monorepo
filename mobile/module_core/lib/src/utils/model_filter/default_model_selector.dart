import "package:sesori_shared/sesori_shared.dart";

/// Pure helper that selects a single representative [ProviderModel] from a
/// family or from a whole provider's [ProviderInfo.models] map.
///
/// The selector uses only signals already present in the upstream data, so
/// the same logic works for every provider without per-provider knowledge:
///
/// 1. The model with the most recent [ProviderModel.releaseDate]. Models
///    without a release date sort last.
/// 2. The first available model in iteration order.
///
/// The "(latest)" marker in a model name is intentionally ignored as a
/// ranking signal. Providers may label an older model as "latest" (e.g.
/// `Claude Sonnet 4.5 (latest)` vs. a newer `Claude Sonnet 4.8`), so the
/// release date is a more reliable signal for picking the current default.
///
/// The provider's backend-supplied [ProviderInfo.defaultModelID] is
/// intentionally ignored. It is a provider-wide default that is frequently
/// stale (e.g. Kimi), and the family-level newest-by-date signal is a more
/// reliable default for the picker.
///
/// There is intentionally no "newer than X months" cutoff. Deprecated
/// models are already filtered out by [ProviderModel.isAvailable] in
/// `bridge/sesori_plugin_opencode/lib/src/provider_mapper.dart`, and a
/// hard cutoff can hide new models whose metadata is missing or stale.
class DefaultModelSelector {
  const DefaultModelSelector();

  /// Selects the default model for a single family of [ProviderModel]s.
  ///
  /// Returns `null` only if [group] is empty.
  ProviderModel? pickFromFamily({required Iterable<ProviderModel> group}) {
    final list = group.where((m) => m.isAvailable).toList();
    if (list.isEmpty) return null;
    return _bestModel(list);
  }

  /// Selects a single default model across an entire provider.
  ///
  /// Groups [models] by family, picks the best model per family using
  /// [pickFromFamily], then returns the best of those representatives
  /// using the same ranking (newest release date, then `id`).
  ///
  /// Returns `null` if [models] contains no available models.
  ProviderModel? pickFromProvider({required Map<String, ProviderModel> models}) {
    // 1. Group by family, pick the best per family.
    final byFamily = <String, List<ProviderModel>>{};
    for (final m in models.values) {
      if (!m.isAvailable) continue;
      final family = m.family ?? m.id;
      (byFamily[family] ??= []).add(m);
    }
    if (byFamily.isEmpty) return null;

    // 2. Pick the best representative across all families using the same
    //    ranking as `pickFromFamily`. This avoids defaulting to an
    //    arbitrary alphabetically-first family when a newer model exists
    //    in another family.
    final representatives = byFamily.values
        .map((group) => pickFromFamily(group: group))
        .whereType<ProviderModel>()
        .toList();
    if (representatives.isEmpty) return null;
    return _bestModel(representatives);
  }

  /// Returns the best model from [candidates] using the standard ranking:
  /// newest release date, then id.
  ///
  /// [candidates] must be non-empty and contain only available models.
  ProviderModel _bestModel(List<ProviderModel> candidates) {
    assert(candidates.isNotEmpty, "_bestModel requires non-empty candidates");

    final sorted = [...candidates]..sort((a, b) {
        final dateA = a.releaseDate;
        final dateB = b.releaseDate;
        final int dateCompare;
        if (dateB == null && dateA == null) {
          dateCompare = 0;
        } else if (dateB == null) {
          dateCompare = -1;
        } else if (dateA == null) {
          dateCompare = 1;
        } else {
          dateCompare = dateB.compareTo(dateA);
        }
        if (dateCompare != 0) return dateCompare;
        return a.id.compareTo(b.id);
      });
    return sorted.first;
  }
}
