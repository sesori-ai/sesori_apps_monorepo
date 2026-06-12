import "package:sesori_shared/sesori_shared.dart";

import "default_model_selector.dart";

/// A single selectable model row in the model picker, precomputed so the
/// sheet can render without any per-frame sorting or grouping.
class ModelPickerModelEntry {
  /// Model identifier reported back when the entry is selected.
  final String modelID;

  /// Display name with the upstream "(latest)" marker stripped.
  final String displayName;

  /// Model family, shown as the tile subtitle when present.
  final String? family;

  /// Lowercase haystack (model name, family, id, provider name) matched
  /// against the lowercased search query with a plain `contains`.
  final String searchText;

  /// Whether the entry is shown when the search query is empty — true for
  /// each family's representative and for the currently selected model.
  final bool visibleByDefault;

  const ModelPickerModelEntry({
    required this.modelID,
    required this.displayName,
    required this.family,
    required this.searchText,
    required this.visibleByDefault,
  });
}

/// One provider's section in the model picker.
class ModelPickerSection {
  final String providerID;
  final String providerName;

  /// Available models sorted by release date (newest first, undated last),
  /// ties broken by name.
  final List<ModelPickerModelEntry> models;

  const ModelPickerSection({
    required this.providerID,
    required this.providerName,
    required this.models,
  });
}

/// Shapes raw [ProviderInfo] catalogs into the sections displayed by the
/// model picker sheet.
///
/// This is a pure transformation extracted from the picker widget so it can
/// run inside a background isolate: large catalogs (hundreds to thousands of
/// models) made the synchronous in-build sorting/grouping block the sheet's
/// opening animation.
///
/// For each family of available models a single representative is visible by
/// default; the user reveals the rest by typing in the search field. The
/// selection priority lives in [DefaultModelSelector] — the same priority
/// used by the cubits that pick the initial model when no prior selection
/// exists — so the picker's "default per family" matches the cubit's
/// "default for the whole provider".
class ModelPickerSectionBuilder {
  const ModelPickerSectionBuilder();

  static const _defaultModelSelector = DefaultModelSelector();

  /// Builds the provider sections for the given catalog.
  ///
  /// Providers are sorted by name and providers without available models are
  /// omitted. [selectedProviderID]/[selectedModelID] mark the corresponding
  /// entry as visible by default so the current selection never disappears
  /// from the unfiltered list.
  List<ModelPickerSection> build({
    required List<ProviderInfo> providers,
    required String selectedProviderID,
    required String selectedModelID,
  }) {
    final sortedProviders = providers.toList()..sort((a, b) => a.name.compareTo(b.name));

    final sections = <ModelPickerSection>[];
    for (final provider in sortedProviders) {
      final models = provider.models.values.where((m) => m.isAvailable).toList()
        ..sort((a, b) {
          final aDate = a.releaseDate;
          final bDate = b.releaseDate;
          if (aDate != bDate) {
            if (bDate == null) return -1;
            if (aDate == null) return 1;
            return bDate.compareTo(aDate);
          }
          return a.name.compareTo(b.name);
        });
      if (models.isEmpty) continue;

      final visibleIds = _defaultVisibleIds(
        provider: provider,
        availableModels: models,
        selectedProviderID: selectedProviderID,
        selectedModelID: selectedModelID,
      );

      sections.add(
        ModelPickerSection(
          providerID: provider.id,
          providerName: provider.name,
          models: [
            for (final model in models)
              ModelPickerModelEntry(
                modelID: model.id,
                displayName: model.name.replaceAll("(latest)", "").trim(),
                family: model.family,
                searchText: "${model.name} ${model.family ?? ""} ${model.id} ${provider.name}".toLowerCase(),
                visibleByDefault: visibleIds.contains(model.id),
              ),
          ],
        ),
      );
    }
    return sections;
  }

  /// Builds the set of model IDs that should be visible by default.
  ///
  /// For each family of available models we pick a single representative via
  /// [DefaultModelSelector.pickFromFamily]; the currently selected model of
  /// the selected provider is always included.
  Set<String> _defaultVisibleIds({
    required ProviderInfo provider,
    required List<ProviderModel> availableModels,
    required String selectedProviderID,
    required String selectedModelID,
  }) {
    final visible = <String>{};

    final byFamily = <String, List<ProviderModel>>{};
    for (final m in availableModels) {
      final family = m.family ?? m.id;
      (byFamily[family] ??= []).add(m);
    }

    for (final group in byFamily.values) {
      final chosen = _defaultModelSelector.pickFromFamily(group: group);
      if (chosen != null) visible.add(chosen.id);
    }

    if (provider.id == selectedProviderID) {
      visible.add(selectedModelID);
    }

    return visible;
  }
}
