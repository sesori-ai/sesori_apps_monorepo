// JSON and editable fields are external inputs, decoded to the closed MotionValue variants here.
// ignore_for_file: no_slop_linter/prefer_specific_type

import "dart:convert";

import "package:flutter/animation.dart";

/// Curve names survive preset round trips; hosts choose their existing default.
enum MotionEasing({required final String label, required final Curve curve}) {
  linear(label: "Linear", curve: Curves.linear),
  easeOut(label: "Ease out", curve: Curves.easeOut),
  easeOutCubic(label: "Ease out cubic", curve: Curves.easeOutCubic),
  easeInOutCubic(label: "Ease in/out cubic", curve: Curves.easeInOutCubic),
  smooth(label: "Smooth · 0.23, 1, 0.32, 1", curve: Cubic(0.23, 1, 0.32, 1)),
  drawer(label: "Drawer · 0.32, 0.72, 0, 1", curve: Cubic(0.32, 0.72, 0, 1)),
}

sealed class const MotionParameter({
  required final String id,
  required final String label,
  required final String source,
}) {
  MotionValue get initial;
  MotionValue decode({required Object? value});
}

final class const MotionDuration({
  required super.id,
  required super.label,
  required super.source,
  required final Duration initialValue,
  required final Duration min,
  required final Duration max,
}) extends MotionParameter {
  @override
  MotionValue get initial => MotionDurationValue(value: initialValue);

  @override
  MotionValue decode({required Object? value}) {
    if (value is! int || value < min.inMilliseconds || value > max.inMilliseconds) {
      throw FormatException("$label must be ${min.inMilliseconds}–${max.inMilliseconds} ms.");
    }
    return MotionDurationValue(value: Duration(milliseconds: value));
  }
}

final class const MotionNumber({
  required super.id,
  required super.label,
  required super.source,
  required final double initialValue,
  required final double min,
  required final double max,
  required final double step,
}) extends MotionParameter {
  @override
  MotionValue get initial => MotionNumberValue(value: initialValue);

  @override
  MotionValue decode({required Object? value}) {
    if (value is! num || !value.isFinite || value < min || value > max) {
      throw FormatException("$label must be between $min and $max.");
    }
    return MotionNumberValue(value: value.toDouble());
  }
}

final class const MotionCurve({
  required super.id,
  required super.label,
  required super.source,
  required final MotionEasing initialValue,
}) extends MotionParameter {
  @override
  MotionValue get initial => MotionCurveValue(value: initialValue);

  @override
  MotionValue decode({required Object? value}) {
    for (final curve in MotionEasing.values) {
      if (curve.name == value) return MotionCurveValue(value: curve);
    }
    throw FormatException("Unknown easing for $label.");
  }
}

sealed class const MotionValue() {
  Object get json;
}

final class const MotionDurationValue({required final Duration value}) extends MotionValue {
  @override
  Object get json => value.inMilliseconds;
}

final class const MotionNumberValue({required final double value}) extends MotionValue {
  @override
  Object get json => value;
}

final class const MotionCurveValue({required final MotionEasing value}) extends MotionValue {
  @override
  Object get json => value.name;
}

/// A host declares a finite list, including transitions currently off screen.
class const MotionTarget({
  required final String id,
  required final String label,
  required final List<MotionParameter> parameters,
});

/// Immutable values captured by the preview when replay begins.
class MotionSnapshot {
  const new() : _values = const {};

  new _({required Map<String, MotionValue> values}) : _values = Map.unmodifiable(values);

  final Map<String, MotionValue> _values;

  MotionValue valueOf({required MotionParameter parameter}) => _values[parameter.id] ?? parameter.initial;

  Duration duration({required MotionDuration parameter}) => switch (valueOf(parameter: parameter)) {
    MotionDurationValue(:final value) => value,
    MotionNumberValue() || MotionCurveValue() => throw StateError("${parameter.id} is not a duration."),
  };

  double number({required MotionNumber parameter}) => switch (valueOf(parameter: parameter)) {
    MotionNumberValue(:final value) => value,
    MotionDurationValue() || MotionCurveValue() => throw StateError("${parameter.id} is not a number."),
  };

  MotionEasing easing({required MotionCurve parameter}) => switch (valueOf(parameter: parameter)) {
    MotionCurveValue(:final value) => value,
    MotionDurationValue() || MotionNumberValue() => throw StateError("${parameter.id} is not an easing."),
  };

  MotionSnapshot withInput({required MotionParameter parameter, required Object? input}) => MotionSnapshot._(
    values: {
      ..._values,
      parameter.id: parameter.decode(value: input),
    },
  );

  MotionSnapshot reset({required MotionTarget target}) => MotionSnapshot._(
    values: {..._values}..removeWhere((id, _) => target.parameters.any((parameter) => parameter.id == id)),
  );
}

String encodeMotionPreset({
  required String fixtureId,
  required List<MotionTarget> targets,
  required MotionSnapshot values,
}) => const JsonEncoder.withIndent("  ").convert({
  "version": 1,
  "fixture": fixtureId,
  "values": {
    for (final target in targets)
      for (final parameter in target.parameters) parameter.id: values.valueOf(parameter: parameter).json,
  },
});

MotionSnapshot decodeMotionPreset({
  required String text,
  required String fixtureId,
  required List<MotionTarget> targets,
}) {
  final Object? decoded = jsonDecode(text);
  if (decoded is! Map<String, dynamic> || decoded["version"] != 1 || decoded["fixture"] != fixtureId) {
    throw const FormatException("This preset belongs to another preview or version.");
  }
  final Object? rawValues = decoded["values"];
  if (rawValues is! Map<String, dynamic>) throw const FormatException("The preset has no animation values.");
  final parameters = {
    for (final target in targets)
      for (final parameter in target.parameters) parameter.id: parameter,
  };
  if (rawValues.length != parameters.length || !rawValues.keys.every(parameters.containsKey)) {
    throw const FormatException("This preset does not match this preview’s animation controls.");
  }
  return MotionSnapshot._(
    values: {for (final entry in parameters.entries) entry.key: entry.value.decode(value: rawValues[entry.key])},
  );
}
