// GENERATED-FILE HEADER — DO NOT EDIT BY HAND
//
// `tool/generate_sse_events.dart` reads `tool/opencode_events_v1.json`
// (a hand-curated manifest of v1 OpenCode SSE event shapes) and emits
// `lib/src/models/sse_event_data.dart` as a hand-written sealed class
// hierarchy. Marker interface SseSessionEventData is auto-implemented by
// any variant whose payload has a `sessionID` field.
//
// To regenerate:
//   dart run tool/generate_sse_events.dart
//
// To add a new event:
//   1. Add an entry to `tool/opencode_events_v1.json`.
//   2. If the new event references a v1 model class not in the import map
//      below, add the import here.
//   3. Run the generator.
//   4. Run `dart analyze` to verify.

import 'dart:convert';
// `dart:io` is used for File/stdout/stderr below.
import 'dart:io';

// ---------------------------------------------------------------------------
// v1 model import map. SSE event payload fields reference the hand-written
// v1 model classes in `lib/src/models/`. Add an entry here when a new event
// references a type that is not already imported.
// ---------------------------------------------------------------------------
const Map<String, String> _v1Imports = {
  'Session': 'session.dart',
  'Message': 'message.dart',
  'MessagePart': 'message_part.dart',
  'FileDiff': 'file_diff.dart',
  'SessionStatus': 'session_status.dart',
  'QuestionInfo': 'question.dart',
};

void main() {
  final manifestFile = File('tool/opencode_events_v1.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Missing tool/opencode_events_v1.json — run from package root.');
    exit(1);
  }
  final manifest = jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
  final events = (manifest['events'] as List).cast<Map<String, dynamic>>();

  // Validate every ref is in the import map.
  final missingImports = <String>{};
  for (final ev in events) {
    for (final f in (ev['fields'] as List).cast<Map<String, dynamic>>()) {
      final ref = f['ref'] as String?;
      if (ref != null && !_v1Imports.containsKey(ref)) {
        missingImports.add(ref);
      }
    }
  }
  if (missingImports.isNotEmpty) {
    stderr.writeln('Error: ref(s) not in v1 import map: $missingImports');
    stderr.writeln('Add an entry to _v1Imports in tool/generate_sse_events.dart.');
    exit(1);
  }

  // Collect refs actually used, in alphabetical order to satisfy
  // `directives_ordering`.
  final usedRefs = <String>[];
  for (final ev in events) {
    for (final f in (ev['fields'] as List).cast<Map<String, dynamic>>()) {
      final ref = f['ref'] as String?;
      if (ref != null && !usedRefs.contains(ref)) usedRefs.add(ref);
    }
  }
  usedRefs.sort();

  final out = StringBuffer();
  out.writeln('// GENERATED FILE - DO NOT EDIT BY HAND');
  out.writeln('//');
  out.writeln('// Source manifest: tool/opencode_events_v1.json');
  out.writeln('// To regenerate: dart run tool/generate_sse_events.dart');
  out.writeln();
  out.writeln('// `FormatException` lives in `dart:core`; no extra import needed.');
  for (final ref in usedRefs) {
    out.writeln('import "${_v1Imports[ref]}";');
  }
  out.writeln();
  out.writeln('/// Marker sealed type for all SSE events that are scoped to a specific');
  out.writeln('/// session. Any [SseEventData] variant that carries a session context');
  out.writeln('/// implements this. Use this to obtain a typed stream of only the events');
  out.writeln('/// that can ever be received for a given session, enabling exhaustive');
  out.writeln('/// switching over only session-scoped variants.');
  out.writeln('sealed class SseSessionEventData {}');
  out.writeln();
  out.writeln('/// Typed representation of all known SSE event payloads. Each variant');
  out.writeln('/// carries a [type] matching the wire-format string and a payload');
  out.writeln('/// corresponding to the field set declared in the event manifest.');
  out.writeln('///');
  out.writeln('/// Deserialization dispatches on the JSON `type` field. Unknown event');
  out.writeln('/// types cause [fromJson] to throw — callers should catch and report.');
  out.writeln('sealed class SseEventData {');
  out.writeln('  const SseEventData();');
  out.writeln();
  out.writeln('  // -------------------------------------------------------------------');
  out.writeln('  // Redirecting factories');
  out.writeln('  //');
  out.writeln('  // Each variant gets a `SseEventData.<eventCamelName>(...)`');
  out.writeln('  // redirecting factory so callers that pre-date the typed variant');
  out.writeln('  // classes can still construct events through the base class.');
  out.writeln('  // -------------------------------------------------------------------');
  for (final ev in events) {
    final type = ev['type'] as String;
    final className = _classNameFor(type);
    final factoryName = _factoryNameFor(type);
    final fields = (ev['fields'] as List).cast<Map<String, dynamic>>();
    if (fields.isEmpty) {
      out.writeln('  const factory SseEventData.$factoryName() = $className;');
    } else {
      out.writeln('  const factory SseEventData.$factoryName({');
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
  out.writeln('  /// Decodes a JSON envelope into the corresponding [SseEventData]');
  out.writeln('  /// variant by dispatching on the `type` field.');
  out.writeln('  factory SseEventData.fromJson(Map<String, dynamic> json) {');
  out.writeln('    final type = json["type"] as String?;');
  out.writeln('    if (type == null) {');
  out.writeln(
      '      throw const FormatException("SSE event missing \'type\' field");');
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
    _emitVariant(out, ev);
  }

  const outputPath = 'lib/src/models/sse_event_data.dart';
  File(outputPath).writeAsStringSync(out.toString());
  stdout.writeln('Wrote $outputPath (${events.length} variants, ${usedRefs.length} refs)');
}

// ---------------------------------------------------------------------------
// Emission helpers
// ---------------------------------------------------------------------------

void _emitVariant(StringBuffer out, Map<String, dynamic> ev) {
  final type = ev['type'] as String;
  final className = _classNameFor(type);
  final fields = (ev['fields'] as List).cast<Map<String, dynamic>>();
  final hasSessionID = fields.any((f) => f['name'] == 'sessionID');
  final isDeprecated = ev['deprecated'] == true;
  final deprecatedMsg = ev['deprecated_message'] as String?;

  // Class header.
  if (isDeprecated) {
    final msg = deprecatedMsg ?? 'Deprecated event.';
    out.writeln('/// Deprecated event. $msg');
    // The ignore comment matches the existing hand-written convention for
    // keeping deprecated events available for backward compatibility.
    out.writeln(
        '// ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
    out.writeln('@Deprecated("$msg")');
  }
  final implementsClause = hasSessionID ? ' implements SseSessionEventData' : '';
  out.writeln('class $className extends SseEventData$implementsClause {');

  // Constructor.
  if (fields.isEmpty) {
    if (isDeprecated) {
      final msg = deprecatedMsg ?? 'Deprecated event.';
      out.writeln(
          '  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
      out.writeln('  @Deprecated("$msg")');
    }
    out.writeln('  const $className();');
  } else {
    if (isDeprecated) {
      final msg = deprecatedMsg ?? 'Deprecated event.';
      out.writeln(
          '  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
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
    out.writeln(
        '  // ignore: remove_deprecations_in_breaking_versions, keep idle event for backward compatibility');
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
  if (ref != null) {
    final isList = f['list'] == true;
    if (isList) return 'List<$ref>';
    return ref;
  }
  final t = f['type'] as String;
  final base = switch (t) {
    'string' => 'String',
    'int' => 'int',
    'bool' => 'bool',
    'double' => 'double',
    _ => 'dynamic',
  };
  return required ? base : (base == 'dynamic' ? 'dynamic' : '$base?');
}

String _encodeField(String name, Map<String, dynamic> f) {
  final ref = f['ref'] as String?;
  final isList = f['list'] == true;
  if (ref != null && isList) {
    return '$name.map((e) => e.toJson()).toList()';
  }
  if (ref != null) {
    return '$name.toJson()';
  }
  return name;
}

String _decodeField(String name, Map<String, dynamic> f, bool required) {
  final ref = f['ref'] as String?;
  final isList = f['list'] == true;
  final jsonName = _rawKey(name);
  if (ref != null && isList) {
    return '(json[$jsonName] as List<dynamic>).map((e) => $ref.fromJson(e as Map<String, dynamic>)).toList()';
  }
  if (ref != null) {
    return '$ref.fromJson(json[$jsonName] as Map<String, dynamic>)';
  }
  final t = f['type'] as String;
  final rawExpr = 'json[$jsonName]';
  if (!required) {
    return '$rawExpr == null ? null : ${_castExpr(t, rawExpr)}';
  }
  return _castExpr(t, rawExpr);
}

String _castExpr(String t, String expr) {
  return switch (t) {
    'string' => '$expr as String',
    'int' => '($expr as num).toInt()',
    'bool' => '$expr as bool',
    'double' => '($expr as num).toDouble()',
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
  // "session.created" -> "SseSessionCreated"
  final parts = eventType.split(RegExp(r'[._\-]'));
  final pascal = parts.map((p) {
    if (p.isEmpty) return '';
    return p[0].toUpperCase() + p.substring(1);
  }).join();
  return 'Sse$pascal';
}

String _factoryNameFor(String eventType) {
  // "session.created" -> "sessionCreated"
  final className = _classNameFor(eventType);
  // Drop the "Sse" prefix and lowercase the first letter.
  final withoutPrefix = className.substring(3);
  return withoutPrefix[0].toLowerCase() + withoutPrefix.substring(1);
}
