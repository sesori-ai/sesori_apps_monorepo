// GENERATED-FILE HEADER — DO NOT EDIT BY HAND
//
// `tool/generate_sse_events.dart` reads a hand-curated manifest of OpenCode
// SSE event shapes (default `tool/opencode_events_v1.json`) and emits a
// sealed class hierarchy (default `lib/src/models/sse_event_data.g.dart`).
// The manifest's `dart` block names the base class, the session marker
// interface, the variant class prefix, and the import of every referenced
// model class. The marker interface is auto-implemented by any variant
// whose payload has a `sessionID` field, OR for which the manifest sets
// `session_marker: true` (used for events that carry session context
// through a nested payload like `info` or `part`).
//
// To regenerate:
//   dart run tool/generate_sse_events.dart
//   dart run tool/generate_sse_events.dart \
//     --manifest tool/opencode_events_v2.json --out lib/src/v2/models/v2_event.g.dart
//
// Field entries use either a primitive `type` (`string`, `int`, `bool`,
// `double`, `map` for a JSON object) or a `ref` to a generated model class.
// `list: true` wraps either in a list, `required: false` makes the field
// nullable, and `ref_kind: "enum"` decodes a ref from its wire string.
//
// To add a new event:
//   1. Add an entry to the manifest.
//   2. If the new event references a model class not in the manifest's
//      `dart.imports`, add its import there.
//   3. Run the generator.
//   4. Run `dart analyze` to verify.

import 'dart:convert';
// `dart:io` is used for File/stdout/stderr below.
import 'dart:io';

const _defaultManifestPath = 'tool/opencode_events_v1.json';
const _defaultOutputPath = 'lib/src/models/sse_event_data.g.dart';

/// Variant class-name prefix from the manifest's `dart.classPrefix`.
late String _classPrefix;

void main(List<String> args) {
  var manifestPath = _defaultManifestPath;
  var outputPath = _defaultOutputPath;
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if ((arg == '--manifest' || arg == '--out') && i + 1 < args.length) {
      if (arg == '--manifest') {
        manifestPath = args[++i];
      } else {
        outputPath = args[++i];
      }
    } else {
      stderr.writeln('Usage: dart run tool/generate_sse_events.dart [--manifest <file>] [--out <file>]');
      exit(2);
    }
  }

  final manifestFile = File(manifestPath);
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing $manifestPath — run from package root.');
    exit(1);
  }
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final events = (manifest['events'] as List).cast<Map<String, dynamic>>();
  final dart = manifest['dart'] as Map<String, dynamic>;
  final baseClass = dart['baseClass'] as String;
  final sessionClass = dart['sessionMarkerClass'] as String;
  _classPrefix = dart['classPrefix'] as String;
  final imports = (dart['imports'] as Map<String, dynamic>).cast<String, String>();
  final envelope = dart['envelope'] as Map<String, dynamic>?;
  final fieldOwners = [...events, ?envelope];

  // Validate every ref is in the import map.
  final missingImports = <String>{};
  for (final ev in fieldOwners) {
    for (final f in (ev['fields'] as List).cast<Map<String, dynamic>>()) {
      final ref = f['ref'] as String?;
      if (ref != null && !imports.containsKey(ref)) {
        missingImports.add(ref);
      }
    }
  }
  if (missingImports.isNotEmpty) {
    stderr.writeln('Error: ref(s) not in the manifest import map: $missingImports');
    stderr.writeln('Add an entry to dart.imports in $manifestPath.');
    exit(1);
  }

  // Collect refs actually used, in alphabetical order to satisfy
  // `directives_ordering`.
  final usedRefs = <String>[];
  for (final ev in fieldOwners) {
    for (final f in (ev['fields'] as List).cast<Map<String, dynamic>>()) {
      final ref = f['ref'] as String?;
      if (ref != null && !usedRefs.contains(ref)) usedRefs.add(ref);
    }
  }
  usedRefs.sort();

  final out = StringBuffer();
  out.writeln('// GENERATED FILE - DO NOT EDIT BY HAND');
  out.writeln('//');
  out.writeln('// Source manifest: $manifestPath');
  final isDefault = manifestPath == _defaultManifestPath && outputPath == _defaultOutputPath;
  out.writeln(
    isDefault
        ? '// To regenerate: dart run tool/generate_sse_events.dart'
        : '// To regenerate: dart run tool/generate_sse_events.dart --manifest $manifestPath --out $outputPath',
  );
  out.writeln();
  out.writeln('// `FormatException` lives in `dart:core`; no extra import needed.');
  for (final ref in usedRefs) {
    out.writeln('import "${imports[ref]}";');
  }
  out.writeln();
  out.writeln('/// Marker sealed type for all SSE events that are scoped to a specific');
  out.writeln('/// session. Any [$baseClass] variant that carries a session context');
  out.writeln('/// implements this. Use this to obtain a typed stream of only the events');
  out.writeln('/// that can ever be received for a given session, enabling exhaustive');
  out.writeln('/// switching over only session-scoped variants.');
  out.writeln('sealed class $sessionClass {}');
  out.writeln();
  out.writeln('/// Typed representation of all known SSE event payloads. Each variant');
  out.writeln('/// carries a [type] matching the wire-format string and a payload');
  out.writeln('/// corresponding to the field set declared in the event manifest.');
  out.writeln('///');
  out.writeln('/// Deserialization dispatches on the JSON `type` field. Unknown event');
  out.writeln('/// types cause [fromJson] to throw — callers should catch and report.');
  out.writeln('sealed class $baseClass {');
  out.writeln('  const $baseClass();');
  out.writeln();
  out.writeln('  // -------------------------------------------------------------------');
  out.writeln('  // Redirecting factories');
  out.writeln('  //');
  out.writeln('  // Each variant gets a `$baseClass.<eventCamelName>(...)`');
  out.writeln('  // redirecting factory so callers that pre-date the typed variant');
  out.writeln('  // classes can still construct events through the base class.');
  out.writeln('  // -------------------------------------------------------------------');
  for (final ev in events) {
    final type = ev['type'] as String;
    final className = _classNameFor(type);
    final factoryName = _factoryNameFor(type);
    final fields = (ev['fields'] as List).cast<Map<String, dynamic>>();
    if (fields.isEmpty) {
      out.writeln('  const factory $baseClass.$factoryName() = $className;');
    } else {
      out.writeln('  const factory $baseClass.$factoryName({');
      for (final f in fields) {
        final name = f['name'] as String;
        final required = f['required'] != false;
        final dartType = _dartType(f, required: required);
        if (required) {
          out.writeln('    required $dartType $name,');
        } else {
          out.writeln('    $dartType $name,');
        }
      }
      out.writeln('  }) = $className;');
    }
  }
  out.writeln();
  out.writeln('  /// Wire-format type discriminator for this event.');
  out.writeln('  String get type;');
  out.writeln();
  out.writeln('  /// Encodes this event back to its JSON wire form, including the');
  out.writeln('  /// `type` discriminator.');
  out.writeln('  Map<String, dynamic> toJson();');
  out.writeln();
  out.writeln('  /// Decodes a JSON envelope into the corresponding [$baseClass]');
  out.writeln('  /// variant by dispatching on the `type` field.');
  out.writeln('  factory $baseClass.fromJson(Map<String, dynamic> json) {');
  out.writeln('    final type = json["type"] as String?;');
  out.writeln('    if (type == null) {');
  out.writeln('      throw const FormatException("SSE event missing \'type\' field");');
  out.writeln('    }');
  out.writeln('    return switch (type) {');
  for (final ev in events) {
    final type = ev['type'] as String;
    final className = _classNameFor(type);
    final rawType = _rawString(type);
    out.writeln('      $rawType => $className.fromJson(json),');
  }
  out.writeln('      final String unknown =>');
  out.writeln(r'        throw FormatException("Unknown SSE event type: $unknown"),');
  out.writeln('    };');
  out.writeln('  }');
  out.writeln('}');
  out.writeln();

  for (final ev in events) {
    _emitVariant(out, ev, baseClass: baseClass, sessionClass: sessionClass);
  }
  if (envelope != null) {
    _emitEnvelope(out: out, envelope: envelope, baseClass: baseClass);
  }

  File(outputPath).writeAsStringSync(out.toString());
  stdout.writeln('Wrote $outputPath (${events.length} variants, ${usedRefs.length} refs)');
}

// ---------------------------------------------------------------------------
// Emission helpers
// ---------------------------------------------------------------------------

/// A protocol may wrap its type-discriminated event data in a frame carrying
/// identity, time and location. Emit that boundary from the same manifest.
void _emitEnvelope({
  required StringBuffer out,
  required Map<String, dynamic> envelope,
  required String baseClass,
}) {
  final className = envelope['className'] as String;
  final fields = (envelope['fields'] as List).cast<Map<String, dynamic>>();
  out.writeln('class $className {');
  out.writeln('  const $className({');
  for (final field in fields) {
    out.writeln('    required this.${field['name']},');
  }
  out.writeln('    required this.data,');
  out.writeln('  });');
  for (final field in fields) {
    out.writeln('  final ${_dartType(field, required: field['required'] != false)} ${field['name']};');
  }
  out.writeln('  final $baseClass data;');
  out.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
  out.writeln('    return $className(');
  for (final field in fields) {
    final name = field['name'] as String;
    out.writeln('      $name: ${_decodeField(name, field, field['required'] != false)},');
  }
  // The outer discriminator is authoritative, even if a future payload happens
  // to contain its own field named type.
  out.writeln('      data: $baseClass.fromJson({...json["data"] as Map<String, dynamic>, "type": json["type"]}),');
  out.writeln('    );');
  out.writeln('  }');
  out.writeln('}');
}

void _emitVariant(
  StringBuffer out,
  Map<String, dynamic> ev, {
  required String baseClass,
  required String sessionClass,
}) {
  final type = ev['type'] as String;
  final className = _classNameFor(type);
  final fields = (ev['fields'] as List).cast<Map<String, dynamic>>();
  // A variant is a session-scoped event either when it has a top-level
  // `sessionID` field, or when the manifest sets `session_marker: true`
  // explicitly (used when the session context is carried through a
  // nested payload, e.g. `info` for session.created/updated/deleted
  // and message.updated, or `part` for message.part.updated).
  final hasSessionID = fields.any((f) => f['name'] == 'sessionID');
  final explicitMarker = ev['session_marker'] == true;
  final isSessionEvent = hasSessionID || explicitMarker;
  final isDeprecated = ev['deprecated'] == true;
  final deprecatedMsg = ev['deprecated_message'] as String?;

  // Class header.
  // COMPATIBILITY 2026-05-18 (v0.7.0): Deprecated manifest events remain generated for older OpenCode runtimes. Remove deprecated-event generation when those runtimes are unsupported.
  if (isDeprecated) {
    final msg = deprecatedMsg ?? 'Deprecated event.';
    out.writeln('/// Deprecated event. $msg');
    // The ignore comment matches the existing hand-written convention for
    // keeping deprecated events available for backward compatibility.
    out.writeln('// ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
    out.writeln('@Deprecated("$msg")');
  }
  final implementsClause = isSessionEvent ? ' implements $sessionClass' : '';
  out.writeln('class $className extends $baseClass$implementsClause {');

  // Constructor.
  if (fields.isEmpty) {
    if (isDeprecated) {
      final msg = deprecatedMsg ?? 'Deprecated event.';
      out.writeln('  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
      out.writeln('  @Deprecated("$msg")');
    }
    out.writeln('  const $className();');
  } else {
    if (isDeprecated) {
      final msg = deprecatedMsg ?? 'Deprecated event.';
      out.writeln('  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
      out.writeln('  @Deprecated("$msg")');
    }
    out.writeln('  const $className({');
    for (final f in fields) {
      final name = f['name'] as String;
      final required = f['required'] != false; // default to required
      if (required) {
        out.writeln('    required this.$name,');
      } else {
        out.writeln('    this.$name,');
      }
    }
    out.writeln('  });');
  }
  out.writeln();

  // Field declarations.
  for (final f in fields) {
    final name = f['name'] as String;
    final required = f['required'] != false;
    final dartType = _dartType(f, required: required);
    out.writeln('  final $dartType $name;');
  }
  if (fields.isNotEmpty) out.writeln();

  // type getter.
  out.writeln('  @override');
  out.writeln('  String get type => ${_rawString(type)};');
  out.writeln();

  // toJson.
  out.writeln('  @override');
  if (fields.isEmpty) {
    out.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{"type": type};');
  } else {
    out.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{');
    out.writeln('    "type": type,');
    for (final f in fields) {
      final name = f['name'] as String;
      final expr = _encodeField(name, f);
      out.writeln('    ${_rawKey(name)}: $expr,');
    }
    out.writeln('  };');
  }
  out.writeln();

  // fromJson.
  if (isDeprecated) {
    final msg = deprecatedMsg ?? 'Deprecated event.';
    out.writeln('  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
    out.writeln('  @Deprecated("$msg")');
  }
  out.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
  if (fields.isEmpty) {
    // Use the `json` parameter for runtime type validation; this satisfies
    // `avoid_unused_constructor_parameters` without a suppression.
    out.writeln('    assert(json["type"] == ${_rawString(type)});');
    out.writeln('    return const $className();');
  } else {
    out.writeln('    return $className(');
    for (final f in fields) {
      final name = f['name'] as String;
      final required = f['required'] != false;
      final expr = _decodeField(name, f, required);
      out.writeln('      $name: $expr,');
    }
    out.writeln('    );');
  }
  out.writeln('  }');
  out.writeln('}');
}

String _dartType(Map<String, dynamic> f, {required bool required}) {
  final ref = f['ref'] as String?;
  final isList = f['list'] == true;
  if (ref != null) {
    final refType = isList ? 'List<$ref>' : ref;
    return required ? refType : '$refType?';
  }
  final t = f['type'] as String;
  final base = _primitiveType(t);
  if (isList) {
    return required ? 'List<$base>' : 'List<$base>?';
  }
  return required ? base : (base == 'dynamic' ? 'dynamic' : '$base?');
}

String _encodeField(String name, Map<String, dynamic> f) {
  final ref = f['ref'] as String?;
  final isList = f['list'] == true;
  final access = f['required'] == false ? '$name?' : name;
  if (ref != null && isList) {
    return '$access.map((e) => e.toJson()).toList()';
  }
  if (ref != null) {
    return '$access.toJson()';
  }
  return name;
}

String _decodeField(String name, Map<String, dynamic> f, bool required) {
  final ref = f['ref'] as String?;
  final isList = f['list'] == true;
  final jsonName = _rawKey(name);
  if (ref != null) {
    final wireType = f['ref_kind'] == 'enum' ? 'String' : 'Map<String, dynamic>';
    final refExpr = isList
        ? '(json[$jsonName] as List<dynamic>).map((e) => $ref.fromJson(e as $wireType)).toList()'
        : '$ref.fromJson(json[$jsonName] as $wireType)';
    return required ? refExpr : 'json[$jsonName] == null ? null : $refExpr';
  }
  final t = f['type'] as String;
  if (isList) {
    final base = _primitiveType(t);
    final listExpr = base == 'dynamic'
        ? 'json[$jsonName] as List<dynamic>'
        : '(json[$jsonName] as List<dynamic>).cast<$base>()';
    if (!required) {
      return 'json[$jsonName] == null ? null : ($listExpr)';
    }
    return listExpr;
  }
  final rawExpr = 'json[$jsonName]';
  if (!required) {
    return '$rawExpr == null ? null : ${_castExpr(t, rawExpr)}';
  }
  return _castExpr(t, rawExpr);
}

String _primitiveType(String t) {
  return switch (t) {
    'string' => 'String',
    'int' => 'int',
    'bool' => 'bool',
    'double' => 'double',
    'map' => 'Map<String, dynamic>',
    _ => 'dynamic',
  };
}

String _castExpr(String t, String expr) {
  return switch (t) {
    'string' => '$expr as String',
    'int' => '($expr as num).toInt()',
    'bool' => '$expr as bool',
    'double' => '($expr as num).toDouble()',
    'map' => '$expr as Map<String, dynamic>',
    _ => expr,
  };
}

// Wire-format strings: emit as raw only when they contain `$` (to prevent
// interpolation), backslashes, or embedded double quotes. Otherwise a plain
// string literal keeps the `unnecessary_raw_strings` lint clean.
String _rawString(String s) {
  if (s.contains(r'$') || s.contains(r'\') || s.contains('"')) {
    return jsonEncode(s);
  }
  return '"$s"';
}

// JSON object key: same rules as `_rawString`.
String _rawKey(String s) {
  if (s.contains(r'$') || s.contains(r'\') || s.contains('"')) {
    return jsonEncode(s);
  }
  return '"$s"';
}

String _classNameFor(String eventType) {
  // "session.created" -> "SseSessionCreated" (with the v1 "Sse" prefix)
  final parts = eventType.split(RegExp(r'[._\-]'));
  final pascal = parts.map((p) {
    if (p.isEmpty) return '';
    return p[0].toUpperCase() + p.substring(1);
  }).join();
  return '$_classPrefix$pascal';
}

String _factoryNameFor(String eventType) {
  // "session.created" -> "sessionCreated"
  final className = _classNameFor(eventType);
  // Drop the class prefix and lowercase the first letter.
  final withoutPrefix = className.substring(_classPrefix.length);
  return withoutPrefix[0].toLowerCase() + withoutPrefix.substring(1);
}
