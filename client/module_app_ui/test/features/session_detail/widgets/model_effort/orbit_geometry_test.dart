import "dart:ui";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/model_effort/orbit_geometry.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show EffortLevel, ModelOrbits;

import "orbits_fixture.dart";

/// The agreed mock's phone: a 393 x 700 screen with the rings' centre at
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
    test("rise upwards, five levels from 10° to 82°", () {
      expect(OrbitGeometry.rayAnglesFor(levelCount: 5), [10, 28, 46, 64, 82]);
      final six = OrbitGeometry.rayAnglesFor(levelCount: 6);
      expect(six.first, 10);
      expect(six.last, closeTo(83, 1e-9));
    });

    test("keep the five-level span for fewer levels and lift the strongest for more", () {
      expect(OrbitGeometry.rayAnglesFor(levelCount: 1), [46]);
      expect(OrbitGeometry.rayAnglesFor(levelCount: 3), [10, 46, 82]);
      final seven = OrbitGeometry.rayAnglesFor(levelCount: 7);
      expect(seven.first, 10);
      expect(seven.last, closeTo(84, 1e-9));
      expect(OrbitGeometry.rayAnglesFor(levelCount: 0), isEmpty);
    });
  });

  group("direction and spacing", () {
    test("puts the strongest level right after the name and the weakest farthest from it", () {
      final geometry = _geometry(orbits: orbits);
      for (final ringIndex in [0, 1, 2]) {
        final strongest = orbits.rings[ringIndex].levels.length - 1;
        final strongestAngle = geometry.levelAngle(ringIndex: ringIndex, levelIndex: strongest);
        expect(geometry.nameEndAngle(ringIndex: ringIndex), greaterThan(strongestAngle));
        for (var levelIndex = 0; levelIndex < strongest; levelIndex++) {
          expect(geometry.levelAngle(ringIndex: ringIndex, levelIndex: levelIndex), lessThan(strongestAngle));
        }
      }
      // Up the screen means more effort.
      expect(
        geometry.dotCenter(ringIndex: 1, levelIndex: 4).dy,
        lessThan(geometry.dotCenter(ringIndex: 1, levelIndex: 0).dy),
      );
    });

    test("spaces five dots on the innermost ring at least 44 pt apart on a 393 pt phone", () {
      // Opus innermost, so the smallest ring carries the whole ladder.
      final geometry = _geometry(orbits: orbits.copyWith(rings: [fable, sonnet, haiku, opus]));
      expect(geometry.scale, 1);
      for (var levelIndex = 1; levelIndex < 5; levelIndex++) {
        final gap =
            (geometry.dotCenter(ringIndex: 3, levelIndex: levelIndex) -
                    geometry.dotCenter(ringIndex: 3, levelIndex: levelIndex - 1))
                .distance;
        expect(gap, greaterThanOrEqualTo(44));
      }
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
        geometry.hitTest(geometry.pointAt(radius: 233, angle: 46)),
        const OrbitLevelTarget(ringIndex: 1, levelIndex: 2),
      );
      expect(
        geometry.hitTest(geometry.pointAt(radius: 232, angle: 46)),
        const OrbitLevelTarget(ringIndex: 2, levelIndex: 2),
      );
      // The outermost and innermost bands reach 34 pt past their ring.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 348, angle: 46)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 2),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 350, angle: 46)), isNull);
      expect(geometry.hitTest(geometry.pointAt(radius: 117, angle: 60)), const OrbitNameTarget(ringIndex: 3));
      expect(geometry.hitTest(geometry.pointAt(radius: 115, angle: 60)), isNull);
    });

    test("splits a ring halfway between its dots", () {
      // Fable's high (46°) and xhigh (64°) meet at 55°.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 315, angle: 54.9)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 2),
      );
      expect(
        geometry.hitTest(geometry.pointAt(radius: 315, angle: 55.1)),
        const OrbitLevelTarget(ringIndex: 0, levelIndex: 3),
      );
    });

    test("ends the weakest patch 7° past the weakest dot", () {
      // Sonnet, clear of the fast toggle, which keeps its own corner.
      expect(
        geometry.hitTest(geometry.pointAt(radius: 205, angle: 3.1)),
        const OrbitLevelTarget(ringIndex: 2, levelIndex: 0),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 205, angle: 2.9)), isNull);
      expect(geometry.hitTest(geometry.pointAt(radius: 315, angle: 3.1)), const OrbitFastToggleTarget());
    });

    test("gives the name the start of the ring, up to 7° before its strongest dot", () {
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 95)), const OrbitNameTarget(ringIndex: 1));
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 89.1)), const OrbitNameTarget(ringIndex: 1));
      expect(
        geometry.hitTest(geometry.pointAt(radius: 260, angle: 88.9)),
        const OrbitLevelTarget(ringIndex: 1, levelIndex: 4),
      );
      expect(geometry.hitTest(geometry.pointAt(radius: 260, angle: 97)), isNull);
      // Sonnet stops at high, so its name reaches down to just above it.
      expect(geometry.hitTest(geometry.pointAt(radius: 205, angle: 53.1)), const OrbitNameTarget(ringIndex: 2));
      expect(
        geometry.hitTest(geometry.pointAt(radius: 205, angle: 52.9)),
        const OrbitLevelTarget(ringIndex: 2, levelIndex: 2),
      );
    });

    test("makes a ring without levels one name patch", () {
      expect(geometry.hitTest(geometry.levellessDotCenter(ringIndex: 3)), const OrbitNameTarget(ringIndex: 3));
      expect(geometry.hitTest(geometry.pointAt(radius: 150, angle: 4)), const OrbitNameTarget(ringIndex: 3));
    });

    test("finds the fast toggle", () {
      expect(geometry.hitTest(const Offset(330, 610)), const OrbitFastToggleTarget());
    });

    test("fits the whole ladder, OFF to ULTRA, with every patch its own", () {
      final rings = [
        for (final name in ["A", "B", "C", "D"])
          orbitRing(modelID: name, name: name, levels: EffortLevel.values, fast: false),
      ];
      final full = _geometry(
        orbits: ModelOrbits(
          rings: rings,
          levels: EffortLevel.values,
          totalModels: 4,
          current: rings.first,
          currentLevel: EffortLevel.off,
        ),
      );

      expect(full.scale, 1);
      expect(full.rayAngles.first, 10);
      expect(full.rayAngles.last, closeTo(85, 1e-9));
      for (var ringIndex = 0; ringIndex < rings.length; ringIndex++) {
        final name = full.namePatch(ringIndex: ringIndex);
        expect(name.fromAngle, greaterThan(name.toAngle));
        var reached = name.toAngle;
        // From ULTRA beside the name down to OFF.
        for (var levelIndex = EffortLevel.values.length - 1; levelIndex >= 0; levelIndex--) {
          final patch = full.levelPatch(ringIndex: ringIndex, levelIndex: levelIndex);
          expect(patch.fromAngle, reached);
          expect(patch.toAngle, lessThan(patch.fromAngle));
          reached = patch.toAngle;
          expect(
            full.hitTest(full.dotCenter(ringIndex: ringIndex, levelIndex: levelIndex)),
            OrbitLevelTarget(ringIndex: ringIndex, levelIndex: levelIndex),
          );
        }
      }
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
