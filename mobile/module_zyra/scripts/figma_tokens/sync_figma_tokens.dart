// ignore_for_file: avoid_print

/// Figma → Dart design token sync script.
///
/// Reads an exported Figma plugin JSON and regenerates the following files
/// (suffixed `.g.dart` to signal they are auto-generated — do not edit by hand):
///   - `zyra_color_primitives.g.dart`
///   - `zyra_colors.g.dart`
///   - `zyra_spacing_primitives.g.dart`
///   - `zyra_spacing.g.dart`
///   - `zyra_radius.g.dart`
///   - `zyra_widths.g.dart`
///
/// Figma is the single source of truth for all token values. The pipeline is
/// strictly one-directional: JSON in → Dart files out. The generated files are
/// never read back by this script.
///
/// The architecture mirrors Figma's variable structure:
/// - **Color Primitives** (mode-invariant base palette): `ZyraColorPrimitives`
/// - **Semantic colors** (Dark/Light modes referencing primitives): `ZyraColors`
/// - **Spacing Primitives** (numeric spacing scale): `ZyraSpacingPrimitives`
/// - **Semantic spacing** (named tokens referencing primitives): `ZyraSpacing`
/// - **Radius** (border radius tokens): `ZyraRadius`
/// - **Widths** (width tokens referencing primitives): `ZyraWidths`
///
/// Usage:
/// ```bash
/// dart run scripts/figma_tokens/sync_figma_tokens.dart generate
/// ```
library;

import "dart:convert";
import "dart:io";

// =============================================================================
// Paths (relative to project root)
// =============================================================================

final _projectRoot = _findProjectRoot();
final _jsonPath = "$_projectRoot/scripts/figma_tokens/figma_tokens.json";
final _primitivesPath = "$_projectRoot/lib/theme/primitives/zyra_color_primitives.g.dart";
final _colorsPath = "$_projectRoot/lib/theme/primitives/zyra_colors.g.dart";
final _spacingPrimitivesPath = "$_projectRoot/lib/theme/primitives/zyra_spacing_primitives.g.dart";
final _spacingPath = "$_projectRoot/lib/theme/primitives/zyra_spacing.g.dart";
final _radiusPath = "$_projectRoot/lib/theme/primitives/zyra_radius.g.dart";
final _widthsPath = "$_projectRoot/lib/theme/primitives/zyra_widths.g.dart";

// =============================================================================
// Naming exceptions — Figma semantic names that don't follow pure kebab→camel
// =============================================================================

const _nameOverrides = <String, String>{
  "shadow-skeumorphic-inner-border": "skeuomorphicInnerBorder",
  "shadow-skeumorphic": "skeuomorphicShadow",
  "Black-white-inversed": "blackWhiteInversed",
};

// =============================================================================
// Semantic category display names and ordering
// =============================================================================

const _categoryOrder = <String>[
  "Text",
  "Border",
  "Foreground",
  "Background",
  "Effects",
  "Shadows",
  "Buttons",
  "Icons",
  "Alpha",
  "Utility",
];

const _categoryHeaders = <String, String>{
  "Text": "Text Colors - Figma: Colors/Text/*",
  "Border": "Border Colors - Figma: Colors/Border/*",
  "Foreground": "Foreground Colors - Figma: Colors/Foreground/*",
  "Background": "Background Colors - Figma: Colors/Background/*",
  "Effects": "Effects - Figma: Colors/Effects/*",
  "Shadows": "Effects - Figma: Colors/Effects/Shadows/*",
  "Buttons": "Component Colors - Buttons",
  "Icons": "Component Colors - Icons",
  "Alpha": "Component Colors - Alpha (mode-invariant)",
  "Utility": "Utility Colors",
};

// =============================================================================
// Main
// =============================================================================

void main(List<String> args) {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  final command = args.first;

  switch (command) {
    case "generate":
      _runGenerate();
    case "--help" || "-h":
      _printUsage();
    default:
      print("Unknown command: $command");
      _printUsage();
      exit(1);
  }
}

void _printUsage() {
  print("""
Usage: dart run scripts/figma_tokens/sync_figma_tokens.dart generate

Reads scripts/figma_tokens/figma_tokens.json and regenerates:
  lib/.../zyra_color_primitives.g.dart
  lib/.../zyra_colors.g.dart
  lib/.../zyra_spacing_primitives.g.dart
  lib/.../zyra_spacing.g.dart
  lib/.../zyra_radius.g.dart
  lib/.../zyra_widths.g.dart
""");
}

// =============================================================================
// Plugin export processing
// =============================================================================

/// Transforms the Figma Plugin API console export into the processed format
/// used by the generator.
///
/// Plugin export shape:
/// ```json
/// {
///   "Primitives": { "modes": [...], "variables": [{ "name": "...", "valuesByMode": {...} }] },
///   "Color modes": { "modes": [...], "variables": [...] }
/// }
/// ```
///
/// Resolved alias values contain an `_alias` key with the referenced variable name.
Map<String, dynamic> _processPluginExport(Map<String, dynamic> json) {
  // Find collections by name
  Map<String, dynamic>? primitivesCollection;
  Map<String, dynamic>? colorModesCollection;
  Map<String, dynamic>? spacingCollection;
  Map<String, dynamic>? radiusCollection;
  Map<String, dynamic>? widthsCollection;
  Map<String, dynamic>? containersCollection;
  String? darkModeId;
  String? lightModeId;

  for (final entry in json.entries) {
    final name = entry.key.toLowerCase();
    final collection = entry.value as Map<String, dynamic>;
    final modes = collection["modes"] as List<dynamic>;

    if (name.contains("primitives") || name == "primitives") {
      primitivesCollection = collection;
    } else if (name.contains("color mode")) {
      colorModesCollection = collection;
      for (final mode in modes) {
        final m = mode as Map<String, dynamic>;
        final modeName = (m["name"] as String).toLowerCase();
        if (modeName.contains("dark")) {
          darkModeId = m["modeId"] as String;
        } else if (modeName.contains("light")) {
          lightModeId = m["modeId"] as String;
        }
      }
    } else if (entry.key == "Spacing") {
      spacingCollection = collection;
    } else if (entry.key == "Radius") {
      radiusCollection = collection;
    } else if (entry.key == "Widths") {
      widthsCollection = collection;
    } else if (entry.key == "Containers") {
      containersCollection = collection;
    }
  }

  if (primitivesCollection == null) {
    print("Warning: No 'Primitives' collection found. Available:");
    for (final key in json.keys) {
      print("  $key");
    }
  }

  if (darkModeId == null || lightModeId == null) {
    print("Error: Could not find Dark/Light modes in Color modes collection");
    print("Available collections:");
    for (final entry in json.entries) {
      final collection = entry.value as Map<String, dynamic>;
      final modes = collection["modes"] as List<dynamic>;
      print("  ${entry.key}: ${modes.map((m) => (m as Map)["name"]).join(", ")}");
    }
    exit(1);
  }

  // Process primitives (single-mode base palette)
  final primitives = <Map<String, dynamic>>[];
  if (primitivesCollection != null) {
    final variables = primitivesCollection["variables"] as List<dynamic>;
    for (final v in variables) {
      final variable = v as Map<String, dynamic>;
      final name = variable["name"] as String;
      final valuesByMode = variable["valuesByMode"] as Map<String, dynamic>;

      // Take the first (and only) mode value — skip non-map values (FLOAT variables)
      Map<String, double>? color;
      for (final val in valuesByMode.values) {
        if (val is! Map<String, dynamic>) continue;
        final m = val;
        if (!m.containsKey("r")) continue;
        color = {
          "r": (m["r"] as num).toDouble(),
          "g": (m["g"] as num).toDouble(),
          "b": (m["b"] as num).toDouble(),
          "a": (m["a"] as num).toDouble(),
        };
        break;
      }

      if (color == null) {
        // FLOAT variables (e.g. Spacing/*) are handled separately — skip silently
        final resolvedType = variable["resolvedType"] as String?;
        if (resolvedType != "FLOAT") {
          print("Warning: Could not resolve primitive color for $name, skipping");
        }
        continue;
      }

      // Parse path: "Colors/Brand Blue/25" → group="Brand Blue", shade="25"
      final parts = name.split("/");
      final shade = parts.last;
      final group = parts.length > 2 ? parts.sublist(1, parts.length - 1).join("/") : parts.first;

      primitives.add({
        "figmaPath": name,
        "group": group,
        "shade": shade,
        "color": color,
      });
    }
  }

  // Process semantic colors (Color modes collection, two modes)
  final semanticColors = <Map<String, dynamic>>[];
  if (colorModesCollection != null) {
    final variables = colorModesCollection["variables"] as List<dynamic>;
    for (final v in variables) {
      final variable = v as Map<String, dynamic>;
      final name = variable["name"] as String;
      final valuesByMode = variable["valuesByMode"] as Map<String, dynamic>;

      final parts = name.split("/");
      // Strip parenthetical suffix: "text-primary (900)" → "text-primary"
      final figmaName = _stripParenthetical(parts.last);
      final category = _resolveCategory(parts);

      final darkRaw = valuesByMode[darkModeId] as Map<String, dynamic>?;
      final lightRaw = valuesByMode[lightModeId] as Map<String, dynamic>?;

      if (darkRaw == null || lightRaw == null) {
        print("Warning: Missing mode value for $name, skipping");
        continue;
      }

      final darkEntry = _resolvePluginModeValue(darkRaw);
      final lightEntry = _resolvePluginModeValue(lightRaw);

      if (darkEntry == null || lightEntry == null) {
        print("Warning: Could not resolve semantic color for $name, skipping");
        continue;
      }

      semanticColors.add({
        "figmaPath": name,
        "category": category,
        "figmaName": figmaName,
        "dark": darkEntry,
        "light": lightEntry,
      });
    }
  }

  // Sort semantics by category order
  semanticColors.sort((a, b) {
    final catA = _categoryOrder.indexOf(a["category"] as String);
    final catB = _categoryOrder.indexOf(b["category"] as String);
    final effectiveCatA = catA == -1 ? _categoryOrder.length : catA;
    final effectiveCatB = catB == -1 ? _categoryOrder.length : catB;
    if (effectiveCatA != effectiveCatB) return effectiveCatA.compareTo(effectiveCatB);
    return _naturalCompare(a["figmaName"] as String, b["figmaName"] as String);
  });

  // Process FLOAT spacing primitives from Primitives collection
  final spacingPrimitives = _extractSpacingPrimitives(primitivesCollection);

  // Process FLOAT semantic collections
  final spacingTokens = _extractFloatTokens(spacingCollection, stripPrefix: "spacing");
  final radiusTokens = _extractFloatTokens(radiusCollection, stripPrefix: "radius");
  final widthTokens = _extractFloatTokens(widthsCollection, stripPrefix: "width");
  final containerTokens = _extractFloatTokens(containersCollection);

  return {
    "primitives": primitives,
    "semanticColors": semanticColors,
    "spacingPrimitives": spacingPrimitives,
    "spacingTokens": spacingTokens,
    "radiusTokens": radiusTokens,
    "widthTokens": widthTokens,
    "containerTokens": containerTokens,
  };
}

/// Resolves a single mode value from the plugin export.
///
/// Values are either:
/// - Direct RGBA: `{ "r": ..., "g": ..., "b": ..., "a": ... }`
/// - Resolved alias with reference: `{ "r": ..., ..., "_alias": "Colors/Brand Blue/500" }`
/// - Unresolvable alias (skipped): `{ "type": "VARIABLE_ALIAS", "id": "..." }`
Map<String, dynamic>? _resolvePluginModeValue(Map<String, dynamic> value) {
  // Unresolvable alias (old export format without resolution)
  if (value.containsKey("type") && value["type"] == "VARIABLE_ALIAS" && !value.containsKey("r")) {
    return null;
  }

  if (!value.containsKey("r")) return null;

  final color = {
    "r": (value["r"] as num).toDouble(),
    "g": (value["g"] as num).toDouble(),
    "b": (value["b"] as num).toDouble(),
    "a": (value["a"] as num).toDouble(),
  };

  final alias = value["_alias"] as String?;
  if (alias != null) {
    return {
      "type": "primitive",
      "primitiveRef": alias,
      "color": color,
    };
  }

  return {"type": "direct", "color": color};
}

/// Strips parenthetical suffixes from Figma names.
///
/// `text-primary (900)` → `text-primary`
/// `fg-primary (900)` → `fg-primary`
/// `border-primary` → `border-primary` (no change)
String _stripParenthetical(String name) {
  final idx = name.indexOf(" (");
  if (idx == -1) return name;
  return name.substring(0, idx);
}

// =============================================================================
// Category resolution
// =============================================================================

String _resolveCategory(List<String> pathParts) {
  if (pathParts.length < 2) return "Other";

  final second = pathParts.length > 1 ? pathParts[1] : "";
  final third = pathParts.length > 2 ? pathParts[2] : "";

  if (second == "Effects" && third == "Shadows") return "Shadows";

  final figmaName = pathParts.last;
  if (figmaName.startsWith("button-")) return "Buttons";
  if (figmaName.startsWith("icon-")) return "Icons";
  if (figmaName.startsWith("alpha-") || figmaName.startsWith("shadow-skeu")) return "Alpha";
  if (figmaName.startsWith("utility-")) return "Utility";

  return switch (second) {
    "Text" => "Text",
    "Border" => "Border",
    "Foreground" => "Foreground",
    "Background" => "Background",
    "Effects" => "Effects",
    _ => "Other",
  };
}

// =============================================================================
// Generate command
// =============================================================================

void _runGenerate() {
  final jsonFile = File(_jsonPath);
  if (!jsonFile.existsSync()) {
    print("Error: $_jsonPath not found.");
    print("Export variables from Figma using the plugin console, then save as scripts/figma_tokens/figma_tokens.json");
    exit(1);
  }

  final json = jsonDecode(jsonFile.readAsStringSync()) as Map<String, dynamic>;

  // Detect format: plugin export has collection names as keys,
  // processed format has "primitives"/"semanticColors"
  final Map<String, dynamic> processed;
  if (json.containsKey("primitives") && json.containsKey("semanticColors")) {
    processed = json;
  } else {
    print("Detected Figma plugin export format — processing...");
    processed = _processPluginExport(json);
  }

  final primitives = (processed["primitives"] as List<dynamic>).cast<Map<String, dynamic>>();
  final semanticColors = (processed["semanticColors"] as List<dynamic>).cast<Map<String, dynamic>>();

  print("Generating from ${primitives.length} color primitives + ${semanticColors.length} semantic colors...");

  // Build color primitive path → Dart name lookup
  final primitiveDartNames = <String, String>{};
  for (final p in primitives) {
    final path = p["figmaPath"] as String;
    final group = p["group"] as String;
    final shade = p["shade"] as String;
    primitiveDartNames[path] = _primitiveToDartName(group, shade);
  }

  _generatePrimitivesFile(primitives);
  _generateColorsFile(semanticColors, primitiveDartNames);

  print("Generated $_primitivesPath");
  print("Generated $_colorsPath");

  // Generate FLOAT token files
  final spacingPrimitives =
      (processed["spacingPrimitives"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final spacingTokens = (processed["spacingTokens"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final radiusTokens = (processed["radiusTokens"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final widthTokens = (processed["widthTokens"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];
  final containerTokens = (processed["containerTokens"] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

  // Build spacing primitive alias → Dart name lookup
  final spacingPrimitiveDartNames = <String, String>{};
  for (final p in spacingPrimitives) {
    spacingPrimitiveDartNames[p["figmaName"] as String] = p["dartName"] as String;
  }

  if (spacingPrimitives.isNotEmpty) {
    _generateSpacingPrimitivesFile(spacingPrimitives);
    print("Generated $_spacingPrimitivesPath");
  }

  if (spacingTokens.isNotEmpty || containerTokens.isNotEmpty) {
    _generateSpacingFile(spacingTokens, containerTokens, spacingPrimitiveDartNames);
    print("Generated $_spacingPath");
  }

  if (radiusTokens.isNotEmpty) {
    _generateRadiusFile(radiusTokens);
    print("Generated $_radiusPath");
  }

  if (widthTokens.isNotEmpty) {
    _generateWidthsFile(widthTokens, spacingPrimitiveDartNames);
    print("Generated $_widthsPath");
  }
}

// =============================================================================
// Primitives file generation
// =============================================================================

void _generatePrimitivesFile(List<Map<String, dynamic>> primitives) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln("// ignore_for_file: lines_longer_than_80_chars");
  buf.writeln();
  buf.writeln('import "dart:ui";');
  buf.writeln();
  buf.writeln("/// Figma primitive color palette — mode-invariant base values.");
  buf.writeln("///");
  buf.writeln("/// These map 1:1 to the Figma **Primitives** collection.");
  buf.writeln("/// Semantic tokens in [ZyraColorsDark] and [ZyraColorsLight] reference");
  buf.writeln("/// these constants, mirroring how Figma aliases work.");
  buf.writeln("///");
  buf.writeln("/// Do not use primitives directly in widgets — use semantic tokens via");
  buf.writeln("/// `context.zyra.colors.*` instead.");
  buf.writeln("abstract final class ZyraColorPrimitives {");

  // Group primitives by group name
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final p in primitives) {
    final group = p["group"] as String;
    grouped.putIfAbsent(group, () => []).add(p);
  }

  var first = true;
  for (final entry in grouped.entries) {
    final group = entry.key;
    final items = entry.value;

    if (!first) buf.writeln();
    first = false;

    buf.writeln("  // ===========================================================================");
    buf.writeln("  // $group");
    buf.writeln("  // ===========================================================================");

    for (final p in items) {
      final shade = p["shade"] as String;
      final rgba = p["color"] as Map<String, dynamic>;
      final hex = _rgbaToHex(rgba);
      final dartName = _primitiveToDartName(group, shade);

      buf.writeln();
      buf.writeln("  /// Figma: $group/$shade");
      buf.writeln("  static const Color $dartName = Color(0x$hex);");
    }
  }

  buf.writeln("}");

  final file = File(_primitivesPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

// =============================================================================
// Color file generation (semantic tokens)
// =============================================================================

void _generateColorsFile(
  List<Map<String, dynamic>> colors,
  Map<String, String> primitiveDartNames,
) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln("// ignore_for_file: lines_longer_than_80_chars");
  buf.writeln();
  buf.writeln('import "package:flutter/material.dart";');
  buf.writeln();
  buf.writeln('import "../../utils/lerp_utils.dart";');
  buf.writeln('import "zyra_color_primitives.g.dart";');

  // Build semantic color path → Dart name lookup for cross-referencing
  final semanticDartNames = <String, String>{};
  for (final c in colors) {
    final path = c["figmaPath"] as String;
    final name = c["figmaName"] as String;
    semanticDartNames[path] = _figmaNameToDart(name);
  }

  // --- ZyraColorsDark ---
  buf.writeln();
  _writeStaticColorClass(buf, "ZyraColorsDark", "Dark", colors, "dark", primitiveDartNames, semanticDartNames);

  // --- ZyraColorsLight ---
  buf.writeln();
  _writeStaticColorClass(buf, "ZyraColorsLight", "Light", colors, "light", primitiveDartNames, semanticDartNames);

  // --- ZyraColors ---
  buf.writeln();
  _writeSemanticColorClass(buf, colors);

  final file = File(_colorsPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

void _writeStaticColorClass(
  StringBuffer buf,
  String className,
  String modeLabel,
  List<Map<String, dynamic>> colors,
  String modeKey,
  Map<String, String> primitiveDartNames,
  Map<String, String> semanticDartNames,
) {
  buf.writeln("/// $modeLabel mode color tokens matching Figma specifications.");
  buf.writeln("///");
  buf.writeln("/// All colors are static const, enabling compile-time constant expressions.");
  buf.writeln("/// Colors reference [ZyraColorPrimitives] where Figma uses an alias,");
  buf.writeln("/// or inline hex where Figma uses a direct value.");
  buf.writeln("abstract final class $className {");

  String? lastCategory;
  for (final color in colors) {
    final category = color["category"] as String;
    final figmaName = color["figmaName"] as String;
    final figmaPath = color["figmaPath"] as String;
    final dartName = _figmaNameToDart(figmaName);
    final modeEntry = color[modeKey] as Map<String, dynamic>;
    final type = modeEntry["type"] as String;

    if (category != lastCategory) {
      if (lastCategory != null) buf.writeln();
      final header = _categoryHeaders[category] ?? category;
      buf.writeln("  // ===========================================================================");
      buf.writeln("  // $header");
      buf.writeln("  // ===========================================================================");
      lastCategory = category;
    }

    buf.writeln();

    if (type == "primitive") {
      final primitiveRef = modeEntry["primitiveRef"] as String;
      final primitiveDart = primitiveDartNames[primitiveRef];

      if (primitiveDart != null) {
        // Reference: strip the leading "Colors/" for the doc comment
        final shortRef = primitiveRef.startsWith("Colors/") ? primitiveRef.substring("Colors/".length) : primitiveRef;
        buf.writeln("  /// Figma: $figmaPath → $shortRef");
        buf.writeln("  static const Color $dartName = ZyraColorPrimitives.$primitiveDart;");
      } else {
        // Alias points to another semantic color — reference it within the same class
        final shortRef = primitiveRef.startsWith("Colors/") ? primitiveRef.substring("Colors/".length) : primitiveRef;
        final semanticDart = semanticDartNames[primitiveRef];
        buf.writeln("  /// Figma: $figmaPath → $shortRef");
        if (semanticDart != null) {
          buf.writeln("  static const Color $dartName = $className.$semanticDart;");
        } else {
          // Unresolvable reference — fall back to hex
          final rgba = modeEntry["color"] as Map<String, dynamic>;
          final hex = _rgbaToHex(rgba);
          buf.writeln("  static const Color $dartName = Color(0x$hex);");
        }
      }
    } else {
      // Direct hex value
      final rgba = modeEntry["color"] as Map<String, dynamic>;
      final hex = _rgbaToHex(rgba);
      buf.writeln("  /// Figma: $figmaPath");
      buf.writeln("  static const Color $dartName = Color(0x$hex);");
    }
  }

  buf.writeln("}");
}

void _writeSemanticColorClass(
  StringBuffer buf,
  List<Map<String, dynamic>> colors,
) {
  buf.writeln("/// Semantic color tokens that adapt to light/dark mode.");
  buf.writeln("///");
  buf.writeln('/// Maps directly to Figma "Color modes" variables.');
  buf.writeln("/// Property names follow Figma naming: `text-primary` → `textPrimary`.");
  buf.writeln("///");
  buf.writeln("/// Usage via `context.zyra`:");
  buf.writeln("/// ```dart");
  buf.writeln("/// Container(");
  buf.writeln("///   color: context.zyra.colors.bgPrimary,");
  buf.writeln("///   child: Text(");
  buf.writeln("///     'Hello',");
  buf.writeln("///     style: TextStyle(color: context.zyra.colors.textPrimary),");
  buf.writeln("///   ),");
  buf.writeln("/// )");
  buf.writeln("/// ```");
  buf.writeln("@immutable");
  buf.writeln("// ignore: use_enums, theme token containers need class semantics and static dark/light singletons");
  buf.writeln("final class ZyraColors {");

  // --- static const dark ---
  buf.writeln("  // ===========================================================================");
  buf.writeln("  // Dark Mode - Figma: Color mode = Dark");
  buf.writeln("  // ===========================================================================");
  buf.writeln();
  buf.writeln("  static const dark = ZyraColors._(");
  buf.writeln("    brightness: Brightness.dark,");
  _writeConstructorArgs(buf, colors, "ZyraColorsDark");
  buf.writeln("  );");

  // --- const constructor ---
  buf.writeln();
  buf.writeln("  const ZyraColors._({");
  buf.writeln("    required this.brightness,");

  String? lastCategory;
  for (final color in colors) {
    final category = color["category"] as String;
    final figmaName = color["figmaName"] as String;
    final dartName = _figmaNameToDart(figmaName);

    if (category != lastCategory) {
      final label = _categoryCommentLabel(category);
      buf.writeln("    // $label");
      lastCategory = category;
    }

    buf.writeln("    required this.$dartName,");
  }

  buf.writeln("  });");

  // --- final fields ---
  buf.writeln();
  buf.writeln("  /// Whether this color set is for [Brightness.light] or [Brightness.dark] mode.");
  buf.writeln("  final Brightness brightness;");

  lastCategory = null;
  for (final color in colors) {
    final category = color["category"] as String;
    final figmaName = color["figmaName"] as String;
    final figmaPath = color["figmaPath"] as String;
    final dartName = _figmaNameToDart(figmaName);

    if (category != lastCategory) {
      buf.writeln();
      final header = _categoryHeaders[category] ?? category;
      buf.writeln("  // ===========================================================================");
      buf.writeln("  // $header");
      buf.writeln("  // ===========================================================================");
      lastCategory = category;
    }

    buf.writeln();
    buf.writeln("  /// Figma: $figmaPath");
    buf.writeln("  final Color $dartName;");
  }

  // --- static const light ---
  buf.writeln();
  buf.writeln("  // ===========================================================================");
  buf.writeln("  // Light Mode - Figma: Color mode = Light");
  buf.writeln("  // ===========================================================================");
  buf.writeln();
  buf.writeln("  static const light = ZyraColors._(");
  buf.writeln("    brightness: Brightness.light,");
  _writeConstructorArgs(buf, colors, "ZyraColorsLight");
  buf.writeln("  );");

  // --- lerpColors ---
  buf.writeln();
  buf.writeln(
    "  static ZyraColors lerpColors({required ZyraColors a, required ZyraColors b, required double t}) => ZyraColors._(",
  );
  buf.writeln("    brightness: t < 0.5 ? a.brightness : b.brightness,");

  lastCategory = null;
  for (final color in colors) {
    final category = color["category"] as String;
    final figmaName = color["figmaName"] as String;
    final dartName = _figmaNameToDart(figmaName);

    if (category != lastCategory) {
      final label = _categoryCommentLabel(category);
      buf.writeln("    // $label");
      lastCategory = category;
    }

    buf.writeln("    $dartName: lerpColorNonNull(a.$dartName, b.$dartName, t),");
  }

  buf.writeln("  );");

  buf.writeln("}");
}

void _writeConstructorArgs(StringBuffer buf, List<Map<String, dynamic>> colors, String sourceClass) {
  String? lastCategory;
  for (final color in colors) {
    final category = color["category"] as String;
    final figmaName = color["figmaName"] as String;
    final dartName = _figmaNameToDart(figmaName);

    if (category != lastCategory) {
      final label = _categoryCommentLabel(category);
      buf.writeln("    // $label");
      lastCategory = category;
    }

    buf.writeln("    $dartName: $sourceClass.$dartName,");
  }
}

String _categoryCommentLabel(String category) {
  return switch (category) {
    "Text" => "Text",
    "Border" => "Border",
    "Foreground" => "Foreground",
    "Background" => "Background",
    "Effects" => "Effects",
    "Shadows" => "Shadows",
    "Buttons" => "Buttons",
    "Icons" => "Icons",
    "Alpha" => "Alpha",
    "Utility" => "Utility",
    _ => category,
  };
}

// =============================================================================
// Natural sort
// =============================================================================

final _naturalSortPattern = RegExp(r"(\d+)");

/// Compares two strings using natural ordering so that numeric segments
/// are compared by value (`alpha10` < `alpha20` < `alpha100`).
int _naturalCompare(String a, String b) {
  final partsA = _splitNatural(a);
  final partsB = _splitNatural(b);
  final len = partsA.length < partsB.length ? partsA.length : partsB.length;
  for (var i = 0; i < len; i++) {
    final pa = partsA[i];
    final pb = partsB[i];
    final na = int.tryParse(pa);
    final nb = int.tryParse(pb);
    final cmp = (na != null && nb != null) ? na.compareTo(nb) : pa.compareTo(pb);
    if (cmp != 0) return cmp;
  }
  return partsA.length.compareTo(partsB.length);
}

/// Splits a string into alternating text and numeric segments.
///
/// `"alpha100"` → `["alpha", "100"]`
/// `"bg-brand-solid"` → `["bg-brand-solid"]`
List<String> _splitNatural(String s) {
  final parts = <String>[];
  var lastEnd = 0;
  for (final match in _naturalSortPattern.allMatches(s)) {
    if (match.start > lastEnd) {
      parts.add(s.substring(lastEnd, match.start));
    }
    parts.add(match.group(0)!);
    lastEnd = match.end;
  }
  if (lastEnd < s.length) {
    parts.add(s.substring(lastEnd));
  }
  return parts;
}

// =============================================================================
// Naming helpers
// =============================================================================

/// Converts a Figma semantic name (e.g. `text-primary_on-brand`) to Dart camelCase.
String _figmaNameToDart(String figmaName) {
  if (_nameOverrides.containsKey(figmaName)) return _nameOverrides[figmaName]!;

  final underscoreParts = figmaName.split("_");
  final result = StringBuffer();
  var isFirst = true;

  for (var i = 0; i < underscoreParts.length; i++) {
    final part = underscoreParts[i];
    // Split on hyphens and whitespace to handle names like "button-glass- primary-hover"
    final kebabParts = part.split(RegExp(r"[-\s]+"));

    for (var j = 0; j < kebabParts.length; j++) {
      final word = kebabParts[j].trim();
      if (word.isEmpty) continue;
      if (isFirst) {
        result.write(word);
        isFirst = false;
      } else {
        result.write(_capitalize(word));
      }
    }
  }

  return result.toString();
}

/// Converts a Figma primitive group + shade to a Dart name.
///
/// Examples:
/// - `Brand Blue`, `25` → `brandBlue25`
/// - `Gray (light mode)`, `300` → `grayLight300`
/// - `Gray (dark mode alpha)`, `100` → `grayDarkAlpha100`
/// - `Base`, `white` → `baseWhite`
String _primitiveToDartName(String group, String shade) {
  // Normalize group: remove parentheses, split on spaces, camelCase
  final normalized = group
      .replaceAll("(", "")
      .replaceAll(")", "")
      .trim();

  final words = normalized.split(RegExp(r"\s+"));
  final groupCamel = StringBuffer();

  for (var i = 0; i < words.length; i++) {
    final word = words[i].toLowerCase();
    // Skip "mode" in group names like "Gray (light mode)"
    if (word == "mode") continue;
    if (i == 0) {
      groupCamel.write(word);
    } else {
      groupCamel.write(_capitalize(word));
    }
  }

  // Shade: split on spaces and hyphens, then camelCase
  final shadeWords = shade.split(RegExp(r"[\s-]+"));
  final shadeBuf = StringBuffer();
  for (var i = 0; i < shadeWords.length; i++) {
    final word = shadeWords[i];
    if (i == 0) {
      shadeBuf.write(word);
    } else {
      shadeBuf.write(_capitalize(word));
    }
  }
  final shadeStr = shadeBuf.toString();

  // If shade starts with a letter, capitalize it for proper camelCase join
  if (shadeStr.isNotEmpty && !RegExp(r"^\d").hasMatch(shadeStr)) {
    return "$groupCamel${_capitalize(shadeStr)}";
  }

  return "$groupCamel$shadeStr";
}

String _capitalize(String s) {
  if (s.isEmpty) return s;
  return s[0].toUpperCase() + s.substring(1);
}

// =============================================================================
// FLOAT token extraction
// =============================================================================

/// Extracts FLOAT spacing primitives from the Primitives collection.
///
/// Looks for variables with `resolvedType == "FLOAT"` whose name starts with
/// `Spacing/`, e.g. `Spacing/0 (0px)`, `Spacing/0․5 (2px)`.
List<Map<String, dynamic>> _extractSpacingPrimitives(Map<String, dynamic>? collection) {
  if (collection == null) return [];
  final result = <Map<String, dynamic>>[];

  for (final v in collection["variables"] as List<dynamic>) {
    final variable = v as Map<String, dynamic>;
    final name = variable["name"] as String;
    final resolvedType = variable["resolvedType"] as String?;

    if (resolvedType != "FLOAT" || !name.startsWith("Spacing/")) continue;

    final valuesByMode = variable["valuesByMode"] as Map<String, dynamic>;
    final value = (valuesByMode.values.first as num).toDouble();

    result.add({
      "figmaName": name,
      "dartName": _numericSpacingToDartName(name),
      "value": value,
    });
  }

  return result;
}

/// Extracts FLOAT tokens from a single-mode collection (Spacing, Radius, Widths, Containers).
///
/// Values are either plain numbers (direct) or objects with `value` + `_alias` (alias).
List<Map<String, dynamic>> _extractFloatTokens(
  Map<String, dynamic>? collection, {
  String? stripPrefix,
}) {
  if (collection == null) return [];
  final result = <Map<String, dynamic>>[];

  for (final v in collection["variables"] as List<dynamic>) {
    final variable = v as Map<String, dynamic>;
    final name = variable["name"] as String;
    final valuesByMode = variable["valuesByMode"] as Map<String, dynamic>;
    final raw = valuesByMode.values.first;

    double value;
    String? alias;

    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is Map<String, dynamic>) {
      value = (raw["value"] as num).toDouble();
      alias = raw["_alias"] as String?;
    } else {
      continue;
    }

    result.add({
      "figmaName": name,
      "dartName": _floatTokenToDartName(name, stripPrefix: stripPrefix),
      "value": value,
      ...?(alias == null ? null : {"alias": alias}),
    });
  }

  return result;
}

// =============================================================================
// Spacing primitives file generation
// =============================================================================

void _generateSpacingPrimitivesFile(List<Map<String, dynamic>> spacingPrimitives) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln();
  buf.writeln("/// Figma numeric spacing scale — mode-invariant base values.");
  buf.writeln("///");
  buf.writeln("/// These map 1:1 to the FLOAT variables in the Figma **Primitives** collection.");
  buf.writeln("/// Semantic tokens in [ZyraSpacing] and [ZyraWidths] reference these constants.");
  buf.writeln("///");
  buf.writeln("/// Do not use primitives directly in widgets — use semantic tokens via");
  buf.writeln("/// `context.zyra.spacing.*` instead.");
  buf.writeln("abstract final class ZyraSpacingPrimitives {");

  for (final p in spacingPrimitives) {
    final figmaName = p["figmaName"] as String;
    final dartName = p["dartName"] as String;
    final value = p["value"] as double;

    buf.writeln();
    buf.writeln("  /// ${_formatDouble(value)}px - Figma: $figmaName");
    buf.writeln("  static const double $dartName = ${_formatDouble(value)};");
  }

  buf.writeln("}");

  final file = File(_spacingPrimitivesPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

// =============================================================================
// Spacing file generation (semantic tokens + containers)
// =============================================================================

void _generateSpacingFile(
  List<Map<String, dynamic>> spacingTokens,
  List<Map<String, dynamic>> containerTokens,
  Map<String, String> spacingPrimitiveDartNames,
) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln();
  buf.writeln('import "zyra_spacing_primitives.g.dart";');
  buf.writeln();
  buf.writeln("/// Semantic spacing tokens matching Figma spacing scale.");
  buf.writeln("///");
  buf.writeln("/// Values reference [ZyraSpacingPrimitives] where Figma uses an alias.");
  buf.writeln("///");
  buf.writeln("/// Usage:");
  buf.writeln("/// ```dart");
  buf.writeln("/// Padding(padding: EdgeInsetsDirectional.all(ZyraSpacing.md))");
  buf.writeln("/// SizedBox(height: ZyraSpacing.lg)");
  buf.writeln("/// ```");
  buf.writeln("abstract final class ZyraSpacing {");

  if (spacingTokens.isNotEmpty) {
    buf.writeln("  // ===========================================================================");
    buf.writeln("  // Semantic Spacing - Figma: Spacing collection");
    buf.writeln("  // ===========================================================================");

    for (final t in spacingTokens) {
      final figmaName = t["figmaName"] as String;
      final dartName = t["dartName"] as String;
      final value = t["value"] as double;
      final alias = t["alias"] as String?;

      buf.writeln();
      _writeFloatConstant(buf, figmaName, dartName, value, alias, spacingPrimitiveDartNames);
    }
  }

  if (containerTokens.isNotEmpty) {
    buf.writeln();
    buf.writeln("  // ===========================================================================");
    buf.writeln("  // Container Spacing - Figma: Containers collection");
    buf.writeln("  // ===========================================================================");

    for (final t in containerTokens) {
      final figmaName = t["figmaName"] as String;
      final dartName = t["dartName"] as String;
      final value = t["value"] as double;
      final alias = t["alias"] as String?;

      buf.writeln();
      _writeFloatConstant(buf, figmaName, dartName, value, alias, spacingPrimitiveDartNames);
    }
  }

  buf.writeln("}");

  final file = File(_spacingPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

// =============================================================================
// Radius file generation
// =============================================================================

void _generateRadiusFile(List<Map<String, dynamic>> radiusTokens) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln();
  buf.writeln("/// Border radius constants matching Figma radius scale.");
  buf.writeln("///");
  buf.writeln("/// Usage:");
  buf.writeln("/// ```dart");
  buf.writeln("/// Container(");
  buf.writeln("///   decoration: BoxDecoration(");
  buf.writeln("///     borderRadius: BorderRadius.circular(ZyraRadius.md),");
  buf.writeln("///   ),");
  buf.writeln("/// )");
  buf.writeln("/// ```");
  buf.writeln("abstract final class ZyraRadius {");

  for (final t in radiusTokens) {
    final figmaName = t["figmaName"] as String;
    final dartName = t["dartName"] as String;
    final value = t["value"] as double;

    buf.writeln();
    buf.writeln("  /// ${_formatDouble(value)}px - Figma: $figmaName");
    buf.writeln("  static const double $dartName = ${_formatDouble(value)};");
  }

  buf.writeln("}");

  final file = File(_radiusPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

// =============================================================================
// Widths file generation
// =============================================================================

void _generateWidthsFile(
  List<Map<String, dynamic>> widthTokens,
  Map<String, String> spacingPrimitiveDartNames,
) {
  final buf = StringBuffer();

  buf.writeln("// GENERATED CODE - DO NOT MODIFY BY HAND");
  buf.writeln("// To update, export variables from Figma and run:");
  buf.writeln("//   dart run scripts/figma_tokens/sync_figma_tokens.dart generate");
  buf.writeln();
  buf.writeln('import "zyra_spacing_primitives.g.dart";');
  buf.writeln();
  buf.writeln("/// Width constants matching Figma width tokens.");
  buf.writeln("///");
  buf.writeln("/// Values reference [ZyraSpacingPrimitives] where Figma uses an alias.");
  buf.writeln("abstract final class ZyraWidths {");

  for (final t in widthTokens) {
    final figmaName = t["figmaName"] as String;
    final dartName = t["dartName"] as String;
    final value = t["value"] as double;
    final alias = t["alias"] as String?;

    buf.writeln();
    _writeFloatConstant(buf, figmaName, dartName, value, alias, spacingPrimitiveDartNames);
  }

  buf.writeln("}");

  final file = File(_widthsPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buf.toString());
}

// =============================================================================
// Shared FLOAT generation helpers
// =============================================================================

/// Writes a single `static const double` line with an optional alias reference.
void _writeFloatConstant(
  StringBuffer buf,
  String figmaName,
  String dartName,
  double value,
  String? alias,
  Map<String, String> spacingPrimitiveDartNames,
) {
  if (alias != null) {
    final primitiveDart = spacingPrimitiveDartNames[alias];
    if (primitiveDart != null) {
      buf.writeln("  /// Figma: $figmaName \u2192 $alias");
      buf.writeln("  static const double $dartName = ZyraSpacingPrimitives.$primitiveDart;");
      return;
    }
  }
  buf.writeln("  /// ${_formatDouble(value)}px - Figma: $figmaName");
  buf.writeln("  static const double $dartName = ${_formatDouble(value)};");
}

/// Formats a double as a clean string — integer when possible.
String _formatDouble(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

// =============================================================================
// FLOAT naming helpers
// =============================================================================

/// Converts a semantic FLOAT token name to a Dart name.
///
/// Strips the prefix (e.g. "spacing-", "radius-", "width-"), then:
/// - Converts `Nxl` → `xNl` (e.g. "2xl" → "x2l", "11xl" → "x11l")
/// - Applies kebab→camelCase for remaining parts
///
/// If the name doesn't start with the prefix, applies plain kebab→camelCase.
String _floatTokenToDartName(String name, {String? stripPrefix}) {
  var n = name;
  if (stripPrefix != null && n.startsWith("$stripPrefix-")) {
    n = n.substring(stripPrefix.length + 1);
  }

  // Convert Nxl → xNl pattern (e.g. "2xl" → "x2l")
  final nxlMatch = RegExp(r"^(\d+)xl$").firstMatch(n);
  if (nxlMatch != null) {
    return "x${nxlMatch.group(1)}l";
  }

  // Standard kebab→camelCase
  return _figmaNameToDart(n);
}

/// Converts a FLOAT variable name from the Primitives collection to a Dart name.
///
/// `Spacing/0 (0px)` → `spacing0`
/// `Spacing/0․5 (2px)` → `spacing0_5`
/// `Spacing/1 (4px)` → `spacing1`
String _numericSpacingToDartName(String name) {
  var n = name;
  if (n.startsWith("Spacing/")) {
    n = n.substring("Spacing/".length);
  }

  // Strip parenthetical suffix " (Xpx)"
  final parenIdx = n.indexOf(" (");
  if (parenIdx != -1) {
    n = n.substring(0, parenIdx);
  }

  // Replace unicode dot ․ (U+2024) and regular dot with underscore
  n = n.replaceAll("\u2024", "_");
  n = n.replaceAll(".", "_");

  return "spacing$n";
}

// =============================================================================
// Color conversion
// =============================================================================

String _rgbaToHex(Map<String, dynamic> rgba) {
  final r = (rgba["r"] as num).toDouble();
  final g = (rgba["g"] as num).toDouble();
  final b = (rgba["b"] as num).toDouble();
  final a = (rgba["a"] as num).toDouble();

  final ai = (a * 255).round();
  final ri = (r * 255).round();
  final gi = (g * 255).round();
  final bi = (b * 255).round();

  final value = (ai << 24) | (ri << 16) | (gi << 8) | bi;
  return value.toRadixString(16).toUpperCase().padLeft(8, "0");
}

// =============================================================================
// Project root finder
// =============================================================================

String _findProjectRoot() {
  var dir = Directory.current;
  while (true) {
    if (File("${dir.path}/pubspec.yaml").existsSync()) return dir.path;
    final parent = dir.parent;
    if (parent.path == dir.path) return Directory.current.path;
    dir = parent;
  }
}
