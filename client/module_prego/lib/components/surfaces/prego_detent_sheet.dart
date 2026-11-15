import "dart:math" as math;

import "package:flutter/physics.dart";
import "package:flutter/semantics.dart";
import "package:material_ui/material_ui.dart";

import "../../module_prego.dart";

/// Builds the content of a [showPregoDetentSheet] sheet.
///
/// Attach [scrollController] to the content's scrolling list so the list and
/// the sheet share one gesture: a drag down on a list scrolled to its top moves
/// the sheet, and a drag up on a half-height sheet grows it to full height
/// before the list scrolls. A scroll view without it scrolls on its own and
/// never moves the sheet.
typedef PregoDetentSheetBuilder = Widget Function(BuildContext context, ScrollController scrollController);

/// Presents [builder]'s content in a sheet with two resting heights, half the
/// screen and full height below the status bar, and returns the value the
/// route is popped with.
///
/// The sheet opens at half height. Its height follows the finger; on release
/// it springs to the height the drag points at: up to full, down to half, and
/// down from half closes it. The scrim is light at half height, so the page
/// behind stays readable, and deepens toward full; a tap on it closes the
/// sheet. The page behind stays mounted and keeps updating.
///
/// The keyboard lifts the sheet, so a text field at the bottom of the content
/// stays above it, and the sheet never grows over the status bar. With reduced
/// motion the sheet opens, closes and changes height without animating.
///
/// The sheet draws the grabber; the content brings its own header (for
/// example [PregoTopNavigationSheets] with `showGrabber: false`) and fills the
/// rest of the height.
Future<T?> showPregoDetentSheet<T>({required BuildContext context, required PregoDetentSheetBuilder builder}) {
  // ignore: no_slop_linter/avoid_navigator_of, design module has no go_router dep; pushes the sheet's own route
  final navigator = Navigator.of(context);
  final route = _PregoDetentSheetRoute<T>(
    builder: builder,
    reducedMotion: prefersReducedMotion(context),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    // The sheet builds under the navigator, so it keeps the presenter's theme
    // explicitly, as the standard modal presenters do.
    capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  return navigator.push(route);
}

const _enterDuration = Duration(milliseconds: 300);
const _exitDuration = Duration(milliseconds: 220);

/// Bounds for the exit after a downward release, which leaves at the finger's
/// speed.
const _minDragExitDuration = Duration(milliseconds: 120);
const _maxDragExitDuration = Duration(milliseconds: 300);

/// A release faster than this (points per second) moves to the next height in
/// its direction; a slower one settles on the nearest height.
const _flingVelocity = 700.0;

/// Heights within this distance (points) count as the same height.
const _tolerance = 0.5;

final _spring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 350));

/// A non-opaque route, so the page under the sheet stays built and painted.
/// Its own animation only carries the sheet in and out; the resting height is
/// the sheet's state.
class _PregoDetentSheetRoute<T>({
  required final PregoDetentSheetBuilder builder,
  required final bool reducedMotion,
  required final CapturedThemes capturedThemes,
  @override required final String barrierLabel,
}) extends PopupRoute<T> {
  // The sheet paints its own scrim, whose depth follows the sheet's height;
  // the transparent barrier under it still closes the sheet on a tap.
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => reducedMotion ? Duration.zero : _enterDuration;

  @override
  Duration get reverseTransitionDuration => reducedMotion ? Duration.zero : _exitDuration;

  /// Pops the sheet after a downward release, carrying it out over
  /// [exitDuration] instead of the default exit.
  void dismissFromDrag({required Duration exitDuration}) {
    if (!isCurrent) return;
    if (!reducedMotion) controller?.reverseDuration = exitDuration;
    navigator?.pop();
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return capturedThemes.wrap(_PregoDetentSheet(route: this, animation: animation));
  }
}

enum _Detent() {
  half,
  full,
}

/// Where a release sends the sheet.
enum _Snap() {
  close,
  half,
  full,
}

/// Who owns the sheet's height.
sealed class const _SheetMotion();

/// At rest on [detent]; the height follows the screen and the keyboard.
final class const _Resting({required final _Detent detent}) extends _SheetMotion;

/// The finger owns the height, and keeps it during the exit after a release.
final class const _Following() extends _SheetMotion;

/// Springing to [detent] after a release.
final class const _Settling({required final _Detent detent}) extends _SheetMotion;

/// The two resting heights, measured from the top of the keyboard (or the
/// bottom of the screen) to the top of the sheet.
final class const _SheetGeometry({required final double halfHeight, required final double fullHeight}) {
  static _SheetGeometry of(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final statusBar = MediaQuery.paddingOf(context).top;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final fullHeight = math.max(0.0, screenHeight - statusBar - keyboard);
    return _SheetGeometry(halfHeight: math.min(screenHeight / 2, fullHeight), fullHeight: fullHeight);
  }

  double heightOf(_Detent detent) => switch (detent) {
    .half => halfHeight,
    .full => fullHeight,
  };
}

class const _PregoDetentSheet({
  required final _PregoDetentSheetRoute<Object?> route,
  required final Animation<double> animation,
}) extends StatefulWidget {
  @override
  State<_PregoDetentSheet> createState() => _PregoDetentSheetState();
}

class _PregoDetentSheetState() extends State<_PregoDetentSheet> with SingleTickerProviderStateMixin {
  /// The sheet's height in points while it isn't resting.
  late final AnimationController _height = AnimationController.unbounded(vsync: this);
  late final CurvedAnimation _presence = CurvedAnimation(parent: widget.animation, curve: Curves.easeOutCubic);
  late final Listenable _frame = Listenable.merge([_presence, _height]);
  late final _SheetScrollController _scrollController = _SheetScrollController(sheet: this);
  _SheetMotion _motion = const _Resting(detent: .half);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The screen or keyboard changed under a spring: aim it at the new height
    // without dropping its speed.
    if (_motion case _Settling(:final detent)) _settleTo(detent: detent, velocity: _height.velocity);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _presence.dispose();
    _height.dispose();
    super.dispose();
  }

  double _heightIn(_SheetGeometry geometry) => switch (_motion) {
    _Resting(:final detent) => geometry.heightOf(detent),
    _Following() || _Settling() => _height.value.clamp(0.0, geometry.fullHeight),
  };

  /// Whether the sheet is below full height, so a drag up grows it first.
  bool get canGrow {
    final geometry = _SheetGeometry.of(context);
    return _heightIn(geometry) < geometry.fullHeight - _tolerance;
  }

  /// Moves the sheet by the finger's movement; positive [fingerDy] is down.
  void dragBy(double fingerDy) {
    final geometry = _SheetGeometry.of(context);
    final height = _heightIn(geometry);
    _height.stop();
    _motion = const _Following();
    _height.value = (height - fingerDy).clamp(0.0, geometry.fullHeight);
  }

  /// Ends a drag; positive [fingerVelocity] is down, in points per second.
  void release({required double fingerVelocity}) {
    if (_motion is! _Following) return;
    final geometry = _SheetGeometry.of(context);
    final height = _heightIn(geometry);
    switch (_snapFor(height: height, fingerVelocity: fingerVelocity, geometry: geometry)) {
      case .close:
        // Leave at the finger's speed, in a straight line, from where the
        // finger let go.
        final travel = math.max(height, geometry.halfHeight) + MediaQuery.viewInsetsOf(context).bottom;
        final microseconds = travel / math.max(fingerVelocity, 1) * Duration.microsecondsPerSecond;
        _presence.reverseCurve = Curves.linear;
        widget.route.dismissFromDrag(
          exitDuration: Duration(
            microseconds: microseconds
                .clamp(_minDragExitDuration.inMicroseconds, _maxDragExitDuration.inMicroseconds)
                .round(),
          ),
        );
      case .half:
        _settleTo(detent: .half, velocity: -fingerVelocity);
      case .full:
        _settleTo(detent: .full, velocity: -fingerVelocity);
    }
  }

  static _Snap _snapFor({
    required double height,
    required double fingerVelocity,
    required _SheetGeometry geometry,
  }) {
    final half = geometry.halfHeight;
    if (fingerVelocity > _flingVelocity) return height > half + _tolerance ? .half : .close;
    if (fingerVelocity < -_flingVelocity) return height < half - _tolerance ? .half : .full;
    if (height < half / 2) return .close;
    return height < (half + geometry.fullHeight) / 2 ? .half : .full;
  }

  /// Springs from the current height to [detent], starting at [velocity]
  /// (points per second, positive up). Reduced motion lands there at once.
  void _settleTo({required _Detent detent, required double velocity}) {
    // The preference read when the sheet opened, so a sheet that opened
    // without motion also settles without it.
    if (widget.route.reducedMotion) {
      _height.stop();
      setState(() => _motion = _Resting(detent: detent));
      return;
    }
    final settling = _Settling(detent: detent);
    _motion = settling;
    final target = _SheetGeometry.of(context).heightOf(detent);
    _height.animateWith(SpringSimulation(_spring, _height.value, target, velocity)).then((_) {
      // A drag or a retarget that took over the spring owns the height now.
      if (!mounted || !identical(_motion, settling)) return;
      setState(() => _motion = _Resting(detent: detent));
    });
  }

  /// Moves the sheet to [detent] for a screen reader, with the same motion as
  /// a release.
  void _moveTo(_Detent detent) {
    _height.stop();
    _height.value = _heightIn(_SheetGeometry.of(context));
    _settleTo(detent: detent, velocity: 0);
    // Offer the opposite action right away, not only once the spring rests.
    setState(() {});
  }

  /// The scrim's opacity at [height] when fully presented: none when closed,
  /// light at half height so the page behind stays readable, and as deep as a
  /// dialog's at full height.
  double _scrimOpacity({required double height, required _SheetGeometry geometry, required bool dark}) {
    final atHalf = dark ? 0.3 : 0.08;
    final atFull = dark ? 0.55 : 0.14;
    final half = geometry.halfHeight;
    if (height <= half) return half == 0 ? 0 : atHalf * height / half;
    // Above half height, full height is above half height too.
    return atHalf + (atFull - atHalf) * (height - half) / (geometry.fullHeight - half);
  }

  @override
  Widget build(BuildContext context) {
    final geometry = _SheetGeometry.of(context);
    final mediaQuery = MediaQuery.of(context);
    final keyboard = mediaQuery.viewInsets.bottom;
    final colors = context.prego.colors;
    final dark = colors.brightness == .dark;

    // The sheet handles the status bar, home indicator and keyboard itself.
    final content = MediaQuery(
      data: mediaQuery.removePadding(removeTop: true, removeBottom: true).removeViewInsets(removeBottom: true),
      child: Builder(builder: (context) => widget.route.builder(context, _scrollController)),
    );

    final localizations = MaterialLocalizations.of(context);
    final detent = switch (_motion) {
      _Resting(:final detent) || _Settling(:final detent) => detent,
      _Following() => null,
    };
    final surface = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: localizations.bottomSheetLabel,
      customSemanticsActions: switch (detent) {
        .half => {CustomSemanticsAction(label: localizations.collapsedIconTapHint): () => _moveTo(.full)},
        .full => {CustomSemanticsAction(label: localizations.expandedIconTapHint): () => _moveTo(.half)},
        null => null,
      },
      child: GestureDetector(
        // Drags anywhere a scroll view doesn't claim move the sheet, and taps
        // on its background don't reach the barrier behind it.
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => dragBy(details.delta.dy),
        onVerticalDragEnd: (details) => release(fingerVelocity: details.velocity.pixelsPerSecond.dy),
        onVerticalDragCancel: () => release(fingerVelocity: 0),
        // A Material, so text fields and ink in the content have one.
        child: Material(
          color: colors.bgSecondary,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(PregoRadius.x8l)),
          ),
          child: Padding(
            // The surface runs down behind the keyboard, so no gap opens under
            // it while the keyboard moves; the content stays above both the
            // keyboard and the home indicator.
            padding: EdgeInsets.only(bottom: math.max(keyboard, mediaQuery.viewPadding.bottom)),
            child: Column(
              children: [
                const PregoSheetGrabber(),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );

    return AnimatedBuilder(
      animation: _frame,
      child: surface,
      builder: (context, surface) {
        final height = _heightIn(geometry);
        final presence = _presence.value;
        // Between the two heights the sheet resizes; below half height it
        // keeps its half-height layout and slides down, so its content doesn't
        // squash on the way out.
        final boxHeight = math.max(height, geometry.halfHeight);
        final slide = (geometry.halfHeight - height).clamp(0.0, geometry.halfHeight);
        final offset = slide + (1 - presence) * (boxHeight + keyboard);
        final scrim = presence * _scrimOpacity(height: height, geometry: geometry, dark: dark);
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: Colors.black.withValues(alpha: scrim)),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: boxHeight + keyboard,
              child: Transform.translate(offset: Offset(0, offset), child: surface),
            ),
          ],
        );
      },
    );
  }
}

/// Gives the sheet's scroll views [_SheetScrollPosition]s.
class _SheetScrollController({required final _PregoDetentSheetState sheet}) extends ScrollController {
  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return _SheetScrollPosition(physics: physics, context: context, oldPosition: oldPosition, sheet: sheet);
  }
}

/// A scroll position that hands the drag to the sheet while the sheet should
/// move: a drag up while the sheet is below full height, and a drag down while
/// the list is at its top. Works for reversed lists, whose top is their end.
class _SheetScrollPosition({
  required super.physics,
  required super.context,
  required super.oldPosition,
  required final _PregoDetentSheetState sheet,
}) extends ScrollPositionWithSingleContext {
  /// Whether the current drag has moved the sheet, so its release settles the
  /// sheet instead of flinging the list.
  bool _movedSheet = false;

  bool get _reversed => axisDirectionIsReversed(axisDirection);

  bool get _atTop => _reversed ? pixels >= maxScrollExtent : pixels <= minScrollExtent;

  @override
  void applyUserOffset(double delta) {
    final fingerDy = _reversed ? -delta : delta;
    if ((fingerDy < 0 && sheet.canGrow) || (fingerDy > 0 && _atTop)) {
      _movedSheet = true;
      sheet.dragBy(fingerDy);
      return;
    }
    super.applyUserOffset(delta);
  }

  @override
  void goBallistic(double velocity) {
    if (!_movedSheet) {
      super.goBallistic(velocity);
      return;
    }
    _movedSheet = false;
    final fingerVelocity = _reversed ? velocity : -velocity;
    // A drag that grew the sheet to full height and went on scrolling the list
    // keeps its fling in the list.
    final listKeepsFling = !sheet.canGrow && fingerVelocity < 0;
    sheet.release(fingerVelocity: fingerVelocity);
    super.goBallistic(listKeepsFling ? velocity : 0);
  }
}
