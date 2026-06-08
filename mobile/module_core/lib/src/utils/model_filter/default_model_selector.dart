import "package:sesori_shared/sesori_shared.dart";

/// Pure helper that selects a single representative [ProviderModel] from a
/// family or from a whole provider's [ProviderInfo.models] map.
///
/// The selector uses only signals already present in the upstream data, so
/// the same logic works for every provider without per-provider knowledge:
///
/// 1. The provider's backend-supplied [ProviderInfo.defaultModelID], if it
///    is available. This is the strongest signal — it is the provider's own
///    "this is the default" answer.
/// 2. Any model whose name contains the upstream " (latest)" marker.
///    OpenCode / models.dev uses this suffix to flag a model as the
///    recommended one in its family (e.g. `Claude Sonnet 4.5 (latest)`,
///    `Mistral Small (latest)`). The model picker already strips this
///    suffix from the display name, so it is a known convention worth
///    trusting.
/// 3. The model with the most recent [ProviderModel.releaseDate]. Models
///    without a release date sort last.
/// 4. The first available model in iteration order.
///
/// There is intentionally no "newer than X months" cutoff. Deprecated
/// models are already filtered out by [ProviderModel.isAvailable] in
/// `bridge/sesori_plugin_opencode/lib/src/provider_mapper.dart`, and a
/// hard cutoff can hide new models whose metadata is missing or stale.
class DefaultModelSelector {
  const DefaultModelSelector();

  /// Selects the default model for a single family of [ProviderModel]s.
  ///
  /// [defaultModelId] is honored only when it identifies one of the
  /// [group] members. Returns `null` only if [group] is empty.
  ProviderModel? pickFromFamily({
    required Iterable<ProviderModel> group,
    required String? defaultModelId,
  }) {
    final list = group.where((m) => m.isAvailable).toList();
    if (list.isEmpty) return null;

    // 1. Provider's backend default.
    if (defaultModelId != null) {
      for (final m in list) {
        if (m.id == defaultModelId) return m;
      }
    }

    // 2. Upstream "(latest)" name marker. Ties broken by newest release date.
    final latestMarked =
        list.where((m) => m.name.toLowerCase().contains("(latest)")).toList();
    if (latestMarked.isNotEmpty) {
      // `List.sort` requires a two-positional-arg comparator; the inline
      // form avoids the `prefer_required_named_parameters` lint while
      // keeping the same behavior as the closed-over helper.
      latestMarked.sort((a, b) {
        final dateA = a.releaseDate;
        final dateB = b.releaseDate;
        if (dateB == null && dateA == null) return 0;
        if (dateB == null) return -1;
        if (dateA == null) return 1;
        return dateB.compareTo(dateA);
      });
      return latestMarked.first;
    }

    // 3. Newest by releaseDate. See note above about the inline comparator.
    final sorted = [...list]..sort((a, b) {
        final dateA = a.releaseDate;
        final dateB = b.releaseDate;
        if (dateB == null && dateA == null) return 0;
        if (dateB == null) return -1;
        if (dateA == null) return 1;
        return dateB.compareTo(dateA);
      });
    return sorted.first;
  }

  /// Selects a single default model across an entire provider.
  ///
  /// Groups [models] by family, picks the best model per family using
  /// [pickFromFamily], then returns the best model of the alphabetically
  /// first family. If [defaultModelId] is set and matches an available
  /// model in [models], that model wins regardless of family order.
  ///
  /// Returns `null` if [models] contains no available models.
  ProviderModel? pickFromProvider({
    required Map<String, ProviderModel> models,
    required String? defaultModelId,
  }) {
    // 1. Provider's backend default always wins.
    if (defaultModelId != null) {
      final m = models[defaultModelId];
      if (m != null && m.isAvailable) return m;
    }

    // 2. Group by family, pick the best per family.
    final byFamily = <String, List<ProviderModel>>{};
    for (final m in models.values) {
      if (!m.isAvailable) continue;
      final family = m.family ?? m.id;
      (byFamily[family] ??= []).add(m);
    }
    if (byFamily.isEmpty) return null;

    // 3. Use the alphabetically first family. Stable, deterministic, and
    //    independent of map iteration order so the same provider always
    //    picks the same default.
    final sortedKeys = byFamily.keys.toList()..sort();
    final firstGroup = byFamily[sortedKeys.first];
    if (firstGroup == null) return null;
    return pickFromFamily(group: firstGroup, defaultModelId: defaultModelId);
  }
}
