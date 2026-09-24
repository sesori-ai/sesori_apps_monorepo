import "dart:async";

import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show
        FastModeControl,
        FastModeToggleApply,
        FastModeToggleConfirmCacheReset,
        FastModeToggleDecision,
        FastModeToggleUnavailable,
        ModelPickerSection,
        ModelPickerSectionBuilder;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "model_picker.dart";

/// Composer header exposing the available agent / model / variant selections
/// as solid pill buttons ([PregoPickerButton]). Tapping a pill opens its popup
/// beside it: a [PregoAnchorMenu] for agents and variants, and a searchable
/// [ModelPicker] for models.
///
/// The widget owns the menu contents, so it receives the selectable data and
/// the selection callbacks directly rather than a "open picker" callback.
class const AgentModelButtons({
  super.key,
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final List<AgentInfo> agents,
  required final String? selectedAgent,
  required final ValueChanged<String> onAgentSelected,
  required final List<ProviderInfo> providers,
  required final AgentModel? selectedAgentModel,
  required final void Function({required String providerID, required String modelID}) onModelSelected,
  required final List<SessionVariant> availableVariants,
  required final ValueChanged<SessionVariant> onVariantSelected,

  /// How the fast-mode pill shows for the selected model.
  required final FastModeControl fastModeControl,

  /// Decides what a tap on the fast-mode pill does, read at tap time.
  required final FastModeToggleDecision? Function() decideFastModeToggle,
  required final ValueChanged<bool> onFastModeChanged,

  /// Whether each selector hugs its label at the leading edge (pointer shells)
  /// instead of sharing the strip's width equally (touch shells).
  required final bool compact,
}) extends StatefulWidget {
  @override
  State<AgentModelButtons> createState() => _AgentModelButtonsState();
}

class _AgentModelButtonsState() extends State<AgentModelButtons> {
  /// Pre-sorted, provider-grouped model sections for the model picker.
  /// Grouping/sorting a large catalog is non-trivial, so it is memoized here
  /// and only rebuilt when the provider catalog or selection changes — never
  /// on the frequent composer rebuilds that streaming triggers. The picker's
  /// search is a cheap `contains` pass over these precomputed sections.
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
    // One agent is no choice: the entry appears only when there is another.
    final hasAgentSelection = widget.agents.length > 1 && selectedAgent != null;
    final compact = widget.compact;
    Widget slot(Widget menu) => compact
        ? Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: IntrinsicWidth(child: menu),
            ),
          )
        : Expanded(child: menu);
    final selectors = [
      if (hasAgentSelection)
        slot(
          _AgentMenu(
            surfaceStyle: widget.surfaceStyle,
            agents: widget.agents,
            selectedAgent: selectedAgent,
            onAgentSelected: widget.onAgentSelected,
          ),
        ),
      slot(
        _ModelMenu(
          surfaceStyle: widget.surfaceStyle,
          sections: _modelSections,
          selected: selected,
          providers: widget.providers,
          onModelSelected: widget.onModelSelected,
        ),
      ),
      if (widget.availableVariants.isNotEmpty)
        slot(
          _VariantMenu(
            surfaceStyle: widget.surfaceStyle,
            availableVariants: widget.availableVariants,
            selectedVariant: selected?.variant,
            onVariantSelected: widget.onVariantSelected,
          ),
        ),
      if (widget.fastModeControl != FastModeControl.hidden)
        _FastModeButton(
          surfaceStyle: widget.surfaceStyle,
          control: widget.fastModeControl,
          decide: widget.decideFastModeToggle,
          onFastModeChanged: widget.onFastModeChanged,
        ),
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Row(spacing: 8, children: selectors),
    );
  }
}

// ── Menus ────────────────────────────────────────────────────────────────────

/// Agent-selection pill + its popup. Extracted as a widget (rather than a build
/// method) so it gets its own element subtree and only rebuilds with its inputs.
class const _AgentMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final List<AgentInfo> agents,
  required final String selectedAgent,
  required final ValueChanged<String> onAgentSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 240,
      acquireOpenLease: null,
      menuMaxHeight: PregoPickerPopover.maxHeight,
      triggerBuilder: (context, toggle) => PregoPickerButton(
        leadingIcon: TablerRegular.robot,
        label: selectedAgent,
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionDetailPickerAgent),
        for (final agent in agents)
          PregoMenuItem(
            title: agent.name,
            subtitle: agent.description,
            isSelected: agent.name == selectedAgent,
            shortcutLabel: null,
            onTap: () => onAgentSelected(agent.name),
          ),
      ],
    );
  }
}

/// Model-selection pill + its searchable picker.
class const _ModelMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final List<ModelPickerSection> sections,
  required final AgentModel? selected,
  required final List<ProviderInfo> providers,
  required final void Function({required String providerID, required String modelID}) onModelSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoPickerPopover(
      pointerWidth: 300,
      onClosed: null,
      triggerBuilder: (context, toggle) => PregoPickerButton(
        leadingIcon: TablerRegular.cpu,
        label: _resolveModelName(context, providers: providers, selected: selected),
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) => ModelPicker(
        sections: sections,
        selected: selected,
        onModelSelected: ({required String providerID, required String modelID}) {
          close();
          onModelSelected(providerID: providerID, modelID: modelID);
        },
        onClose: close,
      ),
    );
  }
}

/// Variant-selection pill + its popup.
class const _VariantMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final List<SessionVariant> availableVariants,
  required final String? selectedVariant,
  required final ValueChanged<SessionVariant> onVariantSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return PregoAnchorMenu(
      flat: true,
      menuWidth: 220,
      acquireOpenLease: null,
      menuMaxHeight: PregoPickerPopover.maxHeight,
      reverseScroll: true,
      triggerBuilder: (context, toggle) => PregoPickerButton(
        leadingIcon: TablerRegular.gauge,
        label: selectedVariant ?? availableVariants.first.id,
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      entriesBuilder: () => [
        PregoMenuLabel(text: loc.sessionDetailPickerVariant),
        // Catalogs are strongest-first; keep those efforts nearest the composer.
        for (final variant in availableVariants.reversed)
          PregoMenuItem(
            title: variant.id,
            subtitle: null,
            isSelected: variant.id == selectedVariant,
            shortcutLabel: null,
            onTap: () => onVariantSelected(variant),
          ),
      ],
    );
  }
}

/// Square ⚡ pill that toggles fast mode. It is highlighted while on and dimmed
/// while the account cannot use fast mode; a tap then explains why.
class const _FastModeButton({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final FastModeControl control,
  required final FastModeToggleDecision? Function() decide,
  required final ValueChanged<bool> onFastModeChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final label = context.loc.sessionDetailFastMode;
    final borderRadius = BorderRadius.circular(PregoRadius.full);
    final (icon, color) = switch (control) {
      FastModeControl.on => (TablerRegular.bolt, prego.colors.fgBrandPrimary),
      FastModeControl.off => (TablerRegular.bolt, prego.colors.textSecondary),
      FastModeControl.unavailable || FastModeControl.hidden => (TablerRegular.bolt_off, prego.colors.fgDisabled),
    };
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        toggled: control == FastModeControl.on,
        label: label,
        onTap: () => unawaited(_onTap(context)),
        excludeSemantics: true,
        child: SizedBox.square(
          dimension: 36,
          child: DecoratedBox(
            decoration: pregoComposerSurfaceDecoration(prego: prego, style: surfaceStyle, borderRadius: borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: Material(
                color: Colors.transparent,
                borderRadius: borderRadius,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  onTap: () => unawaited(_onTap(context)),
                  borderRadius: borderRadius,
                  child: Center(
                    child: Icon(icon, size: PregoIconSize.sm, color: color),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    switch (decide()) {
      case null:
        return;
      case FastModeToggleApply(:final fastMode):
        onFastModeChanged(fastMode);
      case FastModeToggleUnavailable(:final reason):
        final loc = context.loc;
        PregoPopupAlertPresenter.of(context).show(
          title: loc.sessionDetailFastModeUnavailableTitle,
          variant: PregoPopupAlertsNotificationsVariant.error,
          content: PregoPopupAlertContent(
            message: switch (reason) {
              FastModeUnavailableReason.extraUsageDisabled => loc.sessionDetailFastModeUnavailableExtraUsageDisabled,
              FastModeUnavailableReason.notOnPlan => loc.sessionDetailFastModeUnavailableNotOnPlan,
              FastModeUnavailableReason.disabledByOrganization =>
                loc.sessionDetailFastModeUnavailableDisabledByOrganization,
              FastModeUnavailableReason.unknown => loc.sessionDetailFastModeUnavailableUnknown,
            },
          ),
        );
      case FastModeToggleConfirmCacheReset(:final fastMode):
        final confirmed = await _confirmCacheReset(context: context, fastMode: fastMode);
        if (confirmed ?? false) onFastModeChanged(fastMode);
    }
  }

  Future<bool?> _confirmCacheReset({required BuildContext context, required bool fastMode}) {
    final loc = context.loc;
    final prego = context.prego;
    return showPregoModal<bool>(
      context: context,
      title: loc.sessionDetailFastModeConfirmTitle,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PregoSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fastMode ? loc.sessionDetailFastModeConfirmEnableBody : loc.sessionDetailFastModeConfirmDisableBody,
              style: prego.textTheme.textSm.regular.copyWith(color: prego.colors.textSecondary),
            ),
            const SizedBox(height: PregoSpacing.x2l),
            PregoButtonsSolid(
              key: const Key("fast_mode_confirm"),
              label: loc.sessionDetailFastModeConfirmAction,
              hierarchy: PregoButtonsSolidHierarchy.primaryAlt,
              size: PregoButtonsSolidSize.xl,
              fullWidth: true,
              onPressed: () => sheetContext.pop(true),
            ),
            const SizedBox(height: PregoSpacing.md),
            PregoButtonsSolid(
              key: const Key("fast_mode_cancel"),
              label: loc.sessionDetailFastModeCancel,
              hierarchy: PregoButtonsSolidHierarchy.tertiary,
              size: PregoButtonsSolidSize.xl,
              fullWidth: true,
              onPressed: () => sheetContext.pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared menu pieces ─────────────────────────────────────────────────────

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
