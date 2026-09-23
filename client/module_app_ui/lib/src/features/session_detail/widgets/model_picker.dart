import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelPickerSection;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";

/// The composer's model picker, grouped by provider: each provider's
/// representative models, or every model that matches the search.
class const ModelPicker({
  super.key,

  /// Sorted and grouped by the caller, which keeps them across rebuilds.
  required final List<ModelPickerSection> sections,
  required final AgentModel? selected,
  required final void Function({required String providerID, required String modelID}) onModelSelected,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState() extends State<ModelPicker> {
  String _query = "";

  /// Kept until an input changes, so other rebuilds keep the highlight.
  late List<PregoPickerSearchRow> _rows = _buildRows();

  @override
  void didUpdateWidget(ModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sections != widget.sections || oldWidget.selected != widget.selected) _rows = _buildRows();
  }

  List<PregoPickerSearchRow> _buildRows() {
    final query = _query;
    final selected = widget.selected;
    final rows = <PregoPickerSearchRow>[];
    for (final section in widget.sections) {
      final models = section.models
          .where((model) => query.isEmpty ? model.visibleByDefault : model.searchText.contains(query))
          .toList();
      if (models.isEmpty) continue;
      rows.add(PregoPickerSearchHeading(text: section.providerName));
      for (final model in models) {
        rows.add(
          PregoPickerSearchOption(
            isSelected: section.providerID == selected?.providerID && model.modelID == selected?.modelID,
            onPick: () => widget.onModelSelected(providerID: section.providerID, modelID: model.modelID),
            child: _ModelLabel(name: model.displayName, family: model.family),
          ),
        );
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return PregoPickerSearchList(
      searchHint: context.loc.sessionDetailModelSearch,
      onQueryChanged: (query) => setState(() {
        _query = query;
        _rows = _buildRows();
      }),
      rows: _rows,
      emptyText: null,
      onClose: widget.onClose,
    );
  }
}

/// A model's name over its family, styled as the composer menus' items.
class const _ModelLabel({required final String name, required final String? family}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final family = this.family;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
        ),
        if (family != null)
          Text(
            family,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
          ),
      ],
    );
  }
}
