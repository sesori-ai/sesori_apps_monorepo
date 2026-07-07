import "dart:async";
import "dart:math" as math;

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show ModelPickerModelEntry, ModelPickerSection, ModelPickerSectionBuilder, loge;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "model_picker_list_items.dart";

/// Bottom sheet for selecting a model, grouped by provider.
/// Includes a search field for filtering. Unavailable models are excluded.
///
/// The sheet opens immediately with a progress indicator: the provider and
/// model grouping/sorting runs in a background isolate once the sheet is up,
/// so opening never blocks the UI thread on the size of the model catalog.
class ModelPickerSheet extends StatefulWidget {
  final List<ProviderInfo> providers;
  final String selectedProviderID;
  final String selectedModelID;
  final void Function({required String providerID, required String modelID}) onModelChanged;

  /// Whether the search field grabs focus (and raises the keyboard) as soon as
  /// the sheet opens. Used when the sheet is opened straight into "search mode"
  /// from the composer's model menu.
  final bool autofocusSearch;

  const ModelPickerSheet({
    super.key,
    required this.providers,
    required this.selectedProviderID,
    required this.selectedModelID,
    required this.onModelChanged,
    this.autofocusSearch = false,
  });

  /// Shows the model picker as a modal bottom sheet.
  ///
  /// [fullScreen] makes the sheet rise to just below the top safe area instead
  /// of the default 70 % height — used when escalating from the composer's
  /// compact model menu into a roomy, keyboard-friendly search surface.
  /// [autofocusSearch] opens the sheet with the search field already focused.
  static Future<void> show(
    BuildContext context, {
    required List<ProviderInfo> providers,
    required String selectedProviderID,
    required String selectedModelID,
    required void Function({required String providerID, required String modelID}) onModelChanged,
    bool fullScreen = false,
    bool autofocusSearch = false,
  }) {
    // Status-bar inset, captured before presenting: the modal route strips
    // the top inset from both `padding` and `viewPadding`, so inside the
    // sheet it reads as 0.
    final topInset = MediaQuery.paddingOf(context).top;
    return showPregoBottomSheet<void>(
      context: context,
      title: context.loc.sessionDetailSelectModel,
      // Full-bleed list; rows and the search field pad themselves. The model
      // list scrolls to the bottom edge, so it consumes the home-indicator
      // inset as scroll padding (see the ListView below) rather than having
      // the whole sheet lifted above the indicator.
      contentPadding: EdgeInsetsDirectional.zero,
      handleBottomSafeArea: false,
      builder: (sheetContext) {
        // Granular getters (not MediaQuery.of) so this builder only depends on
        // the height/insets it actually reads, rather than rebuilding on every
        // unrelated MediaQueryData change (text scale, brightness, …).
        final screenHeight = MediaQuery.heightOf(sheetContext);
        final keyboard = MediaQuery.viewInsetsOf(sheetContext).bottom;
        // The body hosts its own scroll view, so it needs a bounded height.
        // The keyboard inset is subtracted (the sheet re-adds it below the
        // body) so the search field stays visible while typing. Full screen:
        // fill from just below the sheet header to the bottom edge.
        final maxBody = screenHeight - topInset - PregoBottomSheet.contentTopInset - keyboard;
        final height = fullScreen ? maxBody : math.min(screenHeight * 0.7 - keyboard, maxBody);
        return SizedBox(
          height: math.max(height, screenHeight * 0.3),
          child: ModelPickerSheet(
            providers: providers,
            selectedProviderID: selectedProviderID,
            selectedModelID: selectedModelID,
            autofocusSearch: autofocusSearch,
            onModelChanged: ({required String providerID, required String modelID}) {
              onModelChanged(providerID: providerID, modelID: modelID);
              context.pop();
            },
          ),
        );
      },
    );
  }

  @override
  State<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<ModelPickerSheet> {
  String _query = "";

  /// Precomputed provider sections; `null` while the background isolate is
  /// still preparing them.
  List<ModelPickerSection>? _sections;

  /// Rows currently visible for [_query]. Cached so unrelated rebuilds
  /// (keyboard animation, focus changes) don't re-run the filter pass; only
  /// recomputed when the sections arrive or the query changes. `null` while
  /// the sections are still loading.
  List<_PickerRow>? _rows;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSections());
  }

  Future<void> _loadSections() async {
    List<ModelPickerSection> sections;
    try {
      sections = await compute(_buildSections, (
        providers: widget.providers,
        selectedProviderID: widget.selectedProviderID,
        selectedModelID: widget.selectedModelID,
      ));
    } catch (error, stackTrace) {
      // Fail soft: show an empty list rather than leaving the sheet stuck
      // on the spinner with an uncaught async error.
      loge("Model picker section build failed", error, stackTrace);
      sections = const [];
    }
    if (!mounted) return;
    setState(() {
      _sections = sections;
      _rows = _visibleRows(sections);
    });
  }

  /// Entry point for compute() — must be top-level or static.
  static List<ModelPickerSection> _buildSections(
    ({List<ProviderInfo> providers, String selectedProviderID, String selectedModelID}) args,
  ) {
    return const ModelPickerSectionBuilder().build(
      providers: args.providers,
      selectedProviderID: args.selectedProviderID,
      selectedModelID: args.selectedModelID,
    );
  }

  /// Flattens the precomputed sections into the rows currently visible,
  /// applying the search query. Cheap: a single `contains` pass over
  /// precomputed lowercase haystacks — no sorting or grouping.
  List<_PickerRow> _visibleRows(List<ModelPickerSection> sections) {
    final query = _query.toLowerCase();
    final rows = <_PickerRow>[];
    for (final section in sections) {
      final models = section.models
          .where((m) => query.isEmpty ? m.visibleByDefault : m.searchText.contains(query))
          .toList();
      if (models.isEmpty) continue;
      rows.add(_ProviderHeaderRow(providerName: section.providerName));
      for (final model in models) {
        rows.add(_ModelRow(providerID: section.providerID, entry: model));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;

    // Transparent Material so the tiles' ink and selection effects paint on
    // top of the sheet surface instead of behind it on the modal's
    // transparent Material.
    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              autofocus: widget.autofocusSearch,
              decoration: InputDecoration(
                hintText: loc.sessionDetailModelSearch,
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: prego.colors.bgPrimary,
              ),
              onChanged: (value) => setState(() {
                _query = value.trim();
                final sections = _sections;
                if (sections != null) _rows = _visibleRows(sections);
              }),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: switch (_rows) {
              null => const Center(child: CircularProgressIndicator()),
              final rows => _buildModelList(context: context, rows: rows),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModelList({required BuildContext context, required List<_PickerRow> rows}) {
    return ListView.builder(
      // Extend the scrollable area underneath the home indicator: the
      // bottom inset is added as scroll padding so the last model can
      // scroll clear of the indicator instead of being clipped above it.
      padding: EdgeInsetsDirectional.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        _ProviderHeaderRow(:final providerName) => ModelPickerProviderHeader(name: providerName),
        _ModelRow(:final providerID, :final entry) => ModelPickerModelTile(
          name: entry.displayName,
          subtitle: entry.family,
          isSelected: widget.selectedProviderID == providerID && widget.selectedModelID == entry.modelID,
          onTap: () => widget.onModelChanged(providerID: providerID, modelID: entry.modelID),
        ),
      },
    );
  }
}

/// A row in the flattened picker list: either a provider header or a model.
sealed class _PickerRow {
  const _PickerRow();
}

class _ProviderHeaderRow extends _PickerRow {
  final String providerName;
  const _ProviderHeaderRow({required this.providerName});
}

class _ModelRow extends _PickerRow {
  final String providerID;
  final ModelPickerModelEntry entry;
  const _ModelRow({required this.providerID, required this.entry});
}
