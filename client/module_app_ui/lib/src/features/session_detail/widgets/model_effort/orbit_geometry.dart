import "dart:math" as math;
import "dart:ui";

import "package:flutter/foundation.dart" show immutable;
import "package:sesori_dart_core/sesori_dart_core.dart" show ModelOrbits;

/// What a point on the orbits picker lands on.
@immutable
sealed class const OrbitTarget();

/// One level dot of a ring: picks that model at that level.
final class const OrbitLevelTarget({
  /// The ring's index in [ModelOrbits.rings].
  required final int ringIndex,

  /// The level's index in that ring's own levels.
  required final int levelIndex,
}) extends OrbitTarget {
  @override
  bool operator ==(Object other) =>
      other is OrbitLevelTarget && other.ringIndex == ringIndex && other.levelIndex == levelIndex;

  @override
  int get hashCode => Object.hash(ringIndex, levelIndex);
}

/// The start of a ring, where its model name sits: picks the model and leaves
/// the level to the model switch rule.
final class const OrbitNameTarget({
  /// The ring's index in [ModelOrbits.rings].
  required final int ringIndex,
}) extends OrbitTarget {
  @override
  bool operator ==(Object other) => other is OrbitNameTarget && other.ringIndex == ringIndex;

  @override
  int get hashCode => ringIndex.hashCode;
}

/// The "All N models" pill.
final class const OrbitAllModelsTarget() extends OrbitTarget;

/// The fast-mode toggle in the corner.
final class const OrbitFastToggleTarget() extends OrbitTarget;

/// A slice of a ring band between two radii and two angles (degrees,
/// counter-clockwise from the positive x axis, [fromAngle] > [toAngle]).
final class const OrbitSector({
  required final double innerRadius,
  required final double outerRadius,
  required final double fromAngle,
  required final double toAngle,
}) {
  bool contains({required double radius, required double angle}) =>
      radius >= innerRadius && radius < outerRadius && angle <= fromAngle && angle > toAngle;
}

/// Where everything of the orbits picker sits, shared by its painter and its
/// gestures so what is drawn and what is touched cannot drift apart.
///
/// The rings are quarter arcs centred on [origin], the chip's medallion near
/// the bottom-left of the screen. A level is an angle: the weakest level sits
/// near the vertical, the strongest near the horizontal. Each dot owns a
/// patch of its ring that reaches halfway to its neighbours, so a finger never
/// has to hit the dot itself. All lengths are logical pixels; angles are
/// degrees, counter-clockwise from the positive x axis with y pointing up.
final class OrbitGeometry({
  required final ModelOrbits orbits,

  /// The centre of the rings: the chip's medallion.
  required final Offset origin,

  /// The size of the overlay the picker fills.
  required Size size,

  /// Where the fast-mode toggle sits, or null when there is none.
  required final Rect? fastToggleRect,
}) {
  /// How much the rings shrank to fit the overlay, 1 when they fit. Only a
  /// small overlay shrinks them, such as a narrow or a landscape phone.
  final double scale = math.min(
    1.0,
    math.min(size.width - origin.dx - _edgeMargin, origin.dy - _edgeMargin) /
        (_baseRadii[math.max(0, orbits.rings.length - 1)] + rayOverhang + _labelRoom),
  );

  /// Each ray's angle, by its level's index in [ModelOrbits.levels].
  final List<double> rayAngles = rayAnglesFor(levelCount: orbits.levels.length);

  /// Whether the "All N models" pill shows.
  final bool showsAllModels = orbits.totalModels > orbits.rings.length;

  /// Each ring's radius, by its index in [ModelOrbits.rings], so outermost
  /// first.
  late final List<double> ringRadii = [
    for (var index = 0; index < orbits.rings.length; index++) _baseRadii[orbits.rings.length - 1 - index] * scale,
  ];

  /// The ring radii from the innermost out, for up to four rings.
  static const List<double> _baseRadii = [150, 205, 260, 315];

  /// Room beyond the rays for most of their level labels. A 393 pt wide phone
  /// fits the rings unscaled, as the agreed mock does.
  static const double _labelRoom = 24;
  static const double _edgeMargin = 8;

  /// Where a model name starts along its ring.
  static const double nameStartAngle = 95;

  /// The angle a ring's touch area starts at, a little past the vertical.
  static const double ringStartAngle = 96;

  /// Where the ring line starts and ends.
  static const double ringLineFromAngle = 93;
  static const double ringLineToAngle = 4;

  /// How far a ring's name patch stops before its first dot.
  static const double _nameGap = 7;

  /// How far the last dot's patch reaches past it, short of the fast toggle.
  static const double _lastPatchReach = 7;

  /// The name patch of a ring without levels reaches almost to the horizontal.
  static const double _levellessEndAngle = 3;

  /// Where the single dot of a ring without levels sits.
  static const double levellessDotAngle = 54;

  /// How far the innermost and outermost patches reach past their ring.
  static const double _edgeBandReach = 34;

  /// How far past the outermost ring the rays reach, and where their labels
  /// start.
  static const double rayOverhang = 12;
  static const double labelGap = 20;

  /// How far inside the innermost ring the rays start.
  static const double rayInset = 18;

  /// The radius of a model's name baseline, inside its ring.
  static const double nameInset = 17;

  /// The "All N models" pill: where it sits, its drawn size and its touch size.
  static const double _allModelsRadius = 80;
  static const double _allModelsAngle = 62;
  static const Size allModelsPillSize = Size(76, 26);
  static const Size _allModelsTouchSize = Size(88, 44);

  /// One ray per level, evenly spread. Five levels span 68° to 12° and six span
  /// 74° to 14°; more levels widen the fan further, fewer keep the five-level
  /// span so their patches grow.
  static List<double> rayAnglesFor({required int levelCount}) {
    if (levelCount == 0) return const [];
    final extra = math.max(0, levelCount - 5);
    final first = 68.0 + 6 * extra;
    final last = 12.0 + 2 * extra;
    if (levelCount == 1) return [(first + last) / 2];
    final step = (first - last) / (levelCount - 1);
    return [for (var index = 0; index < levelCount; index++) first - index * step];
  }

  /// The point at [radius] and [angle] around [origin].
  Offset pointAt({required double radius, required double angle}) {
    final radians = angle * math.pi / 180;
    return Offset(origin.dx + radius * math.cos(radians), origin.dy - radius * math.sin(radians));
  }

  /// The ray angle of level [levelIndex] of ring [ringIndex].
  double levelAngle({required int ringIndex, required int levelIndex}) {
    final level = orbits.rings[ringIndex].levels[levelIndex].level;
    return rayAngles[orbits.levels.indexOf(level)];
  }

  /// The centre of a level dot.
  Offset dotCenter({required int ringIndex, required int levelIndex}) => pointAt(
    radius: ringRadii[ringIndex],
    angle: levelAngle(ringIndex: ringIndex, levelIndex: levelIndex),
  );

  /// The centre of the single dot of a ring without levels.
  Offset levellessDotCenter({required int ringIndex}) =>
      pointAt(radius: ringRadii[ringIndex], angle: levellessDotAngle);

  /// Where the ring's name patch ends: just before its first dot.
  double nameEndAngle({required int ringIndex}) {
    if (orbits.rings[ringIndex].levels.isEmpty) return _levellessEndAngle;
    return levelAngle(ringIndex: ringIndex, levelIndex: 0) + _nameGap;
  }

  /// The ring's band, reaching halfway to each neighbour.
  (double inner, double outer) ringBand({required int ringIndex}) {
    final radius = ringRadii[ringIndex];
    // Outermost first, so the next ring inwards has the next index.
    final inner = ringIndex == ringRadii.length - 1
        ? radius - _edgeBandReach * scale
        : (ringRadii[ringIndex + 1] + radius) / 2;
    final outer = ringIndex == 0 ? radius + _edgeBandReach * scale : (ringRadii[ringIndex - 1] + radius) / 2;
    return (inner, outer);
  }

  /// The touch patch of the ring's name.
  OrbitSector namePatch({required int ringIndex}) {
    final (inner, outer) = ringBand(ringIndex: ringIndex);
    return OrbitSector(
      innerRadius: inner,
      outerRadius: outer,
      fromAngle: ringStartAngle,
      toAngle: nameEndAngle(ringIndex: ringIndex),
    );
  }

  /// The touch patch of a level dot, reaching halfway to its neighbours.
  OrbitSector levelPatch({required int ringIndex, required int levelIndex}) {
    final (inner, outer) = ringBand(ringIndex: ringIndex);
    final levelCount = orbits.rings[ringIndex].levels.length;
    double angle(int index) => levelAngle(ringIndex: ringIndex, levelIndex: index);
    final here = angle(levelIndex);
    return OrbitSector(
      innerRadius: inner,
      outerRadius: outer,
      fromAngle: levelIndex == 0 ? nameEndAngle(ringIndex: ringIndex) : (angle(levelIndex - 1) + here) / 2,
      toAngle: levelIndex == levelCount - 1 ? here - _lastPatchReach : (here + angle(levelIndex + 1)) / 2,
    );
  }

  /// The centre of the "All N models" pill.
  Offset get allModelsCenter => pointAt(radius: _allModelsRadius * scale, angle: _allModelsAngle);

  /// The touch area of the "All N models" pill.
  Rect get allModelsTouchRect => Rect.fromCenter(
    center: allModelsCenter,
    width: _allModelsTouchSize.width,
    height: _allModelsTouchSize.height,
  );

  /// What [point] lands on, or null for empty space.
  OrbitTarget? hitTest(Offset point) {
    final fastToggle = fastToggleRect;
    if (fastToggle != null && fastToggle.contains(point)) return const OrbitFastToggleTarget();
    if (showsAllModels && allModelsTouchRect.contains(point)) return const OrbitAllModelsTarget();
    final dx = point.dx - origin.dx;
    final dy = origin.dy - point.dy;
    final radius = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx) * 180 / math.pi;
    for (var ringIndex = 0; ringIndex < orbits.rings.length; ringIndex++) {
      final (inner, outer) = ringBand(ringIndex: ringIndex);
      if (radius < inner || radius >= outer) continue;
      if (namePatch(ringIndex: ringIndex).contains(radius: radius, angle: angle)) {
        return OrbitNameTarget(ringIndex: ringIndex);
      }
      final levelCount = orbits.rings[ringIndex].levels.length;
      for (var levelIndex = 0; levelIndex < levelCount; levelIndex++) {
        if (levelPatch(ringIndex: ringIndex, levelIndex: levelIndex).contains(radius: radius, angle: angle)) {
          return OrbitLevelTarget(ringIndex: ringIndex, levelIndex: levelIndex);
        }
      }
      return null;
    }
    return null;
  }
}
