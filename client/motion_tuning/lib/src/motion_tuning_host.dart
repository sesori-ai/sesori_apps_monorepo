// Developer-only controls use literal labels; values enter through validated parameter descriptors.
// ignore_for_file: no_slop_linter/avoid_string_literals_in_widgets, no_slop_linter/prefer_specific_type

import "package:flutter/scheduler.dart";
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

import "motion_parameters.dart";

enum _InteractionMode() {
  interact,
  select,
}

enum _PlaybackSpeed() {
  normal,
  half,
  fifth;

  String get label => switch (this) {
    normal => "Normal (1×)",
    half => "0.5×",
    fifth => "0.2×",
  };

  double get dilation => switch (this) {
    normal => 1,
    half => 2,
    fifth => 5,
  };
}

sealed class const _TargetSelection();
final class const _NoTarget() extends _TargetSelection;
final class const _SelectedTarget({required final MotionTarget target}) extends _TargetSelection;
final class const _OverlappingTargets({required final List<MotionTarget> targets}) extends _TargetSelection;

/// Wrap a preview app; install [MotionTuningOverlay] in its app builder.
/// The preview owns replay and captures the supplied immutable values per run.
class const MotionTuningHost({
  super.key,
  required final String fixtureId,
  required final List<MotionTarget> targets,
  required final void Function({required MotionTarget target, required MotionSnapshot values}) onReplay,
  required final Widget child,
}) extends StatefulWidget {
  @override
  State<MotionTuningHost> createState() => _MotionTuningHostState();
}

class _MotionTuningHostState() extends State<MotionTuningHost> {
  late final _regionKeys = {for (final target in widget.targets) target.id: GlobalKey()};
  MotionSnapshot _draft = const MotionSnapshot();
  _TargetSelection _selection = const _NoTarget();
  _InteractionMode _mode = _InteractionMode.interact;
  Offset _position = const Offset(12, 12);
  bool _expanded = false;
  bool _original = false;
  String? _notice;
  _PlaybackSpeed _speed = _PlaybackSpeed.normal;
  late final double _previousTimeDilation;

  @override
  void initState() {
    super.initState();
    _previousTimeDilation = timeDilation;
    timeDilation = _speed.dilation;
  }

  void _setSpeed({required _PlaybackSpeed speed}) {
    timeDilation = speed.dilation;
    setState(() => _speed = speed);
  }

  @override
  void dispose() {
    timeDilation = _previousTimeDilation;
    super.dispose();
  }

  MotionTarget? get _target => switch (_selection) {
    _SelectedTarget(:final target) => target,
    _NoTarget() || _OverlappingTargets() => null,
  };

  void _select({required MotionTarget target}) => setState(() {
    _selection = _SelectedTarget(target: target);
    _mode = _InteractionMode.interact;
    _expanded = true;
    _notice = null;
  });

  void _pick({required Offset position}) {
    final matches = <MotionTarget>[];
    for (final target in widget.targets) {
      final box = _regionKeys[target.id]?.currentContext?.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize && box.size.contains(box.globalToLocal(position))) {
        matches.add(target);
      }
    }
    if (matches.length == 1) {
      _select(target: matches.single);
    } else {
      setState(() {
        _expanded = true;
        _selection = matches.isEmpty ? const _NoTarget() : _OverlappingTargets(targets: matches);
        _notice = matches.isEmpty ? "No connected animation here. Choose a target from the list." : null;
      });
    }
  }

  void _edit({required MotionParameter parameter, required Object? input}) {
    try {
      final next = _draft.withInput(parameter: parameter, input: input);
      setState(() {
        _draft = next;
        _original = false;
        _notice = null;
      });
    } on FormatException catch (error) {
      setState(() => _notice = error.message);
    }
  }

  void _move({required Offset delta}) => setState(() => _position += delta);

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  void _toggleSelection() => setState(() {
    _mode = _mode == _InteractionMode.select ? _InteractionMode.interact : _InteractionMode.select;
    _notice = _mode == _InteractionMode.select ? "Tap a connected element to select it." : null;
  });

  void _compare({required bool original}) {
    setState(() => _original = original);
    _replay();
  }

  void _resetTarget() {
    final target = _target;
    if (target == null) return;
    setState(() {
      _draft = _draft.reset(target: target);
      _original = false;
    });
    _replay();
  }

  void _replay() {
    final target = _target;
    if (target == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _mode = _InteractionMode.interact;
      _notice = _original ? "Replaying original values." : "Replaying edited values.";
    });
    widget.onReplay(target: target, values: _original ? const MotionSnapshot() : _draft);
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(
        ClipboardData(
          text: encodeMotionPreset(
            fixtureId: widget.fixtureId,
            targets: widget.targets,
            values: _draft,
          ),
        ),
      );
      if (mounted) setState(() => _notice = "Preset copied. Source code is unchanged.");
    } on PlatformException catch (error) {
      if (mounted) setState(() => _notice = "Couldn’t copy preset: ${error.message ?? error.code}");
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final next = decodeMotionPreset(
        text: data?.text ?? "",
        fixtureId: widget.fixtureId,
        targets: widget.targets,
      );
      if (!mounted) return;
      setState(() {
        _draft = next;
        _original = false;
        _notice = "Preset loaded. Press Replay to preview it.";
      });
    } on FormatException catch (error) {
      if (mounted) setState(() => _notice = "Couldn’t load preset: ${error.message}");
    } on PlatformException catch (error) {
      if (mounted) setState(() => _notice = "Couldn’t paste preset: ${error.message ?? error.code}");
    }
  }

  @override
  Widget build(BuildContext context) => _MotionTuningScope(host: this, child: widget.child);
}

class const _MotionTuningScope({required final _MotionTuningHostState host, required super.child})
    extends InheritedWidget {
  static _MotionTuningHostState of({required BuildContext context}) =>
      context.dependOnInheritedWidgetOfExactType<_MotionTuningScope>()?.host ??
      (throw StateError("Wrap this preview in MotionTuningHost."));

  @override
  bool updateShouldNotify(_MotionTuningScope oldWidget) => true;
}

/// Mark a connected region without changing its hit targets or layout.
/// Use each target ID once in the mounted preview; hidden targets stay in the list.
class const MotionTargetRegion({super.key, required final String targetId, required final Widget child})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final host = _MotionTuningScope.of(context: context);
    final selected = host._target?.id == targetId && host._expanded;
    return DecoratedBox(
      key: host._regionKeys[targetId],
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: selected ? Border.all(color: context.prego.colors.borderBrand, width: 2) : null,
      ),
      child: child,
    );
  }
}

/// Above the app Navigator, so modal sheets cannot cover the tuning controls.
class const MotionTuningOverlay({super.key, required final Widget child}) extends StatefulWidget {
  @override
  State<MotionTuningOverlay> createState() => _MotionTuningOverlayState();
}

class _MotionTuningOverlayState() extends State<MotionTuningOverlay> {
  @override
  Widget build(BuildContext context) {
    final host = _MotionTuningScope.of(context: context);
    final media = MediaQuery.of(context);
    return Overlay.wrap(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - 24).clamp(0.0, 340.0);
          final availableHeight = (constraints.maxHeight - media.padding.top - media.viewInsets.bottom - 24).clamp(
            0.0,
            520.0,
          );
          final panelHeight = host._expanded ? availableHeight : 52.0;
          final maxLeft = (constraints.maxWidth - width - 12).clamp(12.0, double.infinity);
          final maxTop = (constraints.maxHeight - media.viewInsets.bottom - panelHeight - 12).clamp(
            media.padding.top + 12,
            double.infinity,
          );
          return Stack(
            children: [
              widget.child,
              if (host._mode == _InteractionMode.select)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => host._pick(position: details.globalPosition),
                    child: const SizedBox.expand(),
                  ),
                ),
              Positioned(
                left: host._position.dx.clamp(12.0, maxLeft),
                top: host._position.dy.clamp(media.padding.top + 12, maxTop),
                width: width,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelHeight),
                  child: _MotionPanel(
                    host: host,
                    onDrag: host._move,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class const _MotionPanel({
  required final _MotionTuningHostState host,
  required final void Function({required Offset delta}) onDrag,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final target = host._target;
    return Material(
      color: prego.colors.bgSurface2,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: prego.colors.borderSecondary),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (details) => onDrag(delta: details.delta),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(start: 14),
                      child: Row(
                        children: [
                          const Icon(Icons.drag_indicator, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              host._speed == _PlaybackSpeed.normal ? "Motion" : "Motion · ${host._speed.label}",
                              style: prego.textTheme.textSm.bold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: host._mode == _InteractionMode.select ? "Interact with preview" : "Select an element",
                  isSelected: host._mode == _InteractionMode.select,
                  onPressed: host._toggleSelection,
                  icon: const Icon(Icons.ads_click, size: 20),
                ),
                IconButton(
                  tooltip: "Replay animation",
                  onPressed: target == null ? null : host._replay,
                  icon: const Icon(Icons.play_arrow, size: 22),
                ),
                IconButton(
                  tooltip: host._expanded ? "Collapse motion controls" : "Expand motion controls",
                  onPressed: host._toggleExpanded,
                  icon: Icon(host._expanded ? Icons.expand_less : Icons.expand_more, size: 22),
                ),
              ],
            ),
          ),
          if (host._expanded)
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Global animation speed", style: prego.textTheme.textSm.medium),
                    _MotionMenu<_PlaybackSpeed>(
                      label: host._speed.label,
                      options: _PlaybackSpeed.values,
                      labelOf: ({required _PlaybackSpeed option}) => option.label,
                      onSelected: ({required _PlaybackSpeed option}) => host._setSpeed(speed: option),
                    ),
                    Text("Applies immediately across the preview.", style: prego.textTheme.textXs.regular),
                    const SizedBox(height: 12),
                    _MotionMenu<MotionTarget>(
                      label: target?.label ?? "Choose an animation",
                      options: host.widget.targets,
                      labelOf: ({required MotionTarget option}) => option.label,
                      onSelected: ({required MotionTarget option}) => host._select(target: option),
                    ),
                    if (host._selection case _OverlappingTargets(:final targets)) ...[
                      const Text("Overlapping elements — choose one:"),
                      for (final item in targets)
                        TextButton(
                          onPressed: () => host._select(target: item),
                          child: Text(item.label),
                        ),
                    ],
                    Text("Changes apply on Replay.", style: prego.textTheme.textXs.regular),
                    if (target != null) ...[
                      Row(
                        children: [
                          Expanded(child: Text(host._original ? "Original values" : "Edited values")),
                          Switch(
                            value: host._original,
                            onChanged: (value) => host._compare(original: value),
                          ),
                          TextButton(
                            onPressed: host._resetTarget,
                            child: const Text("Reset"),
                          ),
                        ],
                      ),
                      for (final parameter in target.parameters)
                        _ParameterControl(
                          parameter: parameter,
                          value: (host._original ? const MotionSnapshot() : host._draft).valueOf(parameter: parameter),
                          onChanged: ({required Object input}) => host._edit(parameter: parameter, input: input),
                        ),
                    ],
                    if (host._notice case final notice?)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(notice, style: prego.textTheme.textXs.regular),
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: host._copy,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text("Copy preset"),
                        ),
                        TextButton.icon(
                          onPressed: host._paste,
                          icon: const Icon(Icons.content_paste, size: 16),
                          label: const Text("Paste preset"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class const _ParameterControl({
  required final MotionParameter parameter,
  required final MotionValue value,
  required final void Function({required Object input}) onChanged,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parameter.label, style: prego.textTheme.textSm.medium),
          switch ((parameter, value)) {
            (MotionCurve(), MotionCurveValue(value: final easing)) => _MotionMenu<MotionEasing>(
              label: easing.label,
              options: MotionEasing.values,
              labelOf: ({required MotionEasing option}) => option.label,
              onSelected: ({required MotionEasing option}) => onChanged(input: option.name),
            ),
            (MotionDuration(:final min, :final max), MotionDurationValue(value: final duration)) => _numeric(
              min: min.inMilliseconds.toDouble(),
              max: max.inMilliseconds.toDouble(),
              step: 10,
              current: duration.inMilliseconds.toDouble(),
              unit: "ms",
              integer: true,
            ),
            (MotionNumber(:final min, :final max, :final step), MotionNumberValue(value: final number)) => _numeric(
              min: min,
              max: max,
              step: step,
              current: number,
              unit: "",
              integer: false,
            ),
            // Parameters decode values before this paired control reaches the UI.
            // ignore: no_slop_linter/prefer_exhaustive_switch
            _ => throw StateError("Parameter value does not match its control."),
          },
          Text(parameter.source, style: prego.textTheme.textXs.regular.copyWith(color: prego.colors.textTertiary)),
        ],
      ),
    );
  }

  Widget _numeric({
    required double min,
    required double max,
    required double step,
    required double current,
    required String unit,
    required bool integer,
  }) => Row(
    children: [
      Expanded(
        child: Slider(
          value: current,
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          semanticFormatterCallback: (value) => "${value.toStringAsFixed(integer ? 0 : 2)} $unit",
          onChanged: (next) => onChanged(input: integer ? next.round() : next),
        ),
      ),
      SizedBox(
        width: 76,
        child: _NumericInput(
          key: ValueKey(parameter.id),
          current: current,
          unit: unit,
          integer: integer,
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

// iOS number pads have no submit key. Update the draft while typing, keeping
// focus and partial text stable; Replay dismisses the keyboard and applies it.
class const _NumericInput({
  super.key,
  required final double current,
  required final String unit,
  required final bool integer,
  required final void Function({required Object input}) onChanged,
}) extends StatefulWidget {
  @override
  State<_NumericInput> createState() => _NumericInputState();
}

class _NumericInputState() extends State<_NumericInput> {
  late final _text = TextEditingController(text: _formatted);
  final _focus = FocusNode();

  String get _formatted => widget.current.toStringAsFixed(widget.integer ? 0 : 2);

  @override
  void didUpdateWidget(_NumericInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (num.tryParse(_text.text) != widget.current && (!_focus.hasFocus || oldWidget.current != widget.current)) {
      _text.value = TextEditingValue(
        text: _formatted,
        selection: TextSelection.collapsed(offset: _formatted.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _text,
    focusNode: _focus,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.done,
    decoration: InputDecoration(isDense: true, suffixText: widget.unit, border: const OutlineInputBorder()),
    onChanged: (text) => widget.onChanged(input: (widget.integer ? int.tryParse(text) : double.tryParse(text)) ?? text),
    onFieldSubmitted: (_) => _focus.unfocus(),
  );
}

class const _MotionMenu<T>({
  required final String label,
  required final List<T> options,
  required final String Function({required T option}) labelOf,
  required final void Function({required T option}) onSelected,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final option in options)
        MenuItemButton(
          onPressed: () => onSelected(option: option),
          child: Text(labelOf(option: option)),
        ),
    ],
    builder: (context, controller, child) => TextButton(
      onPressed: () => controller.isOpen ? controller.close() : controller.open(),
      child: Row(
        children: [
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.expand_more, size: 18),
        ],
      ),
    ),
  );
}
