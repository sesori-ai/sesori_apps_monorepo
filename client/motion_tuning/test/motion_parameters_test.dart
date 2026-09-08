import "dart:convert";

import "package:flutter_test/flutter_test.dart";
import "package:sesori_motion_tuning/src/motion_parameters.dart";

const _duration = MotionDuration(
  id: "test.entrance.duration",
  label: "Entrance duration",
  source: "test fixture",
  initialValue: Duration(milliseconds: 260),
  min: Duration.zero,
  max: Duration(seconds: 2),
);
const _scale = MotionNumber(
  id: "test.entrance.scale",
  label: "Entrance scale",
  source: "test fixture",
  initialValue: 0.97,
  min: 0.5,
  max: 1.5,
  step: 0.01,
);
const _curve = MotionCurve(
  id: "test.entrance.curve",
  label: "Entrance easing",
  source: "test fixture",
  initialValue: MotionEasing.smooth,
);
const _collapseDuration = MotionDuration(
  id: "test.collapse.duration",
  label: "Collapse duration",
  source: "test fixture",
  initialValue: Duration(milliseconds: 200),
  min: Duration.zero,
  max: Duration(seconds: 2),
);
const _entrance = MotionTarget(id: "test.entrance", label: "Entrance", parameters: [_duration, _scale, _curve]);
const _collapse = MotionTarget(id: "test.collapse", label: "Collapse", parameters: [_collapseDuration]);
const _targets = [_entrance, _collapse];

Map<String, Object?> _preset({required Map<String, Object?> values}) => {
  "version": 1,
  "fixture": "test",
  "values": values,
};

const _validValues = <String, Object?>{
  "test.entrance.duration": 420,
  "test.entrance.scale": 1.15,
  "test.entrance.curve": "easeOutCubic",
  "test.collapse.duration": 180,
};

MotionSnapshot _decode({required String text}) => decodeMotionPreset(text: text, fixtureId: "test", targets: _targets);

void main() {
  test("complete presets round trip duration, number, easing and untouched defaults", () {
    final edited = const MotionSnapshot()
        .withInput(parameter: _duration, input: 420)
        .withInput(parameter: _scale, input: 1.15)
        .withInput(parameter: _curve, input: MotionEasing.easeOutCubic.name);
    final text = encodeMotionPreset(fixtureId: "test", targets: _targets, values: edited);
    final restored = _decode(text: text);

    expect(restored.duration(parameter: _duration), const Duration(milliseconds: 420));
    expect(restored.number(parameter: _scale), 1.15);
    expect(restored.easing(parameter: _curve), MotionEasing.easeOutCubic);
    expect(restored.duration(parameter: _collapseDuration), _collapseDuration.initialValue);
    expect(jsonDecode(text), {
      "version": 1,
      "fixture": "test",
      "values": {..._validValues, _collapseDuration.id: 200},
    });
  });

  test("edits and target reset preserve previous snapshots and unrelated targets", () {
    const original = MotionSnapshot();
    final edited = original
        .withInput(parameter: _duration, input: 420)
        .withInput(parameter: _scale, input: 1.15)
        .withInput(parameter: _curve, input: MotionEasing.linear.name)
        .withInput(parameter: _collapseDuration, input: 180);
    final reset = edited.reset(target: _entrance);

    expect(original.duration(parameter: _duration), _duration.initialValue);
    expect(original.number(parameter: _scale), _scale.initialValue);
    expect(original.easing(parameter: _curve), _curve.initialValue);
    expect(original.duration(parameter: _collapseDuration), _collapseDuration.initialValue);
    expect(reset.duration(parameter: _duration), _duration.initialValue);
    expect(reset.number(parameter: _scale), _scale.initialValue);
    expect(reset.easing(parameter: _curve), _curve.initialValue);
    expect(reset.duration(parameter: _collapseDuration), const Duration(milliseconds: 180));
    expect(edited.duration(parameter: _duration), const Duration(milliseconds: 420));
    expect(edited.number(parameter: _scale), 1.15);
    expect(edited.easing(parameter: _curve), MotionEasing.linear);
  });

  final invalidPresets = <String, Object?>{
    "wrong fixture": {..._preset(values: _validValues), "fixture": "another-preview"},
    "wrong version": {..._preset(values: _validValues), "version": 2},
    "missing values": {"version": 1, "fixture": "test"},
    "non-object values": {..._preset(values: _validValues), "values": <Object?>[]},
    "missing parameter": _preset(values: {..._validValues}..remove(_scale.id)),
    "unknown parameter": _preset(values: {..._validValues, "test.unknown": 1}),
    "substituted parameter": _preset(values: {..._validValues, "test.unknown": 1}..remove(_scale.id)),
    "duration below range": _preset(values: {..._validValues, _duration.id: -1}),
    "duration above range": _preset(values: {..._validValues, _duration.id: 2001}),
    "fractional duration": _preset(values: {..._validValues, _duration.id: 420.5}),
    "number below range": _preset(values: {..._validValues, _scale.id: 0.49}),
    "number above range": _preset(values: {..._validValues, _scale.id: 1.51}),
    "number wrong type": _preset(values: {..._validValues, _scale.id: "1.15"}),
    "unknown easing": _preset(values: {..._validValues, _curve.id: "inventedCurve"}),
    "null value": _preset(values: {..._validValues, _collapseDuration.id: null}),
    "non-object document": [],
  };
  for (final entry in invalidPresets.entries) {
    test("rejects ${entry.key} without replacing the active snapshot", () {
      final previous = const MotionSnapshot().withInput(parameter: _duration, input: 700);
      var active = previous;

      expect(() => active = _decode(text: jsonEncode(entry.value)), throwsFormatException);
      expect(identical(active, previous), isTrue);
      expect(active.duration(parameter: _duration), const Duration(milliseconds: 700));
      expect(active.number(parameter: _scale), _scale.initialValue);
    });
  }

  for (final text in ["{", "null", "", jsonEncode(_preset(values: _validValues)).replaceFirst("1.15", "1e999")]) {
    test("rejects malformed or nonfinite JSON: $text", () {
      expect(() => _decode(text: text), throwsFormatException);
    });
  }

  for (final input in [double.nan, double.infinity, double.negativeInfinity]) {
    test("rejects nonfinite numeric edit $input without mutating its snapshot", () {
      final previous = const MotionSnapshot().withInput(parameter: _scale, input: 1.15);

      expect(() => previous.withInput(parameter: _scale, input: input), throwsFormatException);
      expect(previous.number(parameter: _scale), 1.15);
    });
  }
}
