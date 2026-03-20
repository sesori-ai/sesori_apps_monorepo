import "package:flutter/material.dart";
import "package:sesori_shared/sesori_shared.dart";
import "../../../core/extensions/build_context_x.dart";
import "../../../core/widgets/app_modal_bottom_sheet.dart";

/// Bottom sheet for selecting a model, grouped by provider.
///
/// Includes a search field for filtering. Models with status "deprecated"
/// are excluded. Tapping a model selects it and closes the sheet.
class ModelPickerSheet extends StatefulWidget {
  final List<ProviderInfo> providers;
  final String selectedProviderID;
  final String selectedModelID;
  final void Function(String providerID, String modelID) onModelChanged;
  const ModelPickerSheet({
    super.key,
    required this.providers,
    required this.selectedProviderID,
    required this.selectedModelID,
    required this.onModelChanged,
  });

  /// Shows the model picker as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<ProviderInfo> providers,
    required String selectedProviderID,
    required String selectedModelID,
    required void Function(String providerID, String modelID) onModelChanged,
  }) {
    return showAppModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(16),
            ),
          ),
          child: ModelPickerSheet(
            providers: providers,
            selectedProviderID: selectedProviderID,
            selectedModelID: selectedModelID,
            onModelChanged: (providerID, modelID) {
              onModelChanged(providerID, modelID);
              Navigator.of(context).pop();
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

  late final _sortedProviders = widget.providers.toList()..sort((a, b) => a.name.compareTo(b.name));

  bool _matchesQuery(ProviderModel model, String providerName) {
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return model.name.toLowerCase().contains(q) ||
        (model.family?.toLowerCase().contains(q) ?? false) ||
        model.id.toLowerCase().contains(q) ||
        providerName.toLowerCase().contains(q);
  }

  /// Builds the set of model IDs that should be visible by default
  /// (when not searching). Matches the web UI logic: pick the newest
  /// model per family (released within the last 6 months). Models
  /// without a family or without a valid release date are always shown.
  Set<String> _defaultVisibleIds(ProviderInfo provider) {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - 6, now.day);
    final visible = <String>{};

    // Group non-deprecated models by family.
    final byFamily = <String, List<ProviderModel>>{};
    for (final m in provider.models.values) {
      if (m.status == "deprecated") continue;
      final family = m.family ?? m.id;
      (byFamily[family] ??= []).add(m);
    }

    for (final group in byFamily.values) {
      // Pick the newest model in each family.
      group.sort((a, b) => (b.releaseDate ?? "").compareTo(a.releaseDate ?? ""));
      final newest = group.first;
      final date = DateTime.tryParse(newest.releaseDate ?? "");
      // Show if released within last 6 months, or if no valid date.
      if (date == null || date.isAfter(cutoff)) {
        visible.add(newest.id);
      }
    }

    // Always include the currently selected model so it's visible.
    if (provider.id == widget.selectedProviderID) {
      visible.add(widget.selectedModelID);
    }

    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = context.loc;

    return Column(
      children: [
        // Drag handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            loc.sessionDetailSelectModel,
            style: theme.textTheme.titleMedium,
          ),
        ),
        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            autofocus: false,
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
              fillColor: theme.colorScheme.surfaceContainerHighest,
            ),
            onChanged: (value) => setState(() => _query = value.trim()),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView(
            padding: .zero,
            children: [
              for (final provider in _sortedProviders) ..._buildProviderSection(provider, theme),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProviderSection(ProviderInfo provider, ThemeData theme) {
    final isSearching = _query.isNotEmpty;
    final visibleIds = isSearching ? null : _defaultVisibleIds(provider);

    final models =
        provider.models.values
            .where((m) => m.status != "deprecated")
            .where((m) => _matchesQuery(m, provider.name))
            .where((m) => isSearching || visibleIds!.contains(m.id))
            .toList()
          // Sort by release_date descending (newest first), then by name.
          ..sort((a, b) {
            final aDate = a.releaseDate ?? "";
            final bDate = b.releaseDate ?? "";
            if (aDate != bDate) return bDate.compareTo(aDate);
            return a.name.compareTo(b.name);
          });

    if (models.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          provider.name,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final model in models)
        _ModelTile(
          name: model.name.replaceAll("(latest)", "").trim(),
          subtitle: model.family,
          isSelected: widget.selectedProviderID == provider.id && widget.selectedModelID == model.id,
          onTap: () => widget.onModelChanged(provider.id, model.id),
        ),
    ];
  }
}

class _ModelTile extends StatelessWidget {
  final String name;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelTile({
    required this.name,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      dense: true,
      title: Text(name),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      leading: isSelected
          ? Icon(Icons.radio_button_checked, color: theme.colorScheme.primary)
          : Icon(Icons.radio_button_unchecked, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}
