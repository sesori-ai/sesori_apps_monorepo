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
import "composer_surface_style.dart";
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

  /// Status chips after the selectors, such as the session's YOLO chip. Keep
  /// them compact on touch, where the pickers share the remaining width.
  required final List<Widget> trailing,
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
    Widget slot(Widget menu) => _pickerSlot(compact: compact, child: menu);
    final selectors = [
      if (hasAgentSelection)
        slot(
          _AgentMenu(
            surfaceStyle: widget.surfaceStyle,
            hugLabel: compact,
            agents: widget.agents,
            selectedAgent: selectedAgent,
            onAgentSelected: widget.onAgentSelected,
          ),
        ),
      slot(
        _ModelMenu(
          surfaceStyle: widget.surfaceStyle,
          hugLabel: compact,
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
            hugLabel: compact,
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
      ...widget.trailing,
    ];
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2),
      child: Row(spacing: 8, children: selectors),
    );
  }
}

/// What a session that cannot prompt ran with, where its composer would sit:
/// the [AgentModelButtons] pills, showing their values without opening any
/// picker. A value that is unknown leaves its pill out.
class const ReadOnlyAgentModelPills({
  super.key,
  required final List<AgentInfo> agents,
  required final String? agent,
  required final List<ProviderInfo> providers,
  required final AgentModel? model,

  /// Whether each pill hugs its label at the leading edge (pointer shells)
  /// instead of sharing the strip's width equally (touch shells).
  required final bool compact,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final agent = this.agent;
    final model = this.model;
    final variant = model?.variant;
    Widget pill({required IconData icon, required String label}) => _pickerSlot(
      compact: compact,
      child: _pickerButton(
        hugLabel: compact,
        leadingIcon: icon,
        label: label,
        surfaceStyle: PregoComposerSurfaceStyle.subtle,
        onPressed: null,
      ),
    );
    final pills = [
      // As in the composer, a harness with a single agent has none to name.
      if (agents.length > 1 && agent != null) pill(icon: TablerRegular.robot, label: agent),
      if (model != null)
        pill(
          icon: TablerRegular.cpu,
          label: _resolveModelName(context, providers: providers, selected: model),
        ),
      if (variant != null) pill(icon: TablerRegular.gauge, label: variant),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();
    return DecoratedBox(
      decoration: composerScrimDecoration(prego: context.prego),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 8),
        child: Row(spacing: 8, children: pills),
      ),
    );
  }
}

/// A pill's share of the strip: a pointer (compact) pill hugs its label up to a
/// cap, while touch pills split the width equally.
Widget _pickerSlot({required bool compact, required Widget child}) {
  if (!compact) return Expanded(child: child);
  return Flexible(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: child,
    ),
  );
}

/// A picker's glyphs, caret and padding take about 68 points; below this width
/// its label would show only a few characters.
const double _minLabelledPickerWidth = 96;

/// The pill for one picker. Any pill drops to its glyph when its share of the
/// row is too narrow for a readable label. A labelled pointer pill hugs its
/// label, while a touch pill fills its share. Without [onPressed] the pill
/// only shows its value.
Widget _pickerButton({
  required bool hugLabel,
  required IconData leadingIcon,
  required String label,
  required PregoComposerSurfaceStyle surfaceStyle,
  required VoidCallback? onPressed,
}) {
  Widget pill({required bool showLabel}) => PregoPickerButton(
    leadingIcon: leadingIcon,
    label: label,
    showLabel: showLabel,
    surfaceStyle: surfaceStyle,
    onPressed: onPressed,
  );
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < _minLabelledPickerWidth) return pill(showLabel: false);
      final labelled = pill(showLabel: true);
      return hugLabel ? IntrinsicWidth(child: labelled) : labelled;
    },
  );
}

// ── Menus ────────────────────────────────────────────────────────────────────

/// Agent-selection pill + its popup. Extracted as a widget (rather than a build
/// method) so it gets its own element subtree and only rebuilds with its inputs.
class const _AgentMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final bool hugLabel,
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
      triggerBuilder: (context, toggle) => _pickerButton(
        hugLabel: hugLabel,
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
  required final bool hugLabel,
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
      triggerBuilder: (context, toggle) => _pickerButton(
        hugLabel: hugLabel,
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
  required final bool hugLabel,
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
      triggerBuilder: (context, toggle) => _pickerButton(
        hugLabel: hugLabel,
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
      // The yellowest warning step per theme; dark utility scales run in reverse.
      FastModeControl.on => (
        TablerRegular.bolt,
        switch (prego.colors.brightness) {
          Brightness.dark => prego.colors.utilityWarning700,
          Brightness.light => prego.colors.utilityWarning500,
        },
      ),
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
