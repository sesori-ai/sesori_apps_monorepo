import "dart:async";

import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show FastModeControl, FastModeToggleDecision, ModelOrbits, logw;
import "package:sesori_shared/sesori_shared.dart";
import "package:theme_prego/module_prego.dart";

import "../../../../extensions/build_context_x.dart";
import "../fast_mode_toggle.dart";
import "orbit_geometry.dart";
import "orbit_metal.dart";
import "orbits_painter.dart";

/// Opens the orbits picker over the screen, its rings centred on the
/// medallion of the chip at [anchorRect] (global coordinates; the medallion
/// sits at the chip's leading end, as wide as the chip is tall).
///
/// One press, slide and release picks a model and its effort together, and so
/// does one tap. Releasing anywhere else closes the picker without a change.
Future<void> showOrbitsPicker({
  required BuildContext context,
  required Rect anchorRect,
  required ModelOrbits orbits,
  required void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required VoidCallback onShowAllModels,
  required FastModeControl fastModeControl,
  required FastModeToggleDecision? Function() decideFastModeToggle,
  required ValueChanged<bool> onFastModeChanged,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final overlayBox = navigator.context.findRenderObject();
  final localAnchor = overlayBox is RenderBox
      ? Rect.fromPoints(overlayBox.globalToLocal(anchorRect.topLeft), overlayBox.globalToLocal(anchorRect.bottomRight))
      : anchorRect;
  return navigator.push(
    _OrbitsPickerRoute(
      reducedMotion: context.isReducedMotion,
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      builder: (context, animation) => OrbitsPicker(
        animation: animation,
        anchorRect: localAnchor,
        orbits: orbits,
        onModelSelected: onModelSelected,
        onShowAllModels: onShowAllModels,
        fastModeControl: fastModeControl,
        decideFastModeToggle: decideFastModeToggle,
        onFastModeChanged: onFastModeChanged,
      ),
    ),
  );
}

final class _OrbitsPickerRoute({
  required final bool reducedMotion,
  required final String label,
  required final Widget Function(BuildContext context, Animation<double> animation) builder,
}) extends PopupRoute<void> {
  @override
  String get barrierLabel => label;

  // The picker paints its own scrim, which leaves the chip clear.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => reducedMotion ? OrbitsMotion.fade : OrbitsMotion.open;

  @override
  Duration get reverseTransitionDuration => reducedMotion ? OrbitsMotion.fade : OrbitsMotion.close;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Material(type: MaterialType.transparency, child: builder(context, animation));
}

/// The orbits picker: one ring per model, effort as the angle along the ring,
/// fast mode in the corner. Shown by [showOrbitsPicker].
class const OrbitsPicker({
  super.key,

  /// The route's animation, which drives the ripple entry.
  required final Animation<double> animation,

  /// The chip the picker opened from, in the picker's coordinates.
  required final Rect anchorRect,
  required final ModelOrbits orbits,
  required final void Function({required String providerID, required String modelID, required SessionVariant? variant})
  onModelSelected,
  required final VoidCallback onShowAllModels,
  required final FastModeControl fastModeControl,
  required final FastModeToggleDecision? Function() decideFastModeToggle,
  required final ValueChanged<bool> onFastModeChanged,
}) extends StatefulWidget {
  @override
  State<OrbitsPicker> createState() => _OrbitsPickerState();
}

class _OrbitsPickerState() extends State<OrbitsPicker> with SingleTickerProviderStateMixin {
  static const Size _fastToggleSize = Size(88, 36);

  late final AnimationController _hotGrow = AnimationController(vsync: this, duration: OrbitsMotion.grow);

  /// The fast-mode state as toggled here, since the route does not rebuild
  /// with the composer.
  late FastModeControl _fastMode = widget.fastModeControl;

  OrbitLabels? _labels;
  OrbitPalette? _palette;

  /// The pointer that owns the gesture, what it pressed first, and what it is
  /// on now.
  int? _pointer;
  OrbitTarget? _pressed;
  OrbitTarget? _hot;
  OrbitTarget? _previousHot;
  bool _done = false;

  Offset get _origin => Offset(widget.anchorRect.left + widget.anchorRect.height / 2, widget.anchorRect.center.dy);

  bool get _showsFastToggle =>
      widget.fastModeControl != FastModeControl.hidden || widget.orbits.rings.any((ring) => ring.hasFastMode);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final prego = context.prego;
    final loc = context.loc;
    final palette = OrbitPalette(colors: prego.colors);
    _labels?.dispose();
    _palette = palette;
    _labels = OrbitLabels(
      orbits: widget.orbits,
      textTheme: prego.textTheme,
      palette: palette,
      fastTag: loc.orbitsPickerFastTag,
      noEffortText: loc.orbitsPickerNoEffort,
      allModelsText: loc.orbitsPickerAllModels(widget.orbits.totalModels),
    );
  }

  @override
  void dispose() {
    _hotGrow.dispose();
    _labels?.dispose();
    super.dispose();
  }

  OrbitGeometry _geometry(Size size) => OrbitGeometry(
    orbits: widget.orbits,
    origin: _origin,
    size: size,
    fastToggleRect: _showsFastToggle
        ? Rect.fromLTWH(
            size.width - widget.anchorRect.left - _fastToggleSize.width,
            _origin.dy - _fastToggleSize.height / 2,
            _fastToggleSize.width,
            _fastToggleSize.height,
          )
        : null,
  );

  void _setHot(OrbitTarget? target) {
    // Only things a slide can pick light up under the finger.
    final hot = target is OrbitFastToggleTarget ? null : target;
    if (hot == _hot) return;
    setState(() {
      _previousHot = _hot;
      _hot = hot;
    });
    _hotGrow.forward(from: 0);
    if (hot != null) unawaited(_selectionHaptic());
  }

  static Future<void> _selectionHaptic() async {
    try {
      await HapticFeedback.selectionClick();
    } on Object catch (error, stackTrace) {
      logw("Failed to play orbits picker haptic feedback", error, stackTrace);
    }
  }

  void _onPointerDown({required PointerDownEvent event, required OrbitGeometry geometry}) {
    if (_pointer != null || _done) return;
    _pointer = event.pointer;
    final target = geometry.hitTest(event.localPosition);
    _pressed = target;
    _setHot(target);
  }

  void _onPointerMove({required PointerMoveEvent event, required OrbitGeometry geometry}) {
    if (event.pointer != _pointer) return;
    _setHot(geometry.hitTest(event.localPosition));
  }

  void _onPointerUp({required PointerUpEvent event, required OrbitGeometry geometry}) {
    if (event.pointer != _pointer) return;
    final target = geometry.hitTest(event.localPosition);
    final pressed = _pressed;
    _endGesture();
    switch (target) {
      // The fast toggle answers only a press that started on it, so a slide
      // that ends there cannot switch speed by accident.
      case OrbitFastToggleTarget() when pressed is! OrbitFastToggleTarget:
        _close();
      case final target?:
        _activate(target);
      case null:
        _close();
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _pointer) _endGesture();
  }

  void _endGesture() {
    _pointer = null;
    _pressed = null;
    _setHot(null);
  }

  void _activate(OrbitTarget target) {
    if (_done) return;
    final orbits = widget.orbits;
    switch (target) {
      case OrbitLevelTarget(:final ringIndex, :final levelIndex):
        final ring = orbits.rings[ringIndex];
        _pick(providerID: ring.providerID, modelID: ring.modelID, variant: ring.levels[levelIndex].variant);
      case OrbitNameTarget(:final ringIndex):
        final ring = orbits.rings[ringIndex];
        _pick(providerID: ring.providerID, modelID: ring.modelID, variant: null);
      case OrbitAllModelsTarget():
        _close();
        widget.onShowAllModels();
      case OrbitFastToggleTarget():
        unawaited(_toggleFastMode());
    }
  }

  void _pick({required String providerID, required String modelID, required SessionVariant? variant}) {
    widget.onModelSelected(providerID: providerID, modelID: modelID, variant: variant);
    _close();
  }

  void _close() {
    if (_done) return;
    _done = true;
    Navigator.of(context).pop();
  }

  Future<void> _toggleFastMode() async {
    if (_fastMode == FastModeControl.hidden) {
      // Never swallow the tap: say why there is nothing to switch.
      final loc = context.loc;
      PregoPopupAlertPresenter.of(context).show(
        title: loc.sessionDetailFastModeUnavailableTitle,
        variant: PregoPopupAlertsNotificationsVariant.error,
        content: PregoPopupAlertContent(message: loc.orbitsPickerFastModeNotOffered(widget.orbits.current.name)),
      );
      return;
    }
    await toggleFastMode(
      context: context,
      decide: widget.decideFastModeToggle,
      onFastModeChanged: (fastMode) {
        widget.onFastModeChanged(fastMode);
        if (mounted) setState(() => _fastMode = fastMode ? FastModeControl.on : FastModeControl.off);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labels;
    final palette = _palette;
    if (labels == null || palette == null) return const SizedBox.shrink();
    final metal = _fastMode == FastModeControl.on ? OrbitMetal.gold : OrbitMetal.silver;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = _geometry(constraints.biggest);
        final fastToggleRect = geometry.fastToggleRect;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) => _onPointerDown(event: event, geometry: geometry),
          onPointerMove: (event) => _onPointerMove(event: event, geometry: geometry),
          onPointerUp: (event) => _onPointerUp(event: event, geometry: geometry),
          onPointerCancel: _onPointerCancel,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: OrbitsPainter(
                    geometry: geometry,
                    labels: labels,
                    palette: palette,
                    metal: metal,
                    anchorRect: widget.anchorRect,
                    entry: widget.animation,
                    reducedMotion: context.isReducedMotion,
                    hot: _hot,
                    previousHot: _previousHot,
                    hotGrow: _hotGrow,
                  ),
                ),
              ),
              if (fastToggleRect != null)
                Positioned.fromRect(
                  rect: fastToggleRect,
                  child: FadeTransition(
                    opacity: widget.animation,
                    child: _FastToggleFace(control: _fastMode, palette: palette),
                  ),
                ),
              ..._semanticTargets(geometry: geometry),
            ],
          ),
        );
      },
    );
  }

  /// Invisible screen-reader buttons over every target. Pointers never reach
  /// them: the gesture layer above owns every touch.
  List<Widget> _semanticTargets({required OrbitGeometry geometry}) {
    final loc = context.loc;
    final orbits = widget.orbits;
    Widget target({
      required Offset center,
      required Size size,
      required String label,
      required bool selected,
      required OrbitTarget onTap,
      bool? toggled,
    }) => Positioned.fromRect(
      rect: Rect.fromCenter(center: center, width: size.width, height: size.height),
      child: Semantics(
        button: true,
        label: label,
        selected: selected,
        toggled: toggled,
        onTap: () => _activate(onTap),
        child: const SizedBox.expand(),
      ),
    );
    const dotSize = Size.square(44);
    return [
      for (var ringIndex = 0; ringIndex < orbits.rings.length; ringIndex++) ...[
        target(
          center: geometry.pointAt(
            radius: geometry.ringRadii[ringIndex],
            angle: (OrbitGeometry.ringStartAngle + geometry.nameEndAngle(ringIndex: ringIndex)) / 2,
          ),
          size: dotSize,
          label: orbits.rings[ringIndex].name,
          selected: orbits.rings[ringIndex] == orbits.current && orbits.currentLevel == null,
          onTap: OrbitNameTarget(ringIndex: ringIndex),
        ),
        for (var levelIndex = 0; levelIndex < orbits.rings[ringIndex].levels.length; levelIndex++)
          target(
            center: geometry.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex),
            size: dotSize,
            label: loc.orbitsPickerLevel(
              orbits.rings[ringIndex].name,
              orbits.rings[ringIndex].levels[levelIndex].level.wireId,
            ),
            selected:
                orbits.rings[ringIndex] == orbits.current &&
                orbits.rings[ringIndex].levels[levelIndex].level == orbits.currentLevel,
            onTap: OrbitLevelTarget(ringIndex: ringIndex, levelIndex: levelIndex),
          ),
      ],
      if (geometry.showsAllModels)
        target(
          center: geometry.allModelsCenter,
          size: geometry.allModelsTouchRect.size,
          label: loc.orbitsPickerAllModels(orbits.totalModels),
          selected: false,
          onTap: const OrbitAllModelsTarget(),
        ),
      if (geometry.fastToggleRect case final rect?)
        target(
          center: rect.center,
          size: rect.size,
          label: loc.sessionDetailFastMode,
          selected: false,
          toggled: _fastMode == FastModeControl.on,
          onTap: const OrbitFastToggleTarget(),
        ),
    ];
  }
}

/// The fast-mode toggle's look: a plain pill at standard speed, dark enamel
/// with a gold bolt while fast, dimmed when the model cannot use it.
class const _FastToggleFace({required final FastModeControl control, required final OrbitPalette palette})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final prego = context.prego;
    final on = control == FastModeControl.on;
    final usable = control == FastModeControl.on || control == FastModeControl.off;
    final foreground = on ? OrbitMetal.gold.m1 : palette.text;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Opacity(
          opacity: usable ? 1 : .55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: on
                  ? const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [OrbitMetal.enamelTop, OrbitMetal.enamelBottom],
                    )
                  : null,
              color: on ? null : palette.surface,
              border: Border.all(
                color: on ? OrbitMetal.gold.m2 : prego.colors.borderPrimary,
                width: on ? 1.6 : 1,
              ),
              borderRadius: BorderRadius.circular(PregoRadius.full),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(usable ? TablerRegular.bolt : TablerRegular.bolt_off, size: 18, color: foreground),
                const SizedBox(width: 6),
                Text(
                  context.loc.orbitsPickerFastToggle,
                  style: prego.textTheme.textMd.medium.copyWith(color: foreground, height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
