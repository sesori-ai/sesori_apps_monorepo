import "dart:async";

import "package:flutter/services.dart" show HapticFeedback;
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show
        EffortLevel,
        FastModeControl,
        FastModeToggleDecision,
        ModelOrbits,
        ModelPickerSection,
        ModelPickerSectionBuilder;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../extensions/build_context_x.dart";
import "composer_chip_presence.dart";
import "fast_mode_toggle.dart";
import "model_effort/model_effort_chip.dart";
import "model_effort/orbits_picker.dart";
import "model_picker.dart";

/// Composer header exposing the agent and the model with its effort as solid
/// pill buttons. The model and its effort always show and pick together: one
/// control reading `Opus 5.5 · High` opens the searchable [ModelPicker], whose
/// selected row sets the effort.
///
/// On touch that control is a [ModelEffortChip] leading the row, with the
/// agent pill, the fast-mode pill and [trailing] chips at its end. A catalog
/// the orbits picker can draw ([modelOrbits]) opens the orbits picker from the
/// chip instead, which also covers fast mode. Under a pointer it is a pill like
/// the agent's.
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
  required final ModelSelectionHandler onModelSelected,

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

  /// A status chip after [trailing] that comes and goes while the composer is
  /// up, such as the session's wake-ups, or null while there is none. It grows
  /// in and folds away with its gap, so the pickers ease rather than jump.
  required final Widget? transientTrailing,
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
    // One agent is no choice: the entry appears only when there is another.
    final selectedAgent = widget.agents.length > 1 ? widget.selectedAgent : null;
    final compact = widget.compact;
    // Locking leaves each pill's geometry untouched, so nothing shifts as the
    // options turn read-only, and blocks its taps, hover cursor, keyboard focus
    // and actions. Each pill carries its own halo.
    Widget lock(Widget control) => _pillHalo(
      reachesLayerBottom: false,
      child: ExcludeFocus(
        excluding: widget.readOnly,
        child: IgnorePointer(ignoring: widget.readOnly, child: control),
      ),
    );
    Widget slot(Widget menu) => _pickerSlot(compact: compact, child: lock(menu));
    Widget agentMenu({required String agent, required bool hugLabel}) => _AgentMenu(
      surfaceStyle: widget.surfaceStyle,
      hugLabel: hugLabel,
      agents: widget.agents,
      selectedAgent: agent,
      onAgentSelected: widget.onAgentSelected,
    );
    // The pointer layout keeps its pills.
    final orbits = compact ? null : widget.modelOrbits;
    final Widget modelMenu = orbits != null
        ? _OrbitsMenu(
            surfaceStyle: widget.surfaceStyle,
            readOnly: widget.readOnly,
            orbits: orbits,
            sections: _modelSections,
            selected: selected,
            onModelSelected: widget.onModelSelected,
            fastModeControl: widget.fastModeControl,
            decideFastModeToggle: widget.decideFastModeToggle,
            onFastModeChanged: widget.onFastModeChanged,
          )
        : _ModelEffortMenu(
            surfaceStyle: widget.surfaceStyle,
            compact: compact,
            readOnly: widget.readOnly,
            sections: _modelSections,
            selected: selected,
            providers: widget.providers,
            onModelSelected: widget.onModelSelected,
          );
    // The orbits picker carries fast mode; any other model control leaves it
    // to its own pill.
    final fastModeButton = orbits != null || widget.fastModeControl == FastModeControl.hidden
        ? null
        : lock(
            _FastModeButton(
              surfaceStyle: widget.surfaceStyle,
              control: widget.fastModeControl,
              decide: widget.decideFastModeToggle,
              onFastModeChanged: widget.onFastModeChanged,
            ),
          );
    final selectors = [
      if (compact) ...[
        if (selectedAgent != null) slot(agentMenu(agent: selectedAgent, hugLabel: true)),
        slot(modelMenu),
      ] else ...[
        // The chip leads and hugs its text; everything else on the line sits
        // at the end, so the gap between them stays open.
        Expanded(
          child: Align(alignment: AlignmentDirectional.centerStart, child: lock(modelMenu)),
        ),
        if (selectedAgent != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _endAlignedPickerMaxWidth),
            child: lock(agentMenu(agent: selectedAgent, hugLabel: true)),
          ),
      ],
      ?fastModeButton,
      for (final chip in widget.trailing) _pillHalo(reachesLayerBottom: false, child: chip),
    ];
    final transientTrailing = widget.transientTrailing;
    final row = _pillRow(
      compact: compact,
      pills: selectors,
      presence: ComposerChipPresence(
        gap: _pillGap,
        chip: transientTrailing == null ? null : _pillHalo(reachesLayerBottom: false, child: transientTrailing),
      ),
    );
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
    // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
    final pointer = PregoInteractionScope.of(context) == PregoInteractionMode.pointer;
    // The bottom-most row: its halos run on to the bottom edge, so nothing
    // shows below the pills.
    Widget halo(Widget child) => _pillHalo(reachesLayerBottom: true, child: child);
    Widget pill({required IconData icon, required String label}) => _pickerButton(
      pointer: pointer,
      hugLabel: compact,
      leadingIcon: icon,
      label: label,
      surfaceStyle: PregoComposerSurfaceStyle.subtle,
      onPressed: null,
    );
    // As in the composer, a harness with a single agent has none to name.
    final agentPill = agents.length > 1 && agent != null ? pill(icon: TablerRegular.robot, label: agent) : null;
    final modelLabel = model == null
        ? null
        : (name: _resolveModelName(context, providers: providers, selected: model), level: model.variant);
    final pills = [
      if (compact) ...[
        if (agentPill != null) _pickerSlot(compact: true, child: halo(agentPill)),
        if (modelLabel != null)
          _pickerSlot(
            compact: true,
            child: halo(
              pill(
                icon: TablerRegular.cpu,
                label: _modelEffortText(name: modelLabel.name, level: modelLabel.level),
              ),
            ),
          ),
      ] else ...[
        // Laid out as the live touch composer: the chip leads, the agent ends.
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: modelLabel == null
                ? const SizedBox.shrink()
                : halo(
                    ModelEffortChip(
                      name: modelLabel.name,
                      level: modelLabel.level,
                      fast: false,
                      showsCaret: false,
                      surfaceStyle: PregoComposerSurfaceStyle.subtle,
                    ),
                  ),
          ),
        ),
        if (agentPill != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _endAlignedPickerMaxWidth),
            child: halo(agentPill),
          ),
      ],
    ];
    if (modelLabel == null && agentPill == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 8),
      child: _pillRow(compact: compact, pills: pills, presence: null),
    );
  }
}

/// A pill's own halo. The row has none, so transcript words between the pills
/// stay readable; the halos still merge across the narrow gaps.
Widget _pillHalo({required bool reachesLayerBottom, required Widget child}) =>
    PregoPageHalo(radius: PregoRadius.full, reachesLayerBottom: reachesLayerBottom, child: child);

const double _pillGap = 8;

/// Hugging pointer pills sit leading-aligned; touch pills fill the strip. A
/// [presence] ends the row with its own gap, so a chip coming or going there
/// moves the pills smoothly.
Widget _pillRow({required bool compact, required List<Widget> pills, required Widget? presence}) {
  final size = compact ? MainAxisSize.min : MainAxisSize.max;
  final pillsRow = Row(mainAxisSize: size, spacing: _pillGap, children: pills);
  final row = presence == null
      ? pillsRow
      : Row(
          mainAxisSize: size,
          children: [
            if (compact) Flexible(child: pillsRow) else Expanded(child: pillsRow),
            presence,
          ],
        );
  return compact ? Align(alignment: AlignmentDirectional.centerStart, heightFactor: 1, child: row) : row;
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

/// How wide a picker at the end of the model and effort chip's row may hug its
/// label, so the chip keeps room for its model name.
const double _endAlignedPickerMaxWidth = 140;

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

/// The model and its effort as one control, opening the searchable
/// [ModelPicker] that picks both: a [ModelEffortChip] on touch, and a pill
/// reading the same under a pointer.
class const _ModelEffortMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,

  /// Shows the pointer shells' pill, which hugs its label, instead of the
  /// touch chip.
  required final bool compact,

  /// Shows the chip without its caret, as the read-only pills do.
  required final bool readOnly,
  required final List<ModelPickerSection> sections,
  required final AgentModel? selected,
  required final List<ProviderInfo> providers,
  required final ModelSelectionHandler onModelSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = _resolveModelName(context, providers: providers, selected: selected);
    final level = selected?.variant;
    return PregoPickerPopover(
      pointerWidth: 300,
      onClosed: null,
      triggerBuilder: (context, toggle) {
        if (compact) {
          return _pickerButton(
            // ignore: no_slop_linter/avoid_interaction_mode_reads, pending: metrics
            pointer: PregoInteractionScope.of(context) == PregoInteractionMode.pointer,
            hugLabel: true,
            leadingIcon: TablerRegular.cpu,
            label: _modelEffortText(name: name, level: level),
            surfaceStyle: surfaceStyle,
            onPressed: toggle,
          );
        }
        final borderRadius = BorderRadius.circular(PregoRadius.full);
        return Semantics(
          button: true,
          label: _modelEffortSemantics(context, name: name, level: level),
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              mouseCursor: WidgetStateMouseCursor.clickable,
              borderRadius: borderRadius,
              onTap: toggle,
              child: ModelEffortChip(
                name: name,
                level: level,
                fast: false,
                showsCaret: !readOnly,
                surfaceStyle: surfaceStyle,
              ),
            ),
          ),
        );
      },
      contentBuilder: (context, close) => ModelPicker(
        sections: sections,
        showsEveryModel: false,
        selected: selected,
        onModelSelected: onModelSelected,
        onClose: close,
      ),
    );
  }
}

/// The model and effort chip and the orbits picker it opens, with the searchable
/// [ModelPicker] behind the picker's "All N models".
class const _OrbitsMenu({
  required final PregoComposerSurfaceStyle surfaceStyle,
  required final bool readOnly,
  required final ModelOrbits orbits,
  required final List<ModelPickerSection> sections,
  required final AgentModel? selected,
  required final ModelSelectionHandler onModelSelected,
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
        surfaceStyle: surfaceStyle,
        readOnly: readOnly,
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
      // Opened from "All N models", so it lists every model, not one per
      // family, and sets the effort of any of them, as the other harnesses'
      // list does.
      contentBuilder: (context, close) => ModelPicker(
        sections: sections,
        showsEveryModel: true,
        selected: selected,
        onModelSelected: onModelSelected,
        onClose: close,
      ),
    );
  }
}

/// The chip as a button. A press opens the orbits picker at once and hands
/// the finger over, so the same press slides on into it; a tap leaves the
/// picker open for a second tap.
class const _OrbitsChip({
  required final PregoComposerSurfaceStyle surfaceStyle,

  /// Shows the chip without its caret, as the read-only pills do.
  required final bool readOnly,
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

  /// Opens the picker, answering the press, key or screen-reader tap with a
  /// haptic at once.
  void _open({required OrbitsPointerHandoff? handoff}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    unawaited(playOrbitsHaptic(play: HapticFeedback.lightImpact));
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
      label: switch (level) {
        null => orbits.current.name,
        EffortLevel.off => loc.orbitsPickerLevelOff(orbits.current.name),
        final level => loc.orbitsPickerLevel(orbits.current.name, level.wireId),
      },
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
                borderRadius: BorderRadius.circular(ModelEffortChip.height / 2),
                boxShadow: _focused
                    ? [
                        BoxShadow(color: colors.focusRing, spreadRadius: 4),
                        BoxShadow(color: colors.bgSurface1, spreadRadius: 2),
                      ]
                    : null,
              ),
              child: ModelEffortChip(
                name: orbits.current.name,
                level: orbits.currentLevel?.wireId,
                fast: widget.fastModeControl == FastModeControl.on,
                showsCaret: !widget.readOnly,
                surfaceStyle: widget.surfaceStyle,
              ),
            ),
          ),
        ),
      ),
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

/// The model and its effort as the pointer pill reads them, `Opus 5.5 · High`,
/// or only the model when it has no effort.
String _modelEffortText({required String name, required String? level}) =>
    level == null ? name : "$name · ${effortLevelWord(level: level)}";

/// What a screen reader hears for the model and effort control.
String _modelEffortSemantics(BuildContext context, {required String name, required String? level}) {
  final loc = context.loc;
  if (level == null) return name;
  if (EffortLevel.tryParse(value: level) == EffortLevel.off) return loc.orbitsPickerLevelOff(name);
  return loc.orbitsPickerLevel(name, level);
}
