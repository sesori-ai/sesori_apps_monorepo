import "dart:ui";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, ModelOrbits;

import "orbits_fixture.dart";

/// The agreed mock's phone: a 393 x 700 screen with the medallion at
/// (33.5, 610) and the fast toggle 14 pt from the right edge.
OrbitGeometry _geometry({required ModelOrbits orbits, Size size = const Size(393, 700)}) => OrbitGeometry(
  orbits: orbits,
  origin: const Offset(33.5, 610),
  size: size,
  fastToggleRect: Rect.fromLTWH(size.width - 14 - 88, 592, 88, 36),
);

void main() {
  final orbits = claudeOrbits(totalModels: 4, current: opus, currentLevel: EffortLevel.high);

  group("rays", () {
    test("match the mock for five and six levels", () {
      expect(OrbitGeometry.rayAnglesFor(levelCount: 5), [68, 54, 40, 26, 12]);
      expect(OrbitGeometry.rayAnglesFor(levelCount: 6), [74, 62, 50, 38, 26, 14]);
    });

    test("keep the five-level span for fewer levels and widen it for more", () {
      expect(OrbitGeometry.rayAnglesFor(levelCount: 1), [40]);
      expect(OrbitGeometry.rayAnglesFor(levelCount: 3), [68, 40, 12]);
      final seven = OrbitGeometry.rayAnglesFor(levelCount: 7);
      expect(seven.first, 80);
      expect(seven.last, closeTo(16, 1e-9));
      expect(OrbitGeometry.rayAnglesFor(levelCount: 0), isEmpty);
    });
  });

  group("rings", () {
    test("use the mock radii, outermost first, on a 393 pt phone", () {
      final geometry = _geometry(orbits: orbits);

      expect(geometry.scale, 1);
      expect(geometry.ringRadii, [315, 260, 205, 150]);
    });

    test("fewer rings keep the inner radii", () {
      final two = orbits.copyWith(rings: [opus, sonnet], totalModels: 2);

      expect(_geometry(orbits: two).ringRadii, [205, 150]);
    });

    test("shrink to fit a narrow overlay", () {
      final geometry = _geometry(orbits: orbits, size: const Size(320, 700));

      expect(geometry.scale, lessThan(1));
      expect(geometry.ringRadii.first, closeTo(315 * geometry.scale, 1e-9));
    });
  });

  group("hit test", () {
    final geometry = _geometry(orbits: orbits);

    test("finds every dot at its centre", () {
      for (var ringIndex = 0; ringIndex < orbits.rings.length; ringIndex++) {
        for (var levelIndex = 0; levelIndex < orbits.rings[ringIndex].levels.length; levelIndex++) {
          expect(
            geometry.hitTest(geometry.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex)),
            OrbitLevelTarget(ringIndex: ringIndex, levelIndex: levelIndex),
          );
        }
      }
    });

    test("gives each ring the band halfway to its neighbours", () {
      // Opus (260) and Sonnet (205) meet at 232.5.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 233, angle: 40)),
        const OrbitLevelTarget(ringIndex: 1, levelIndex: 2),
      );
      expect(
        geometry.hitTest(geometry.pointAt(radius: 232, angle: 40)),
        const OrbitLevelTarget(ringIndex: 2, levelIndex: 2),
      );
      // The outermost and innermost bands reach 34 pt past their ring.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 348, angle: 40)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 2),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 350, angle: 40)), isNull);
      expect(geometry.hitTest(geometry.pointAt(radius: 117, angle: 60)), const OrbitNameTarget(ringIndex: 3));
      expect(geometry.hitTest(geometry.pointAt(radius: 115, angle: 60)), isNull);
    });

    test("splits a ring halfway between its dots", () {
      // Fable's high (40°) and xhigh (26°) meet at 33°.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 315, angle: 33.1)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 2),
      );
      expect(
        geometry.hitTest(geometry.pointAt(radius: 315, angle: 32.9)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 3),
      );
    });

    test("ends the last patch 7° past the strongest dot, clear of the fast toggle", () {
      expect(
        geometry.hitTest(geometry.pointAt(radius: 315, angle: 5.1)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 4),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 315, angle: 4.9)), isNull);
    });

    test("gives the name the start of the ring, up to 7° before its first dot", () {
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 95)), const OrbitNameTarget(ringIndex: 1));
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 75.1)), const OrbitNameTarget(ringIndex: 1));
      expect(
        geometry.hitTest(geometry.pointAt(radius: 260, angle: 74.9)),
        const OrbitLevelTarget(ringIndex: 1, levelIndex: 0),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 97)), isNull);
    });

    test("makes a ring without levels one name patch", () {
      expect(geometry.hitTest(geometry.levellessDotCenter(ringIndex: 3)), const OrbitNameTarget(ringIndex: 3));
      expect(geometry.hitTest(geometry.pointAt(radius: 150, angle: 4)), const OrbitNameTarget(ringIndex: 3));
    });

    test("finds the fast toggle", () {
      expect(geometry.hitTest(const Offset(330, 610)), const OrbitFastToggleTarget());
    });

    test("offers the All pill only when the catalog has more models than rings", () {
      expect(geometry.showsAllModels, isFalse);
      expect(geometry.hitTest(geometry.allModelsCenter), isNull);

      final more = _geometry(orbits: orbits.copyWith(totalModels: 6));
      expect(more.showsAllModels, isTrue);
      expect(more.hitTest(more.allModelsCenter), const OrbitAllModelsTarget());
    });
  });
}
