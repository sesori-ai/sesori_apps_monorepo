import "dart:async";

import "package:flutter/material.dart";
import "package:liquid_glass_widgets/liquid_glass_widgets.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelPickerSection, ModelPickerSectionBuilder;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../extensions/build_context_x.dart";
import "model_picker_sheet.dart";

/// Composer header exposing the agent / model / variant selection as three
/// liquid-glass pill buttons. Tapping a pill morphs it into a [GlassMenu]
/// popup listing the pickable values (instead of a modal bottom sheet).
///
/// The widget owns the menu contents, so it receives the selectable data and
/// the selection callbacks directly rather than a "open picker" callback.
class AgentModelButtons extends StatefulWidget {
  final List<AgentInfo> agents;
  final String selectedAgent;
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

  /// Drives the model menu imperatively so the in-popup search affordance can
  /// dismiss the glass popup before the full-screen search sheet rises.
  final GlassMenuController _modelMenuController = GlassMenuController();

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
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Expanded(child: _buildAgentMenu(context)),
          const SizedBox(width: 8),
          Expanded(child: _buildModelMenu(context)),
          if (widget.availableVariants.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(child: _buildVariantMenu(context)),
          ],
        ],
      ),
    );
  }

  // ── Menus ──────────────────────────────────────────────────────────────────

  Widget _buildAgentMenu(BuildContext context) {
    final loc = context.loc;
    return GlassMenu(
      menuWidth: 240,
      menuHeight: widget.agents.length > 6 ? 320 : null,
      menuBorderRadius: 24,
      autoAdjustToScreen: true,
      menuPadding: const EdgeInsets.all(12),
      settings: _menuGlass(context),
      triggerBuilder: (context, toggle) => _Trigger(
        icon: Icons.smart_toy_outlined,
        label: widget.selectedAgent,
        onTap: toggle,
      ),
      items: [
        _menuLabel(context, text: loc.sessionDetailPickerAgent),
        for (final agent in widget.agents)
          _menuItem(
            context,
            title: agent.name,
            subtitle: agent.description,
            isSelected: agent.name == widget.selectedAgent,
            onTap: () => widget.onAgentSelected(agent.name),
          ),
      ],
    );
  }

  Widget _buildModelMenu(BuildContext context) {
    final selected = widget.selectedAgentModel;

    // The compact popup is a quick-pick list: a search affordance pinned at the
    // top, then each provider's representative models. Tapping the affordance
    // escalates into the full-screen search sheet (see [_openModelSearchSheet]).
    final items = <Widget>[_buildModelSearchAffordance(context)];
    var modelRows = 0;
    var headerRows = 0;
    for (final section in _modelSections) {
      final models = section.models.where((model) => model.visibleByDefault).toList();
      if (models.isEmpty) continue;
      headerRows++;
      items.add(_menuLabel(context, text: section.providerName));
      for (final model in models) {
        modelRows++;
        items.add(
          _menuItem(
            context,
            title: model.displayName,
            subtitle: model.family,
            isSelected: section.providerID == selected?.providerID && model.modelID == selected?.modelID,
            onTap: () => widget.onModelSelected(providerID: section.providerID, modelID: model.modelID),
          ),
        );
      }
    }

    return GlassMenu(
      controller: _modelMenuController,
      menuWidth: 320,
      menuHeight: _modelMenuHeight(modelRows: modelRows, headerRows: headerRows),
      menuBorderRadius: 24,
      autoAdjustToScreen: true,
      menuPadding: const EdgeInsets.all(12),
      settings: _menuGlass(context),
      triggerBuilder: (context, toggle) => _Trigger(
        icon: Icons.memory_outlined,
        label: _resolveModelName(context),
        onTap: toggle,
      ),
      items: items,
    );
  }

  /// A search-bar-styled tap target pinned at the top of the model popup.
  /// Tapping it enters "search mode": the compact glass popup collapses and the
  /// roomy, keyboard-friendly full-screen search sheet rises in its place. The
  /// popup itself does not filter — searching happens in that sheet.
  Widget _buildModelSearchAffordance(BuildContext context) {
    final prego = context.prego;
    final loc = context.loc;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
      child: GestureDetector(
        onTap: _openModelSearchSheet,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: prego.colors.bgPrimary,
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

  /// Collapses the glass popup and opens the full-screen, autofocused model
  /// search sheet. Selecting there flows back through [onModelSelected].
  void _openModelSearchSheet() {
    _modelMenuController.close();
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

  /// Fixed (always-scrollable) model-menu height that fits the quick-pick rows
  /// but caps so the popup never fills the screen; results scroll inside.
  double _modelMenuHeight({required int modelRows, required int headerRows}) {
    const searchHeight = 52.0;
    const itemHeight = 48.0;
    const headerHeight = 30.0;
    const verticalPadding = 36.0;
    final natural = searchHeight + modelRows * itemHeight + headerRows * headerHeight + verticalPadding;
    return natural.clamp(120.0, 380.0);
  }

  Widget _buildVariantMenu(BuildContext context) {
    final loc = context.loc;
    final selectedVariant = widget.selectedAgentModel?.variant;
    return GlassMenu(
      menuWidth: 220,
      menuHeight: widget.availableVariants.length > 6 ? 320 : null,
      menuBorderRadius: 24,
      autoAdjustToScreen: true,
      menuPadding: const EdgeInsets.all(12),
      settings: _menuGlass(context),
      triggerBuilder: (context, toggle) => _Trigger(
        icon: Icons.speed_outlined,
        label: selectedVariant ?? loc.sessionDetailVariantDefault,
        onTap: toggle,
      ),
      items: [
        _menuLabel(context, text: loc.sessionDetailPickerVariant),
        _menuItem(
          context,
          title: loc.sessionDetailVariantDefault,
          subtitle: null,
          isSelected: selectedVariant == null,
          onTap: () => widget.onVariantSelected(null),
        ),
        for (final variant in widget.availableVariants)
          _menuItem(
            context,
            title: variant.id,
            subtitle: null,
            isSelected: variant.id == selectedVariant,
            onTap: () => widget.onVariantSelected(variant),
          ),
      ],
    );
  }

  // ── Shared menu pieces ───────────────────────────────────────────────────

  Widget _menuLabel(BuildContext context, {required String text}) {
    final prego = context.prego;
    return GlassMenuLabel(
      title: text,
      style: prego.textTheme.textXs.medium.copyWith(
        color: prego.colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }

  GlassMenuItem _menuItem(
    BuildContext context, {
    required String title,
    required String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final prego = context.prego;
    return GlassMenuItem(
      title: title,
      subtitle: subtitle,
      titleStyle: prego.textTheme.textSm.medium.copyWith(color: prego.colors.textPrimary),
      subtitleStyle: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textSecondary),
      trailing: isSelected ? Icon(Icons.check, size: 16, color: prego.colors.bgBrandSolid) : null,
      onTap: onTap,
    );
  }

  LiquidGlassSettings _menuGlass(BuildContext context) {
    final colors = context.prego.colors;
    return LiquidGlassSettings(
      glassColor: colors.buttonGlassPrimaryBackground,
    );
  }

  String _resolveModelName(BuildContext context) {
    final providerID = widget.selectedAgentModel?.providerID;
    final modelID = widget.selectedAgentModel?.modelID;
    final fallback = context.loc.sessionDetailModelFallback;
    if (providerID == null || modelID == null) return fallback;
    for (final provider in widget.providers) {
      if (provider.id == providerID) {
        final model = provider.models[modelID];
        if (model != null) return model.name;
      }
    }
    return modelID.isNotEmpty ? modelID : fallback;
  }
}

/// A single glass pill that triggers one of the menus. Fills its [Expanded]
/// slot (so long labels ellipsize) and shows a caret to signal it opens a menu.
class _Trigger extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Trigger({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final foreground = prego.colors.textSecondary;
    return GlassButton.custom(
      onTap: onTap,
      width: double.infinity,
      height: 36,
      shape: const LiquidRoundedRectangle(borderRadius: 18),
      useOwnLayer: true,
      settings: LiquidGlassSettings(glassColor: prego.colors.buttonGlassPrimaryBackground),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: prego.textTheme.textXs.medium.copyWith(color: foreground),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.unfold_more, size: 14, color: foreground),
          ],
        ),
      ),
    );
  }
}
