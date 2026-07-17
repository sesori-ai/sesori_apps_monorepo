import "dart:async";

import "package:flutter/material.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelPickerSection, ModelPickerSectionBuilder;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "model_picker_sheet.dart";

/// Composer header exposing the available agent / model / variant selections
/// as glass pill buttons ([PregoButtonsGlass]). Tapping a pill opens its
/// [PregoAnchorMenu] popup listing the pickable values (instead of a modal
/// bottom sheet).
///
/// The widget owns the menu contents, so it receives the selectable data and
/// the selection callbacks directly rather than a "open picker" callback.
class AgentModelButtons extends StatefulWidget {
  final List<AgentInfo> agents;
  final String? selectedAgent;
  final ValueChanged<String> onAgentSelected;

  final List<ProviderInfo> providers;
  final AgentModel? selectedAgentModel;
  final void Function({required String providerID, required String modelID}) onModelSelected;

  final List<SessionVariant> availableVariants;
  final ValueChanged<SessionVariant?> onVariantSelected;

  const AgentModelButtons({
    super.key,
    required this.agents,
    required this.selectedAgent,
    required this.onAgentSelected,
    required this.providers,
    required this.selectedAgentModel,
    required this.onModelSelected,
    required this.availableVariants,
    required this.onVariantSelected,
  });

  @override
  State<AgentModelButtons> createState() => _AgentModelButtonsState();
}

class _AgentModelButtonsState extends State<AgentModelButtons> {
  /// Pre-sorted, provider-grouped model sections for the model menu. Grouping/
  /// sorting a large catalog is non-trivial (the bottom sheet ran it in an
  /// isolate), so it is memoized here and only rebuilt when the provider
  /// catalog or selection changes — never on the frequent composer rebuilds
  /// that streaming triggers. Filtering by [_modelQuery] is a cheap per-build
  /// `contains` pass over these precomputed sections.
  List<ModelPickerSection> _modelSections = const [];

  @override
  void initState() {
    super.initState();
    _rebuildModelSections();
  }

  @override
  void didUpdateWidget(AgentModelButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.providers, widget.providers) ||
        oldWidget.selectedAgentModel?.providerID != widget.selectedAgentModel?.providerID ||
        oldWidget.selectedAgentModel?.modelID != widget.selectedAgentModel?.modelID) {
      _rebuildModelSections();
    }
  }

  void _rebuildModelSections() {
    final selected = widget.selectedAgentModel;
    _modelSections = const ModelPickerSectionBuilder().build(
      providers: widget.providers,
      selectedProviderID: selected?.providerID ?? "",
      selectedModelID: selected?.modelID ?? "",
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedAgentModel;
    final selectedAgent = widget.selectedAgent;
    final hasAgentSelection = widget.agents.isNotEmpty && selectedAgent != null;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Row(
        children: [
          if (hasAgentSelection) ...[
            Expanded(
              child: _AgentMenu(
                agents: widget.agents,
                selectedAgent: selectedAgent,
                onAgentSelected: widget.onAgentSelected,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _ModelMenu(
              sections: _modelSections,
              selected: selected,
              providers: widget.providers,
              onModelSelected: widget.onModelSelected,
              onSearchTap: _openModelSearchSheet,
            ),
          ),
          if (widget.availableVariants.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _VariantMenu(
                availableVariants: widget.availableVariants,
                selectedVariant: selected?.variant,
                onVariantSelected: widget.onVariantSelected,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Opens the full-screen, autofocused model search sheet. The menu itself is
  /// dismissed by the search affordance (via the [PregoMenuCustom] `close`
  /// callback) before this runs. Selecting there flows back through
  /// [onModelSelected].
  void _openModelSearchSheet() {
    final selected = widget.selectedAgentModel;
    unawaited(
      ModelPickerSheet.show(
        context,
        providers: widget.providers,
        selectedProviderID: selected?.providerID ?? "",
        selectedModelID: selected?.modelID ?? "",
        fullScreen: true,
        autofocusSearch: true,
        onModelChanged: ({required String providerID, required String modelID}) =>
            widget.onModelSelected(providerID: providerID, modelID: modelID),
      ),
    );
  }
}

// ── Menus ────────────────────────────────────────────────────────────────────

/// Agent-selection pill + its popup. Extracted as a widget (rather than a build
/// method) so it gets its own element subtree and only rebuilds with its inputs.
class _AgentMenu extends StatelessWidget {
  final List<AgentInfo> agents;
  final String selectedAgent;
  final ValueChanged<String> onAgentSelected;

  const _AgentMenu({
    required this.agents,
    required this.selectedAgent,
    required this.onAgentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      menuWidth: 240,
      menuMaxHeight: _pickerMaxHeight,
      triggerBuilder: (context, toggle) => PregoButtonsGlass(
        leadingIcon: Icons.smart_toy_outlined,
        label: selectedAgent,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionDetailPickerAgent),
        for (final agent in agents)
          PregoMenuItem(
            title: agent.name,
            subtitle: agent.description,
            isSelected: agent.name == selectedAgent,
            onTap: () => onAgentSelected(agent.name),
          ),
      ],
    );
  }
}

/// Model-selection pill + its quick-pick popup (search affordance pinned at the
/// top, then each provider's representative models).
class _ModelMenu extends StatelessWidget {
  final List<ModelPickerSection> sections;
  final AgentModel? selected;
  final List<ProviderInfo> providers;
  final void Function({required String providerID, required String modelID}) onModelSelected;
  final VoidCallback onSearchTap;

  const _ModelMenu({
    required this.sections,
    required this.selected,
    required this.providers,
    required this.onModelSelected,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    // Tapping the search affordance escalates into the full-screen search sheet
    // (see [_AgentModelButtonsState._openModelSearchSheet]). The affordance is a
    // custom entry so it can close the menu before the sheet rises.
    final entries = <PregoMenuEntry>[
      PregoMenuCustom(
        height: _ModelSearchAffordance.height,
        builder: (context, close) => _ModelSearchAffordance(
          onTap: () {
            close();
            onSearchTap();
          },
        ),
      ),
    ];
    for (final section in sections) {
      final models = section.models.where((model) => model.visibleByDefault).toList();
      if (models.isEmpty) continue;
      entries.add(PregoMenuLabel(text: section.providerName));
      for (final model in models) {
        entries.add(
          PregoMenuItem(
            title: model.displayName,
            subtitle: model.family,
            isSelected: section.providerID == selected?.providerID && model.modelID == selected?.modelID,
            onTap: () => onModelSelected(providerID: section.providerID, modelID: model.modelID),
          ),
        );
      }
    }

    return PregoAnchorMenu(
      menuWidth: 320,
      menuMaxHeight: _pickerMaxHeight,
      triggerBuilder: (context, toggle) => PregoButtonsGlass(
        leadingIcon: Icons.memory_outlined,
        label: _resolveModelName(context, providers: providers, selected: selected),
        onPressed: toggle,
      ),
      entriesBuilder: () => entries,
    );
  }
}

/// Variant-selection pill + its popup.
class _VariantMenu extends StatelessWidget {
  final List<SessionVariant> availableVariants;
  final String? selectedVariant;
  final ValueChanged<SessionVariant?> onVariantSelected;

  const _VariantMenu({
    required this.availableVariants,
    required this.selectedVariant,
    required this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      menuWidth: 220,
      menuMaxHeight: _pickerMaxHeight,
      triggerBuilder: (context, toggle) => PregoButtonsGlass(
        leadingIcon: Icons.speed_outlined,
        label: selectedVariant ?? loc.sessionDetailVariantDefault,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionDetailPickerVariant),
        PregoMenuItem(
          title: loc.sessionDetailVariantDefault,
          subtitle: null,
          isSelected: selectedVariant == null,
          onTap: () => onVariantSelected(null),
        ),
        for (final variant in availableVariants)
          PregoMenuItem(
            title: variant.id,
            subtitle: null,
            isSelected: variant.id == selectedVariant,
            onTap: () => onVariantSelected(variant),
          ),
      ],
    );
  }
}

/// A search-bar-styled tap target pinned at the top of the model popup. Tapping
/// it enters "search mode": the compact glass popup collapses and the roomy,
/// keyboard-friendly full-screen search sheet rises in its place. The popup
/// itself does not filter — searching happens in that sheet.
class _ModelSearchAffordance extends StatelessWidget {
  final VoidCallback onTap;

  const _ModelSearchAffordance({required this.onTap});

  /// The row's rendered height — the [_barHeight] bar plus the [_bottomGap] that
  /// separates it from the first provider heading. The glass popup budgets its
  /// height from what each row declares, so this is what the menu is told; the
  /// two constants below are the only things that decide it.
  static const double height = _barHeight + _bottomGap;
  static const double _barHeight = 40;
  static const double _bottomGap = 8;

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, _bottomGap),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _barHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: prego.colors.bgSurface1,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: prego.colors.textSecondary),
              const SizedBox(width: 8),
              Text(
                loc.sessionDetailModelSearch,
                style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared menu pieces ─────────────────────────────────────────────────────

/// How tall a composer picker may grow before its rows start to scroll. The menu
/// sizes itself to its rows below this; the cap only stops a long catalog (or a
/// project with many agents) from swallowing the conversation behind it.
const double _pickerMaxHeight = 380;

String _resolveModelName(
  BuildContext context, {
  required List<ProviderInfo> providers,
  required AgentModel? selected,
}) {
  final providerID = selected?.providerID;
  final modelID = selected?.modelID;
  final fallback = context.loc.sessionDetailModelFallback;
  if (providerID == null || modelID == null) return fallback;
  for (final provider in providers) {
    if (provider.id == providerID) {
      final model = provider.models[modelID];
      if (model != null) return model.name;
    }
  }
  return modelID.isNotEmpty ? modelID : fallback;
}
