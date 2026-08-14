// ignore_for_file: no_slop_linter/avoid_bang_operator

import "dart:io";

final _catalogRoot = Directory.current.path;
final _pregoRoot = "$_catalogRoot/../module_prego";
final _outputPath = "$_catalogRoot/lib/src/inspector/prego_token_catalog.g.dart";

void main(List<String> args) {
  final generated = _generate();
  final output = File(_outputPath);

  if (args.contains("--check")) {
    if (!output.existsSync() || output.readAsStringSync() != generated) {
      stderr.writeln("$_outputPath is stale. Run `dart run tool/generate_inspector_tokens.dart`.");
      exitCode = 1;
    }
    return;
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(generated);
}

String _generate() {
  final semanticColors = _instanceFields(
    "$_pregoRoot/lib/theme/primitives/prego_colors.g.dart",
    type: "Color",
  );
  final primitiveColors = _staticFields(
    "$_pregoRoot/lib/theme/primitives/prego_color_primitives.g.dart",
    type: "Color",
  );
  final typography = _instanceFields(
    "$_pregoRoot/lib/theme/font/prego_text_theme.dart",
    type: "FontVariation",
  );
  final spacing = _staticFields(
    "$_pregoRoot/lib/theme/primitives/prego_spacing.g.dart",
    type: "double",
  );
  final spacingPrimitives = _staticFields(
    "$_pregoRoot/lib/theme/primitives/prego_spacing_primitives.g.dart",
    type: "double",
  );
  final radius = _staticFields(
    "$_pregoRoot/lib/theme/primitives/prego_radius.g.dart",
    type: "double",
  );
  final widths = _staticFields(
    "$_pregoRoot/lib/theme/primitives/prego_widths.g.dart",
    type: "double",
  );

  final buffer = StringBuffer()
    ..writeln("// GENERATED CODE - DO NOT MODIFY BY HAND")
    ..writeln("// Run: dart run tool/generate_inspector_tokens.dart")
    ..writeln("// ignore_for_file: lines_longer_than_80_chars")
    ..writeln()
    ..writeln('import "package:flutter/widgets.dart";')
    ..writeln('import "package:theme_prego/module_prego.dart";')
    ..writeln('import "package:theme_prego/theme/primitives/prego_color_primitives.g.dart";')
    ..writeln()
    ..writeln('import "prego_inspection_tokens.dart";')
    ..writeln()
    ..writeln("List<PregoInspectionToken<Color>> buildPregoInspectionColorTokens(PregoColors colors) => [");

  for (final field in semanticColors) {
    buffer.writeln(
      '  PregoInspectionToken(kind: PregoInspectionTokenKind.semanticColor, name: "${_kebab(field)}", reference: "context.prego.colors.$field", value: colors.$field),',
    );
  }
  for (final field in primitiveColors) {
    buffer.writeln(
      '  PregoInspectionToken(kind: PregoInspectionTokenKind.primitiveColor, name: "${_kebab(field)}", reference: "PregoColorPrimitives.$field", value: PregoColorPrimitives.$field),',
    );
  }
  buffer
    ..writeln("];")
    ..writeln()
    ..writeln(
      "List<PregoInspectionToken<TextStyle>> buildPregoInspectionTypographyTokens(PregoTextTheme theme) => [",
    );

  const weights = ["light", "regular", "medium", "bold", "black"];
  for (final scale in typography) {
    for (final weight in weights) {
      buffer.writeln(
        '  PregoInspectionToken(kind: PregoInspectionTokenKind.typography, name: "${_kebab(scale)} / $weight", reference: "context.prego.textTheme.$scale.$weight", value: theme.$scale.$weight),',
      );
    }
  }
  buffer
    ..writeln("];")
    ..writeln()
    ..writeln("const pregoInspectionDimensionTokens = <PregoInspectionToken<double>>[");

  _writeDimensions(
    buffer,
    fields: spacing,
    kind: "spacing",
    className: "PregoSpacing",
    referencePrefix: "context.prego.spacing",
  );
  _writeDimensions(
    buffer,
    fields: spacingPrimitives,
    kind: "spacingPrimitive",
    className: "PregoSpacingPrimitives",
    referencePrefix: "PregoSpacingPrimitives",
  );
  _writeDimensions(
    buffer,
    fields: radius,
    kind: "radius",
    className: "PregoRadius",
    referencePrefix: "context.prego.radius",
  );
  _writeDimensions(
    buffer,
    fields: widths,
    kind: "width",
    className: "PregoWidths",
    referencePrefix: "context.prego.widths",
  );
  buffer.writeln("];\n");
  return buffer.toString();
}

void _writeDimensions(
  StringBuffer buffer, {
  required List<String> fields,
  required String kind,
  required String className,
  required String referencePrefix,
}) {
  for (final field in fields) {
    buffer.writeln(
      '  PregoInspectionToken(kind: PregoInspectionTokenKind.$kind, name: "${_kebab(field)}", reference: "$referencePrefix.$field", value: $className.$field),',
    );
  }
}

List<String> _instanceFields(String path, {required String type}) {
  final source = File(path).readAsStringSync();
  return RegExp("final $type (\\w+);").allMatches(source).map((match) => match.group(1)!).toList();
}

List<String> _staticFields(String path, {required String type}) {
  final source = File(path).readAsStringSync();
  return RegExp("static const $type (\\w+) =").allMatches(source).map((match) => match.group(1)!).toList();
}

String _kebab(String value) =>
    value.replaceAllMapped(RegExp("([a-z0-9])([A-Z])"), (match) => "${match.group(1)}-${match.group(2)}").toLowerCase();
