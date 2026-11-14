import "dart:async";

import "package:flutter/gestures.dart" show kTouchSlop;
import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart"
    show EffortLevel, FastModeControl, FastModeToggleDecision, ModelOrbits, logw;
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
/// A press that began on the chip arrives as [handoff], so the same finger
/// slides on into the picker without a second press.
Future<void> showOrbitsPicker({
  required BuildContext context,
  required Rect anchorRect,
  required OrbitsPointerHandoff? handoff,
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
        handoff: handoff,
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

/// Plays [play], one of [HapticFeedback]'s patterns, for the medallion chip
/// and the orbits picker. A platform failure is logged, never thrown at the
/// gesture.
Future<void> playOrbitsHaptic({required Future<void> Function() play}) async {
  try {
    await play();
  } on Object catch (error, stackTrace) {
    logw("Failed to play orbits haptic feedback", error, stackTrace);
  }
}

final class _OrbitsPickerRoute({
  required final bool reducedMotion,
  required final String label,
  required final Widget Function(BuildContext context, Animation<double> animation) builder,
}) extends PopupRoute<void> {
  // Focus stays where it was, so an open keyboard stays up and the chip does
  // not slide away from under the finger.
  this : super(requestFocus: false);

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
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => Material(
    type: MaterialType.transparency,
    // Part of the composer: a touch here leaves the prompt field focused.
    child: TextFieldTapRegion(child: builder(context, animation)),
  );
}

/// Where a finger that pressed the chip is now.
sealed class const OrbitsHandoffPhase();

final class const OrbitsHandoffPressing({required final Offset position}) extends OrbitsHandoffPhase;

final class const OrbitsHandoffReleased({required final Offset position}) extends OrbitsHandoffPhase;

final class const OrbitsHandoffCancelled() extends OrbitsHandoffPhase;

/// A press that began on the chip, carried into the picker. The chip keeps
/// receiving that finger's events after the picker opens over it, so it
/// reports them here (global coordinates) and the picker follows the same
/// finger without a second press.
final class OrbitsPointerHandoff({required final int pointer, required final Offset start}) {
  OrbitsHandoffPhase _phase = OrbitsHandoffPressing(position: start);
  VoidCallback? _follower;
  bool _travelled = false;

  /// Where the finger is now.
  OrbitsHandoffPhase get phase => _phase;

  /// Whether the finger has ever moved past touch slop from [start]. A
  /// release before that was a tap, which leaves the picker open for a
  /// second one. Tracked here, because the picker may attach after the
  /// finger has already moved.
  bool get travelled => _travelled;

  /// Calls [follower] whenever the finger moves, lifts or is cancelled; null
  /// stops following.
  void follow({required VoidCallback? follower}) => _follower = follower;

  void move({required Offset position}) {
    _track(position);
    _report(OrbitsHandoffPressing(position: position));
  }

  void release({required Offset position}) {
    _track(position);
    _report(OrbitsHandoffReleased(position: position));
  }

  void _track(Offset position) {
    if ((position - start).distance > kTouchSlop) _travelled = true;
  }

  void cancel() => _report(const OrbitsHandoffCancelled());

  void _report(OrbitsHandoffPhase phase) {
    _phase = phase;
    _follower?.call();
  }
}

/// The orbits picker: one ring per model, effort as the angle along the ring,
/// fast mode in the corner. Shown by [showOrbitsPicker].
class const OrbitsPicker({
  super.key,

  /// The route's animation, which drives the ripple entry.
  required final Animation<double> animation,

  /// The chip the picker opened from, in the picker's coordinates.
  required final Rect anchorRect,

  /// The press on the chip that opened the picker, if a finger did.
  required final OrbitsPointerHandoff? handoff,
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
  void initState() {
    super.initState();
    final handoff = widget.handoff;
    if (handoff == null) return;
    // The finger that opened the picker is already down. Its events keep going
    // to the chip, which reports them through the handoff; the picker can
    // follow them once it has a size.
    _pointer = handoff.pointer;
    handoff.follow(follower: _followHandoff);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _followHandoff();
    });
  }

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
      noEffortText: loc.orbitsPickerNoEffort,
      allModelsText: loc.orbitsPickerAllModels(widget.orbits.totalModels),
    );
  }

  @override
  void dispose() {
    widget.handoff?.follow(follower: null);
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

  /// Lights up [target] under the finger, with a selection [haptic] when it
  /// is new.
  void _setHot({required OrbitTarget? target, required bool haptic}) {
    // Only things a slide can pick light up under the finger.
    final hot = target is OrbitFastToggleTarget ? null : target;
    if (hot == _hot) return;
    setState(() {
      _previousHot = _hot;
      _hot = hot;
    });
    _hotGrow.forward(from: 0);
    if (hot != null && haptic) unawaited(playOrbitsHaptic(play: HapticFeedback.selectionClick));
  }

  /// Hit tests what is drawn: while the ripple settles, each ring is still
  /// scaled about the origin, so the finger is mapped back into each ring's
  /// own scale and only that ring's targets count. Once settled this is the
  /// plain [OrbitGeometry.hitTest].
  OrbitTarget? _hitTest({required OrbitGeometry geometry, required Offset position}) {
    final direct = geometry.hitTest(position);
    // The fast toggle is not part of the ripple.
    if (direct is OrbitFastToggleTarget) return direct;
    OrbitTarget? drawnAt({required int stagger}) {
      final scale = OrbitsMotion.scaleOf(
        entry: widget.animation,
        reducedMotion: context.isReducedMotion,
        stagger: stagger,
      );
      return geometry.hitTest(_origin + (position - _origin) / scale);
    }

    final ringCount = widget.orbits.rings.length;
    for (var ringIndex = 0; ringIndex < ringCount; ringIndex++) {
      final target = drawnAt(
        stagger: OrbitsMotion.ringStagger(ringCount: ringCount, ringIndex: ringIndex),
      );
      final onThisRing = switch (target) {
        OrbitLevelTarget(ringIndex: final hit) || OrbitNameTarget(ringIndex: final hit) => hit == ringIndex,
        _ => false,
      };
      if (onThisRing) return target;
    }
    final pill = drawnAt(stagger: 0);
    return pill is OrbitAllModelsTarget ? pill : null;
  }

  void _onPointerDown({required PointerDownEvent event, required OrbitGeometry geometry}) {
    if (_pointer != null || _done) return;
    _pointer = event.pointer;
    final target = _hitTest(geometry: geometry, position: event.localPosition);
    _pressed = target;
    _setHot(target: target, haptic: true);
  }

  void _onPointerMove({required PointerMoveEvent event, required OrbitGeometry geometry}) {
    if (event.pointer != _pointer) return;
    _setHot(
      target: _hitTest(geometry: geometry, position: event.localPosition),
      haptic: true,
    );
  }

  void _onPointerUp({required PointerUpEvent event, required OrbitGeometry geometry}) {
    if (event.pointer != _pointer) return;
    _release(
      target: _hitTest(geometry: geometry, position: event.localPosition),
    );
  }

  void _followHandoff() {
    final handoff = widget.handoff;
    final box = context.findRenderObject();
    if (handoff == null || handoff.pointer != _pointer || box is! RenderBox || !box.hasSize) return;
    final geometry = _geometry(box.size);
    OrbitTarget? targetAt(Offset position) => _hitTest(geometry: geometry, position: box.globalToLocal(position));

    switch (handoff.phase) {
      case OrbitsHandoffPressing(:final position):
        // The chip already answered the press, so a finger that has not
        // moved yet gets no second haptic for where it landed.
        _setHot(target: targetAt(position), haptic: handoff.travelled);
      case OrbitsHandoffReleased(:final position):
        final target = targetAt(position);
        // A tap on the chip opens the picker and leaves it open.
        if (handoff.travelled) {
          _release(target: target);
        } else {
          _endGesture();
        }
      case OrbitsHandoffCancelled():
        _endGesture();
    }
  }

  void _release({required OrbitTarget? target}) {
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
    _setHot(target: null, haptic: false);
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
    unawaited(playOrbitsHaptic(play: HapticFeedback.lightImpact));
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
            label: switch (orbits.rings[ringIndex].levels[levelIndex].level) {
              EffortLevel.off => loc.orbitsPickerLevelOff(orbits.rings[ringIndex].name),
              final level => loc.orbitsPickerLevel(orbits.rings[ringIndex].name, level.wireId),
            },
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
