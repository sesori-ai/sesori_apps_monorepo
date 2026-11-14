import "dart:async";

import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show FastModeControl, FastModeToggleDecision, ModelOrbits, ModelPickerSection, ModelPickerSectionBuilder;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "fast_mode_toggle.dart";
import "model_effort/medallion_chip.dart";
import "model_effort/orbits_picker.dart";
import "model_picker.dart";

/// Composer header exposing the available agent / model / variant selections
/// as solid pill buttons ([PregoPickerButton]). Tapping a pill opens its popup
/// beside it: a [PregoAnchorMenu] for agents and variants, and a searchable
/// [ModelPicker] for models.
///
/// On touch, a catalog the orbits picker can draw ([modelOrbits]) gets one
/// [MedallionChip] in place of the model, variant and fast-mode pills.
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
  required final void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required final List<SessionVariant> availableVariants,
  required final ValueChanged<SessionVariant> onVariantSelected,

  /// The orbits picker's content, or null when the catalog does not fit it.
  required final ModelOrbits? modelOrbits,

  /// How the fast-mode pill shows for the selected model.
  required final FastModeControl fastModeControl,

  /// Decides what a tap on the fast-mode pill does, read at tap time.
  required final FastModeToggleDecision? Function() decideFastModeToggle,
  required final ValueChanged<bool> onFastModeChanged,

  /// Whether each selector hugs its label at the leading edge (pointer shells)
  /// instead of sharing the strip's width equally (touch shells).
  required final bool compact,

  /// Shows the committed selections exactly as the live pills draw them,
  /// without opening any picker or toggling fast mode.
  required final bool readOnly,

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
    // Locking leaves each pill's geometry untouched, so nothing shifts as the
    // options turn read-only, and blocks its taps, hover cursor, keyboard focus
    // and actions.
    Widget lock(Widget control) => ExcludeFocus(
      excluding: widget.readOnly,
      child: IgnorePointer(ignoring: widget.readOnly, child: control),
    );
    Widget slot(Widget menu) => _pickerSlot(compact: compact, child: lock(menu));
    // The pointer layout keeps its pills.
    final orbits = compact ? null : widget.modelOrbits;
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
      if (orbits != null)
        // The plate hugs its text rather than sharing the strip.
        Flexible(
          child: lock(
            _OrbitsMenu(
              orbits: orbits,
              sections: _modelSections,
              selected: selected,
              onModelSelected: widget.onModelSelected,
              fastModeControl: widget.fastModeControl,
              decideFastModeToggle: widget.decideFastModeToggle,
              onFastModeChanged: widget.onFastModeChanged,
            ),
          ),
        )
      else ...[
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
          lock(
            _FastModeButton(
              surfaceStyle: widget.surfaceStyle,
              control: widget.fastModeControl,
              decide: widget.decideFastModeToggle,
              onFastModeChanged: widget.onFastModeChanged,
            ),
          ),
      ],
      ...widget.trailing,
    ];
    final row = _pillRow(compact: compact, reachesLayerBottom: false, pills: selectors);
    // Under a pointer they sit on the composer's action row, in its line.
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    if (PregoInteractionScope.of(context) == PregoInteractionMode.pointer) return row;
    return Padding(padding: const EdgeInsetsDirectional.only(top: 6, bottom: 2), child: row);
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
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
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
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 8),
      // The bottom-most row: its halo runs on to the bottom edge, so nothing
      // shows below the pills.
      child: _pillRow(compact: compact, reachesLayerBottom: true, pills: pills),
    );
  }
}

/// The pills under one [PregoPageHalo], so no transcript words show through the
/// gaps between them. Hugging pointer pills keep the halo to their own width,
/// leading-aligned; touch pills fill the strip, and the halo with them.
Widget _pillRow({required bool compact, required bool reachesLayerBottom, required List<Widget> pills}) {
  final halo = PregoPageHalo(
    radius: PregoRadius.full,
    reachesLayerBottom: reachesLayerBottom,
    child: Row(mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max, spacing: 8, children: pills),
  );
  return compact ? Align(alignment: AlignmentDirectional.centerStart, heightFactor: 1, child: halo) : halo;
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
  required bool pointer,
}) {
  Widget pill({required bool showLabel}) => PregoPickerButton(
    leadingIcon: leadingIcon,
    label: label,
    showLabel: showLabel,
    surfaceStyle: surfaceStyle,
    onPressed: onPressed,
    plain: pointer,
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
      menuMaxHeight: PregoPickerPopover.maxHeight,
      triggerBuilder: (context, toggle) => _pickerButton(
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
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
  required final void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoPickerPopover(
      pointerWidth: 300,
      onClosed: null,
      triggerBuilder: (context, toggle) => _pickerButton(
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
        hugLabel: hugLabel,
        leadingIcon: TablerRegular.cpu,
        label: _resolveModelName(context, providers: providers, selected: selected),
        surfaceStyle: surfaceStyle,
        onPressed: toggle,
      ),
      contentBuilder: (context, close) =>
          _modelPicker(sections: sections, selected: selected, onModelSelected: onModelSelected, close: close),
    );
  }
}

Widget _modelPicker({
  required List<ModelPickerSection> sections,
  required AgentModel? selected,
  required void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required VoidCallback close,
}) => ModelPicker(
  sections: sections,
  selected: selected,
  onModelSelected: ({required String providerID, required String modelID, required SessionVariant? variant}) {
    close();
    onModelSelected(providerID: providerID, modelID: modelID, variant: variant);
  },
  onClose: close,
);

/// The medallion chip and the orbits picker it opens, with the searchable
/// [ModelPicker] behind the picker's "All N models".
class const _OrbitsMenu({
  required final ModelOrbits orbits,
  required final List<ModelPickerSection> sections,
  required final AgentModel? selected,
  required final void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required final FastModeControl fastModeControl,
  required final FastModeToggleDecision? Function() decideFastModeToggle,
  required final ValueChanged<bool> onFastModeChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PregoPickerPopover(
      pointerWidth: 300,
      onClosed: null,
      triggerBuilder: (context, toggle) => _OrbitsChip(
        orbits: orbits,
        onModelSelected: onModelSelected,
        fastModeControl: fastModeControl,
        decideFastModeToggle: decideFastModeToggle,
        onFastModeChanged: onFastModeChanged,
        onShowAllModels: () {
          // The list wants the keyboard's space, as the model pill's does.
          FocusManager.instance.primaryFocus?.unfocus();
          toggle();
        },
      ),
      contentBuilder: (context, close) =>
          _modelPicker(sections: sections, selected: selected, onModelSelected: onModelSelected, close: close),
    );
  }
}

/// The chip as a button. A press opens the orbits picker at once and hands
/// the finger over, so the same press slides on into it; a tap leaves the
/// picker open for a second tap.
class const _OrbitsChip({
  required final ModelOrbits orbits,
  required final void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required final FastModeControl fastModeControl,
  required final FastModeToggleDecision? Function() decideFastModeToggle,
  required final ValueChanged<bool> onFastModeChanged,
  required final VoidCallback onShowAllModels,
}) extends StatefulWidget {
  @override
  State<_OrbitsChip> createState() => _OrbitsChipState();
}

class _OrbitsChipState() extends State<_OrbitsChip> {
  /// The finger that opened the picker, while it is down.
  OrbitsPointerHandoff? _handoff;

  /// Whether a keyboard has focused the chip, which then shows Prego's ring.
  bool _focused = false;

  void _open({required OrbitsPointerHandoff? handoff}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    unawaited(
      showOrbitsPicker(
        context: context,
        anchorRect: box.localToGlobal(Offset.zero) & box.size,
        handoff: handoff,
        orbits: widget.orbits,
        onModelSelected: widget.onModelSelected,
        onShowAllModels: widget.onShowAllModels,
        fastModeControl: widget.fastModeControl,
        decideFastModeToggle: widget.decideFastModeToggle,
        onFastModeChanged: widget.onFastModeChanged,
      ),
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_handoff != null) return;
    final handoff = OrbitsPointerHandoff(pointer: event.pointer, start: event.position);
    _handoff = handoff;
    _open(handoff: handoff);
  }

  /// The hand-off [event] belongs to; [ends] lets go of it.
  OrbitsPointerHandoff? _handoffOf({required PointerEvent event, required bool ends}) {
    final handoff = _handoff;
    if (handoff == null || handoff.pointer != event.pointer) return null;
    if (ends) _handoff = null;
    return handoff;
  }

  @override
  Widget build(BuildContext context) {
    final orbits = widget.orbits;
    final level = orbits.currentLevel;
    final loc = context.loc;
    final colors = context.prego.colors;
    // Enter and Space open the picker from a focused chip, as they did the pills.
    final activate = CallbackAction<Intent>(onInvoke: (_) => _open(handoff: null));
    return Semantics(
      button: true,
      label: level == null ? orbits.current.name : loc.orbitsPickerLevel(orbits.current.name, level.wireId),
      onTap: () => _open(handoff: null),
      excludeSemantics: true,
      // Part of the composer: pressing it leaves the prompt field focused, so
      // an open keyboard stays up and the chip stays under the finger.
      child: TextFieldTapRegion(
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: (event) => _handoffOf(event: event, ends: false)?.move(position: event.position),
          onPointerUp: (event) => _handoffOf(event: event, ends: true)?.release(position: event.position),
          onPointerCancel: (event) => _handoffOf(event: event, ends: true)?.cancel(),
          child: FocusableActionDetector(
            onFocusChange: (focused) => setState(() => _focused = focused),
            actions: {ActivateIntent: activate, ButtonActivateIntent: activate},
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MedallionChip.height / 2),
                boxShadow: _focused
                    ? [
                        BoxShadow(color: colors.focusRing, spreadRadius: 4),
                        BoxShadow(color: colors.bgSurface1, spreadRadius: 2),
                      ]
                    : null,
              ),
              child: MedallionChip(orbits: orbits, fast: widget.fastModeControl == FastModeControl.on),
            ),
          ),
        ),
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
      menuMaxHeight: PregoPickerPopover.maxHeight,
      reverseScroll: true,
      triggerBuilder: (context, toggle) => _pickerButton(
        // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
        pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
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
    // The size and corners of the row's other square pill, `PregoComposerChip`.
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    final borderRadius = BorderRadius.circular(pointer ? PregoRadius.md : PregoRadius.full);
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
          dimension: pointer ? 28 : 36,
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

  Future<void> _onTap(BuildContext context) =>
      toggleFastMode(context: context, decide: decide, onFastModeChanged: onFastModeChanged);
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
