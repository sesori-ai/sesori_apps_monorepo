import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelPickerModelEntry, ModelPickerSection;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "model_effort/model_level_strip.dart";

/// Applies a model pick, with the level picked together with it when there is
/// one, and returns the selection that now holds, or null when nothing changed.
typedef ModelSelectionHandler = AgentModel? Function({
  required String providerID,
  required String modelID,
  required SessionVariant? variant,
});

/// The composer's model picker, grouped by provider: each provider's
/// representative models, or every model with [showsEveryModel], or every
/// model that matches the search.
///
/// It picks the model and its effort together. The selected row grows a
/// [ModelLevelStrip] of that model's levels under its name. Tapping another
/// row switches to that model at once and moves the strip there, the old row
/// shrinking while the new one grows; tapping a level, or the selected row
/// itself, keeps that choice and closes the picker.
class const ModelPicker({
  super.key,

  /// Sorted and grouped by the caller, which keeps them across rebuilds.
  required final List<ModelPickerSection> sections,

  /// Lists every model rather than one per family, as the orbits picker's
  /// "All N models" asks for.
  required final bool showsEveryModel,
  required final AgentModel? selected,
  required final ModelSelectionHandler onModelSelected,
  required final VoidCallback onClose,
}) extends StatefulWidget {
  @override
  State<ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState() extends State<ModelPicker> {
  String _query = "";

  /// The selection the open picker shows. A popover's content is built apart
  /// from the composer, so a switch made here follows what the pick applied
  /// rather than waiting for the composer to rebuild it.
  late AgentModel? _selected = widget.selected;

  /// Kept until an input changes, so other rebuilds keep the highlight.
  late List<PregoPickerSearchRow> _rows = _buildRows();

  @override
  void didUpdateWidget(ModelPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) _selected = widget.selected;
    if (oldWidget.sections != widget.sections || oldWidget.selected != widget.selected) _rows = _buildRows();
  }

  bool _isSelected({required String providerID, required String modelID}) =>
      providerID == _selected?.providerID && modelID == _selected?.modelID;

  /// A tap on a row: the selected row keeps its choice and closes; another
  /// row switches to its model at the level the switch rule gives it.
  void _pickModel({required String providerID, required String modelID}) {
    if (_isSelected(providerID: providerID, modelID: modelID)) {
      widget.onClose();
      return;
    }
    final applied = widget.onModelSelected(providerID: providerID, modelID: modelID, variant: null);
    if (applied == null || !mounted) return;
    setState(() {
      _selected = applied;
      _rows = _buildRows();
    });
  }

  void _pickLevel({required String providerID, required String modelID, required SessionVariant level}) {
    widget.onModelSelected(providerID: providerID, modelID: modelID, variant: level);
    widget.onClose();
  }

  List<PregoPickerSearchRow> _buildRows() {
    final query = _query;
    final rows = <PregoPickerSearchRow>[];
    for (final section in widget.sections) {
      final providerID = section.providerID;
      bool isSelected(ModelPickerModelEntry model) => _isSelected(providerID: providerID, modelID: model.modelID);
      final models = section.models
          .where(
            (model) => query.isEmpty
                ? widget.showsEveryModel || model.visibleByDefault || isSelected(model)
                : model.searchText.contains(query),
          )
          .toList();
      if (models.isEmpty) continue;
      rows.add(PregoPickerSearchHeading(text: section.providerName));
      for (final model in models) {
        final modelID = model.modelID;
        final selected = isSelected(model);
        rows.add(
          PregoPickerSearchOption(
            isSelected: selected,
            onPick: () => _pickModel(providerID: providerID, modelID: modelID),
            child: _ModelRow(
              // A row that turns into another model's builds anew, so only a
              // selection change animates.
              key: ValueKey((providerID, modelID)),
              name: model.displayName,
              family: model.family,
              levels: model.levels,
              expanded: selected,
              selectedLevel: selected ? _selected?.variant : null,
              onLevelPicked: (level) => _pickLevel(providerID: providerID, modelID: modelID, level: level),
            ),
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
      footer: null,
      rows: _rows,
      emptyText: null,
      onClose: widget.onClose,
    );
  }
}

/// A model's name over its family, and, while selected, its levels under them.
/// The levels grow and shrink with the selection, so nothing snaps.
class const _ModelRow({
  super.key,
  required final String name,
  required final String? family,
  required final List<SessionVariant> levels,
  required final bool expanded,
  required final String? selectedLevel,
  required final ValueChanged<SessionVariant> onLevelPicked,
}) extends StatefulWidget {
  static const Duration _resize = Duration(milliseconds: 250);

  @override
  State<_ModelRow> createState() => _ModelRowState();
}

class _ModelRowState() extends State<_ModelRow> with SingleTickerProviderStateMixin {
  late final AnimationController _size = AnimationController(
    vsync: this,
    duration: _ModelRow._resize,
    value: widget.expanded ? 1 : 0,
  );
  late final CurvedAnimation _curve = CurvedAnimation(parent: _size, curve: Curves.easeInOut);

  @override
  void didUpdateWidget(_ModelRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded == widget.expanded) return;
    if (prefersReducedMotion(context)) {
      _size.value = widget.expanded ? 1 : 0;
    } else if (widget.expanded) {
      _size.forward();
    } else {
      _size.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _size.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final family = widget.family;
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.name,
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
        // Built only while it shows or eases away.
        AnimatedBuilder(
          animation: _size,
          builder: (context, child) => _size.isDismissed ? const SizedBox.shrink() : child ?? const SizedBox.shrink(),
          child: SizeTransition(
            sizeFactor: _curve,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(
              opacity: _curve,
              child: Padding(
                padding: EdgeInsets.only(top: pointer ? 6 : 8),
                child: widget.levels.isEmpty
                    // As tall as the strip, so the list keeps its height when
                    // the selection moves between a model with levels and one
                    // without.
                    ? SizedBox(
                        height: ModelLevelStrip.heightFor(pointer: pointer),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            context.loc.modelPickerNoEffort,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary),
                          ),
                        ),
                      )
                    : ModelLevelStrip(
                        levels: widget.levels,
                        selected: widget.selectedLevel,
                        onPicked: widget.onLevelPicked,
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
