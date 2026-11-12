// Hand-written generator for the OpenCode OpenAPI model files under models/openapi/.
//
// Usage:
//   # Fetch the spec from anomalyco/opencode and record the source in every
//   # generated file header:
//   dart run tool/generate_opencode_client.dart --tag v1.16.2
//   dart run tool/generate_opencode_client.dart --branch dev
//   dart run tool/generate_opencode_client.dart --commit 76c631d1...
//
//   # Use a local openapi.json (no upstream ref recorded in the header):
//   dart run tool/generate_opencode_client.dart --local /path/to/openapi.json
//
//   # Override the output directory (default: lib/src):
//   dart run tool/generate_opencode_client.dart --tag v1.16.2 --out-dir lib/src
//
//   # Generate another API surface (default: tool/opencode_v1_surface.json).
//   # The surface file also names the spec path inside the upstream repo:
//   dart run tool/generate_opencode_client.dart --tag v2.0.16 \
//     --surface tool/opencode_v2_surface.json --out-dir lib/src/v2
//
// Exactly one of --tag, --branch, --commit, or --local is required. There
// is no default: this script will not guess what you meant.
//
// This script consumes an OpenAPI 3.1 JSON document (the surface file's
// `specPath`, e.g. OpenCode's `packages/sdk/openapi.json`) and emits,
// relative to outDir:
//   - models/openapi/<SchemaName>.g.dart   — one file per included top-level schema (Layer 0)
//
// The API clients that call these endpoints are hand-written.
//
// Models live under `models/openapi/` to avoid filename collisions with the
// hand-written v1 models already in `models/` (e.g. session.dart, message.dart).
// Layer-mirror rule (bridge/AGENTS.md): directory structure mirrors layers.
//
// Generated code has no codegen runtime: immutable classes with
// hand-written fromJson/toJson (no freezed/json_serializable), and Dart 3
// sealed classes for unions.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'src/json_reads.dart';

const _upstreamOwner = 'anomalyco';
const _upstreamRepo = 'opencode';

/// Resolved upstream ref description passed to the codegen. Exactly one
/// of [tag], [branch], [commit] is non-null. [commitSha] is the 40-char
/// hex commit SHA the ref points at (always populated when [kind] is set).
class SourceRef({
  /// One of 'tag', 'branch', 'commit'.
  required final String kind,

  /// The user-supplied ref string (`v1.16.2`, `dev`, or a 40-char SHA).
  required final String value,

  /// The 40-char hex commit SHA the ref resolves to. Pre-resolved at
  /// startup via `git ls-remote` so generation is fully offline after
  /// the initial fetch.
  required final String commitSha,
}) {
  /// Display form used in generated file headers:
  /// `anomalyco/opencode@<value> (<commitSha>)`.
  String get display => '$_upstreamOwner/$_upstreamRepo@$value ($commitSha)';
}

Future<void> main(List<String> args) async {
  String? tag;
  String? branch;
  String? commit;
  String? localSpecPath;
  var outDir = 'lib/src';
  var surfacePath = 'tool/opencode_v1_surface.json';
  var verbose = false;

  // Positional args are not used; everything is an explicit flag so the
  // script never has to guess what the user meant.
  var i = 0;
  while (i < args.length) {
    final a = args[i++];
    switch (a) {
      case '--tag':
        if (i >= args.length) {
          stderr.writeln('error: --tag requires a value');
          _printUsage();
          exit(2);
        }
        tag = args[i++];
      case '--branch':
        if (i >= args.length) {
          stderr.writeln('error: --branch requires a value');
          _printUsage();
          exit(2);
        }
        branch = args[i++];
      case '--commit':
        if (i >= args.length) {
          stderr.writeln('error: --commit requires a value');
          _printUsage();
          exit(2);
        }
        commit = args[i++];
      case '--local':
        if (i >= args.length) {
          stderr.writeln('error: --local requires a value');
          _printUsage();
          exit(2);
        }
        localSpecPath = args[i++];
      case '--out-dir':
        if (i >= args.length) {
          stderr.writeln('error: --out-dir requires a value');
          _printUsage();
          exit(2);
        }
        outDir = args[i++];
      case '--surface':
        if (i >= args.length) {
          stderr.writeln('error: --surface requires a value');
          _printUsage();
          exit(2);
        }
        surfacePath = args[i++];
      case '--verbose':
      case '-v':
        verbose = true;
      case '--help':
      case '-h':
        _printUsage();
        exit(0);
      default:
        stderr.writeln('error: unknown argument: $a');
        _printUsage();
        exit(2);
    }
  }

  final surface = SurfaceSpec.load(surfacePath);

  // Exactly one of --tag / --branch / --commit / --local is required.
  final source = switch ((tag, branch, commit, localSpecPath)) {
    (final tag?, null, null, null) => await _resolveAndFetch(
      kind: 'tag',
      value: tag,
      specPathInRepo: surface.specPath,
      verbose: verbose,
    ),
    (null, final branch?, null, null) => await _resolveAndFetch(
      kind: 'branch',
      value: branch,
      specPathInRepo: surface.specPath,
      verbose: verbose,
    ),
    (null, null, final commit?, null) => await _fetchCommit(
      commit: commit,
      specPathInRepo: surface.specPath,
      verbose: verbose,
    ),
    (null, null, null, final localSpecPath?) => (sourceRef: null, specPath: localSpecPath),
    (null, null, null, null) => _usageError('one of --tag, --branch, --commit, or --local is required'),
    _ => _usageError('--tag, --branch, --commit, and --local are mutually exclusive'),
  };

  stdout.writeln('Reading OpenAPI spec: ${source.specPath}');
  final raw = File(source.specPath).readAsStringSync();
  final spec = readObject(jsonDecode(raw));
  final specSchemas = readObjectOrNull(readObjectOrNull(spec['components'])?['schemas']) ?? const {};
  _hoistInlineSchemas(schemas: specSchemas, hoists: surface.hoistSchemas);
  for (final entry in surface.optionalProperties.entries) {
    final schema = readObject(specSchemas[entry.key]);
    final required = readList(schema['required']);
    for (final property in entry.value) {
      if (!readObject(schema['properties']).containsKey(property) || !required.remove(property)) {
        throw StateError('Optional property override ${entry.key}.$property no longer matches upstream');
      }
    }
  }
  for (final name in surface.sealedUnions) {
    final schema = readObject(specSchemas[name]);
    final key = schema.containsKey('anyOf') ? 'anyOf' : 'oneOf';
    schema[key] = readList(schema[key]).map((value) {
      final variant = readObject(value);
      final ref = variant[r'$ref'];
      final rawName = ref is String ? _schemaNameFromRef(ref) : null;
      final inline = rawName == null ? variant : readObject(specSchemas[rawName]);
      if (inline['type'] != 'object') throw StateError('Sealed union $name requires object variants');
      return {...inline, if (rawName != null) 'x-sesori-variant-name': _pascalFromSnake(rawName)};
    }).toList();
    schema['x-sesori-sealed'] = true;
  }
  // Collapse first: a collapsed named schema becomes a primitive whose
  // refs are then inlined.
  _collapseOpenStringUnions(spec);
  _inlinePrimitiveRefs(spec: spec, schemas: specSchemas);
  _collidingDottedNames = _findCollidingDottedNames(specSchemas.keys);

  final gen = Codegen(
    spec: spec,
    surface: surface,
    outDir: outDir,
    verbose: verbose,
    sourceRef: source.sourceRef,
  );
  try {
    await gen.run();
  } finally {
    // A fetched spec is a temp file; a --local spec belongs to the user.
    if (source.sourceRef != null) {
      try {
        File(source.specPath).deleteSync();
      } catch (_) {
        /* best-effort cleanup */
      }
    }
  }
  stdout.writeln('Done. Output: $outDir');
}

Never _usageError(String message) {
  stderr.writeln('error: $message');
  _printUsage();
  exit(2);
}

void _printUsage() {
  stderr.writeln('');
  stderr.writeln(
    'Usage: dart run tool/generate_opencode_client.dart '
    '[--tag <tag> | --branch <branch> | --commit <sha> | --local <path>] '
    '[--out-dir <dir>] [--surface <file>] [--verbose]',
  );
  stderr.writeln('');
  stderr.writeln(
    '  --tag <name>        Fetch the spec from anomalyco/opencode at '
    'the given git tag (e.g. v1.16.2)',
  );
  stderr.writeln(
    '  --branch <name>     Fetch the spec from anomalyco/opencode at '
    'the given git branch (e.g. dev)',
  );
  stderr.writeln(
    '  --commit <sha>      Fetch the spec from anomalyco/opencode at '
    'the given 40-char commit SHA',
  );
  stderr.writeln(
    '  --local <path>      Use a local openapi.json file '
    '(no upstream ref recorded in headers)',
  );
  stderr.writeln('  --out-dir <dir>     Output directory (default: lib/src)');
  stderr.writeln('  --surface <file>    API surface allowlist (default: tool/opencode_v1_surface.json)');
  stderr.writeln('  --verbose, -v       Print extra progress information');
}

/// Fetch the OpenCode openapi.json from upstream at [ref] (a branch name,
/// tag name, or commit SHA) and return the path to the downloaded temp
/// file. Caller is responsible for deleting the file.
Future<String> _fetchSpec(String ref, {required String specPathInRepo, required bool verbose}) async {
  final url = Uri.parse(
    'https://raw.githubusercontent.com/$_upstreamOwner/$_upstreamRepo/'
    '$ref/$specPathInRepo',
  );
  if (verbose) stdout.writeln('Fetching $url');
  final response = await http.get(url);
  if (response.statusCode != 200) {
    stderr.writeln('error: failed to fetch $url (HTTP ${response.statusCode})');
    exit(1);
  }
  final tmp = File('${Directory.systemTemp.path}/opencode-openapi-$ref.json');
  tmp.writeAsBytesSync(response.bodyBytes);
  return tmp.path;
}

/// Fetch the spec at [commit], a 40-char commit SHA that needs no
/// resolution.
Future<({SourceRef sourceRef, String specPath})> _fetchCommit({
  required String commit,
  required String specPathInRepo,
  required bool verbose,
}) async {
  if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
    stderr.writeln('error: --commit must be a 40-character hex SHA; got "$commit"');
    exit(2);
  }
  final specPath = await _fetchSpec(commit, specPathInRepo: specPathInRepo, verbose: verbose);
  return (sourceRef: SourceRef(kind: 'commit', value: commit, commitSha: commit), specPath: specPath);
}

/// Resolve [value] (a tag or branch name) to its 40-char commit SHA via
/// `git ls-remote`, then fetch the spec at that commit. The resolved
/// SHA is recorded in every generated file header.
Future<({SourceRef sourceRef, String specPath})> _resolveAndFetch({
  required String kind,
  required String value,
  required String specPathInRepo,
  required bool verbose,
}) async {
  if (verbose) stdout.writeln('Resolving $kind "$value" to a commit SHA...');
  final r = await Process.run('git', [
    'ls-remote',
    '--exit-code',
    'https://github.com/$_upstreamOwner/$_upstreamRepo',
    value,
  ]);
  if (r.exitCode != 0) {
    stderr.writeln(
      'error: could not resolve $kind "$value" via git ls-remote '
      '(exit ${r.exitCode}). '
      'Check your network connection and that the ref exists.',
    );
    final error = readString(r.stderr);
    if (error.isNotEmpty) stderr.writeln(error);
    exit(1);
  }
  // Output line shape: "<sha>\trefs/<kind>/<ref>"
  String? sha;
  for (final line in readString(r.stdout).split('\n')) {
    final parts = line.split('\t');
    if (parts.length != 2) continue;
    final refName = parts[1];
    if (refName == 'refs/tags/$value' || refName == 'refs/heads/$value') {
      sha = parts[0];
      break;
    }
  }
  if (sha == null) {
    stderr.writeln('error: git ls-remote returned no entry for $kind "$value"');
    exit(1);
  }
  if (verbose) stdout.writeln('Resolved $kind "$value" to commit $sha');
  // Fetch the spec at the resolved commit so we get a reproducible
  // tree even if the branch head moves after we resolved the SHA.
  final specPath = await _fetchSpec(sha, specPathInRepo: specPathInRepo, verbose: verbose);
  return (sourceRef: SourceRef(kind: kind, value: value, commitSha: sha), specPath: specPath);
}

class Codegen({
  required final Map<String, dynamic> spec,
  required final SurfaceSpec surface,
  required final String outDir,
  required final bool verbose,

  /// Upstream ref (tag, branch, or commit SHA) the spec was fetched
  /// from, pre-resolved to a commit SHA. Recorded in every generated
  /// file header so we always know exactly what the code was generated
  /// from. Null when the generator is run against a local file with no
  /// tracked upstream.
  final SourceRef? sourceRef,
}) {
  late final Map<String, dynamic> components = readObjectOrNull(spec['components']) ?? const {};
  late final Map<String, dynamic> schemas = Map<String, dynamic>.from(
    readObjectOrNull(components['schemas']) ?? const {},
  );
  late final Map<String, dynamic> paths = readObjectOrNull(spec['paths']) ?? const {};

  /// Maps a schema name → raw names of the unions (anyOf / oneOf) that
  /// list it, in spec order. A schema can belong to several unions
  /// (OpenCode 2.2 lists `Form.ExternalField` in `Form.Field` and
  /// `Form.Field_1`); see [_unionParentFor].
  late final Map<String, List<String>> _unionParents = _buildUnionParents();

  /// The union class [rawName] implements: its first union that is
  /// generated, else its first union (which then gets a stub).
  String? _unionParentFor({required String rawName, required Set<String> selected}) {
    final parents = _unionParents[rawName];
    if (parents == null) return null;
    return _pascalFromSnake(parents.firstWhere(selected.contains, orElse: () => parents.first));
  }

  /// Header block describing the upstream source the code was
  /// generated from: the upstream ref and resolved commit SHA when
  /// [sourceRef] is set, or a `local` marker otherwise. Deliberately
  /// contains NO generation timestamp — regenerating against an
  /// unchanged spec must produce byte-identical output so diffs show
  /// only real upstream changes. Lines are returned WITHOUT the `// `
  /// prefix so callers can emit them as comments themselves.
  String sourceHeader() => switch (sourceRef) {
    final ref? => 'Source: ${ref.display}',
    null => 'Source: local (no upstream ref)',
  };

  Future<void> run() async {
    _run();
  }

  Map<String, List<String>> _buildUnionParents() {
    final out = <String, List<String>>{};
    schemas.forEach((rawName, schema) {
      if (schema is! Map<String, dynamic>) return;
      final variants = readListOrNull(schema['anyOf']) ?? readListOrNull(schema['oneOf']);
      if (variants == null) return;
      for (final v in variants) {
        if (v is! Map<String, dynamic>) continue;
        final r = v[r'$ref'];
        if (r is String && r.startsWith('#/components/schemas/')) {
          final childRaw = _schemaNameFromRef(r);
          // Skip enum variants: Dart enums cannot `implements` an
          // abstract interface class with abstract members, so treating
          // an enum as a union variant would generate broken code.
          if (_isEnum(schemas[childRaw])) continue;
          (out[childRaw] ??= []).add(rawName);
        }
      }
    });
    return out;
  }

  void log(String msg) {
    if (verbose) stdout.writeln('[codegen] $msg');
  }

  void _run() {
    final operations = _selectSurfaceOperations(
      operations: _synthesizeInlineResponseModels(operations: _collectOperations()),
      allowedIds: surface.operations,
    );
    final selectedSchemas = _selectSurfaceSchemas(operations: operations, extraSchemas: surface.extraSchemas);
    final modelsDir = Directory('$outDir/models/openapi');
    if (modelsDir.existsSync()) {
      modelsDir.deleteSync(recursive: true);
    }
    modelsDir.createSync(recursive: true);

    // Skip undotted schemas that have a dotted equivalent with the same
    // normalized filename (e.g. `EventTuiCommandExecute` and
    // `Event.tui.command.execute` both become `event_tui_command_execute`).
    // The dotted variant is the canonical one (it appears in the Event
    // union); the undotted one is a duplicate that would create a
    // second model family.
    final skipSchemas = <String>{};
    for (final name in schemas.keys) {
      if (name.contains('.')) continue;
      final fileName = _snakeFromCamel(name);
      for (final other in schemas.keys) {
        if (other == name) continue;
        final otherFile = _snakeFromCamel(other).replaceAll('.', '_');
        if (other.contains('.') && otherFile == fileName) {
          skipSchemas.add(name);
          break;
        }
      }
    }

    final sortedSchemas = selectedSchemas.toList()..sort();
    for (final name in sortedSchemas) {
      if (skipSchemas.contains(name)) {
        log('SKIP $name (dotted equivalent exists)');
        continue;
      }
      _writeModelFile(
        rawName: name,
        schema: readObject(schemas[name]),
        implementsClass: _unionParentFor(rawName: name, selected: selectedSchemas),
      );
      log('model $name');
    }

    final selectedParentClasses = sortedSchemas.map(_pascalFromSnake).toSet();
    final missingParentClasses = <String>{};
    for (final name in sortedSchemas) {
      final parent = _unionParentFor(rawName: name, selected: selectedSchemas);
      if (parent != null && !selectedParentClasses.contains(parent)) {
        missingParentClasses.add(parent);
      }
    }
    for (final parent in missingParentClasses.toList()..sort()) {
      _writeUnionParentStub(parent);
      log('union parent stub $parent');
    }
  }

  List<Operation> _selectSurfaceOperations({
    required List<Operation> operations,
    required List<String> allowedIds,
  }) {
    final byId = <String, Operation>{
      for (final op in operations) ?op.operationId: op,
    };
    final missing = allowedIds.where((id) => !byId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      stderr.writeln('error: OpenAPI spec is missing allowlisted operationId(s): ${missing.join(', ')}');
      exit(1);
    }
    return [for (final id in allowedIds) ?byId[id]];
  }

  /// Selects the models the plugin decodes: the surface's success
  /// responses and extra schemas, plus every model their generated files
  /// import. The adapters send hand-written request bodies, so a body
  /// model is generated only when the surface lists it in extraSchemas.
  /// SSE events are decoded by the manifest codegen
  /// (`generate_sse_events.dart`), so the event manifest is only
  /// cross-checked against the spec.
  Set<String> _selectSurfaceSchemas({
    required List<Operation> operations,
    required List<String> extraSchemas,
  }) {
    final roots = <String>{...extraSchemas};
    for (final op in operations) {
      final response = op.successResponse;
      if (response != null) _collectTypesFromDartType(dartType: response.dartType, out: roots);
    }
    _warnOnEventManifestDrift();
    final closure = <String>{};
    final stack = roots.where(schemas.containsKey).toList();
    while (stack.isNotEmpty) {
      final name = stack.removeLast();
      if (!closure.add(name)) continue;
      final schema = schemas[name];
      if (schema is! Map<String, dynamic>) continue;
      final refs = ModelWriter(
        name: _pascalFromSnake(name),
        rawName: name,
        schema: schema,
        schemas: schemas,
      ).importedSchemas();
      for (final ref in refs) {
        if (schemas.containsKey(ref) && !closure.contains(ref)) stack.add(ref);
      }
    }
    return closure;
  }

  void _warnOnEventManifestDrift() {
    final manifestPath = surface.eventManifest;
    if (manifestPath == null) return;
    final file = File(manifestPath);
    if (!file.existsSync()) return;
    final manifest = readObject(jsonDecode(file.readAsStringSync()));
    final manifestTypes = {
      for (final event in readList(manifest['events'])) readString(readObject(event)['type']),
    };
    for (final type in manifestTypes) {
      if (!schemas.containsKey(_eventSchemaNameForType(type))) {
        stderr.writeln('warning: manifest event "$type" has no OpenAPI Event schema');
      }
    }
    final specEvents = schemas.keys.where((name) => name.startsWith('Event.')).toList()..sort();
    for (final schemaName in specEvents) {
      final type = schemaName.substring('Event.'.length);
      if (!manifestTypes.contains(type)) {
        stderr.writeln('warning: OpenAPI schema $schemaName is absent from $manifestPath');
      }
    }
  }

  String _eventSchemaNameForType(String type) {
    final candidates = <String>[
      'Event.$type',
      'Event${_pascalCore(type)}',
      'Event${type.split(RegExp('[._]+')).map((part) => part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1)).join()}',
    ];
    for (final candidate in candidates) {
      if (schemas.containsKey(candidate)) return candidate;
    }
    return candidates.first;
  }

  /// Registers the inline success-response schemas the surface names as
  /// models, and returns [operations] with those responses retyped.
  List<Operation> _synthesizeInlineResponseModels({required List<Operation> operations}) {
    final names = surface.inlineResponseModels;
    final out = <Operation>[];
    for (final op in operations) {
      final className = names[op.operationId];
      final schema = op.successResponseSchema;
      if (className == null || schema == null) {
        out.add(op);
      } else if (schema['type'] != 'array') {
        schemas[className] = schema;
        out.add(op.withResponseDartType(className));
      } else {
        final items = schema['items'];
        if (items is Map<String, dynamic>) {
          schemas[className] = items;
          out.add(op.withResponseDartType('List<$className>'));
        } else {
          out.add(op);
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Operation collection
  // ---------------------------------------------------------------------------

  static const _httpVerbs = ['get', 'post', 'put', 'patch', 'delete'];

  List<Operation> _collectOperations() {
    final out = <Operation>[];
    for (final item in paths.values) {
      if (item is! Map<String, dynamic>) continue;
      for (final verb in _httpVerbs) {
        final op = item[verb];
        if (op is! Map<String, dynamic>) continue;
        out.add(Operation.fromOpenApi(op: op));
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // File emission
  // ---------------------------------------------------------------------------

  void _writeModelFile({
    required String rawName,
    required Map<String, dynamic> schema,
    required String? implementsClass,
  }) {
    final cleanName = _pascalFromSnake(rawName);
    final fileName = _snakeFromCamel(rawName);
    final relPath = 'models/openapi/$fileName.g.dart';
    final writer = ModelWriter(
      name: cleanName,
      rawName: rawName,
      schema: schema,
      schemas: schemas,
      implementsClass: implementsClass,
      sourceHeader: sourceHeader(),
    );
    var body = writer.emit();
    // Trim trailing whitespace and ensure the file ends with exactly
    // one newline. The dart analyzer flags `eol_at_end_of_file` if the
    // last byte is not `\n`, and tooling occasionally complains about
    // stray blank lines.
    body = body.trimRight();
    body = '$body\n';
    File('$outDir/$relPath').writeAsStringSync(body);
  }

  void _writeUnionParentStub(String className) {
    final fileName = _snakeFromCamel(className);
    final relPath = 'models/openapi/$fileName.g.dart';
    final body = StringBuffer()
      ..writeln('// GENERATED FILE - DO NOT EDIT BY HAND')
      ..writeln('// ${sourceHeader()}')
      ..writeln()
      ..writeln('abstract interface class $className {')
      ..writeln('  const $className();')
      ..writeln()
      ..writeln('  Object? toJson();')
      ..writeln('}');
    File('$outDir/$relPath').writeAsStringSync(body.toString());
  }

  void _collectTypesFromDartType({required String dartType, required Set<String> out}) {
    // Strip List<...>, Map<String, ...>, ? nullability, etc.
    final base = dartType.replaceAll(RegExp(r'[\?<>\[\], ]'), '').trim();
    if (base.isEmpty) return;
    // Check if it's a top-level schema name
    if (schemas.containsKey(base)) {
      out.add(base);
    }
    // Also handle List<X> by extracting X
    if (RegExp(r'List<(\w+)>').firstMatch(dartType)?.group(1) case final inner?) {
      if (schemas.containsKey(inner)) out.add(inner);
    }
  }
}

String _schemaNameFromRef(String ref) {
  const prefix = '#/components/schemas/';
  if (!ref.startsWith(prefix)) {
    throw ArgumentError('Invalid \$ref: $ref');
  }
  return ref.substring(prefix.length);
}

// ---------------------------------------------------------------------------
// Operation / Response models
// ---------------------------------------------------------------------------

class Operation({required final String? operationId, required final ResponseSpec? successResponse}) {
  factory fromOpenApi({required Map<String, dynamic> op}) {
    final responses = readObjectOrNull(op['responses']) ?? const <String, dynamic>{};
    ResponseSpec? successResponse;
    for (final code in ['200', '201', '202', '203', '204']) {
      final response = responses[code];
      if (response is Map<String, dynamic>) {
        successResponse = ResponseSpec.fromOpenApi(response);
        break;
      }
    }
    return Operation(operationId: readStringOrNull(op['operationId']), successResponse: successResponse);
  }

  Map<String, dynamic>? get successResponseSchema => successResponse?.schema;

  Operation withResponseDartType(String dartType) =>
      Operation(operationId: operationId, successResponse: successResponse?.withDartType(dartType));
}

class SurfaceSpec({
  /// Path of the OpenAPI document inside the upstream repository.
  required final String specPath,
  required final List<String> operations,
  required final List<String> extraSchemas,

  /// Hand-curated SSE event manifest whose events are cross-checked against
  /// the spec's per-event `Event.*` schemas. Null when the spec's event union
  /// is opaque and events are generated from a manifest alone.
  required final String? eventManifest,

  /// Operation id -> class name for inline success-response schemas that
  /// should become named models.
  required final Map<String, String> inlineResponseModels,

  /// New schema name -> `<SchemaName>#<json pointer>` of an inline schema
  /// (typically an inline union) to hoist into a named model.
  required final Map<String, String> hoistSchemas,

  /// Target-schema fields absent in a supported native version.
  required final Map<String, List<String>> optionalProperties,

  /// Object unions emitted with all variants in the same Dart library.
  required final List<String> sealedUnions,
}) {
  factory load(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('error: missing surface file $path');
      exit(2);
    }
    return SurfaceSpec.fromJson(readObject(jsonDecode(file.readAsStringSync())));
  }

  factory fromJson(Map<String, dynamic> json) {
    return SurfaceSpec(
      specPath: readString(json['specPath']),
      operations: readList(json['operations']).map(readString).toList(),
      extraSchemas: (readListOrNull(json['extraSchemas']) ?? const []).map(readString).toList(),
      eventManifest: readStringOrNull(json['eventManifest']),
      inlineResponseModels: (readObjectOrNull(json['inlineResponseModels']) ?? const {}).map(
        (key, value) => MapEntry(key, readString(value)),
      ),
      hoistSchemas: (readObjectOrNull(json['hoistSchemas']) ?? const {}).map(
        (key, value) => MapEntry(key, readString(value)),
      ),
      optionalProperties: (readObjectOrNull(json['optionalProperties']) ?? const {}).map(
        (key, value) => MapEntry(key, readList(value).map(readString).toList()),
      ),
      sealedUnions: (readListOrNull(json['sealedUnions']) ?? const []).map(readString).toList(),
    );
  }
}

class ResponseSpec({required final Map<String, dynamic>? schema, required final String dartType}) {
  factory fromOpenApi(Map<String, dynamic> r) {
    final content = readObjectOrNull(r['content']);
    final json = readObjectOrNull(content?['application/json']);
    final schema = readObjectOrNull(json?['schema']);
    if (schema != null) {
      return ResponseSpec(schema: schema, dartType: _dartTypeFromSchema(schema));
    }
    return ResponseSpec(schema: null, dartType: 'Object');
  }

  ResponseSpec withDartType(String dartType) => ResponseSpec(schema: schema, dartType: dartType);

  static String _dartTypeFromSchema(Map<String, dynamic> sch) {
    final r = sch[r'$ref'];
    if (r is String) {
      final name = _schemaNameFromRef(r);
      return _pascalFromSnake(name);
    }
    final t = sch['type'];
    if (t == 'boolean') return 'bool';
    if (t == 'integer') return 'int';
    if (t == 'number') return 'double';
    if (t == 'string') return 'String';
    if (t == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        return 'List<${_dartTypeFromSchema(items)}>';
      }
      return 'List<Object>';
    }
    final anyOf = sch['anyOf'];
    if (anyOf is List) {
      final variants = anyOf.map(readObject).toList();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeFromSchema(nonNull.first);
      }
      return 'Object';
    }
    return 'Object';
  }
}

// ---------------------------------------------------------------------------
// Model writer
// ---------------------------------------------------------------------------

class ModelWriter({
  /// Cleaned, valid Dart class name.
  required final String name,

  /// Original schema name as it appears in the OpenAPI document.
  required final String rawName,
  required final Map<String, dynamic> schema,
  required final Map<String, dynamic> schemas,

  /// If this schema is a variant of a union, the name of the union class it
  /// implements.
  final String? implementsClass,

  /// Multi-line comment block describing the upstream ref / commit /
  /// generation timestamp. Emitted at the top of every generated file
  /// so consumers and reviewers always know what the code was
  /// generated from.
  final String? sourceHeader,
}) {
  /// Track inline enums we emit (de-duped by their values tuple).
  final List<InlineEnum> _inlineEnums = [];
  final Set<String> _emittedEnumKeys = {};

  /// Inline enums generated for multi-value `type: string` + `enum`
  /// properties, named after the field context (e.g. `CommandSource`).
  /// De-duped by class name so computing a field's type more than once
  /// (type pass, then decode) does not emit the enum twice.
  final Set<String> _inlineEnumNames = {};

  /// String properties OpenCode marks `required` but omits at runtime
  /// (untitled / unversioned sessions), so the generated field must stay
  /// nullable rather than default to `''`. Mirrors the v1 hand-written
  /// models. (`Command.template`, a required string that can arrive as a
  /// non-string payload, is handled separately via its field context.)
  static const _alwaysNullableStringFields = {'title'};
  // Version omission belongs to sessions, not server identity or installation events.
  static const _omittableStringContexts = {'SessionVersion', 'GlobalSessionVersion', 'CommandTemplate'};

  /// Synthesized classes for inline `type: object` schemas with
  /// `properties` (e.g. `Session.time` → `SessionTime`). Registered by
  /// [_dartTypeForInline] while computing field types; emitted as
  /// siblings after the main class. Acts as a worklist: emitting one
  /// synthesized class may register more (nested inline objects).
  final List<_InlineObjectEntry> _inlineObjects = [];
  final Set<String> _inlineObjectNames = {};

  /// Usage flags, populated during body emission so the header only
  /// imports what the body references.
  bool _usesJsonValue = false;
  bool _usesImmutable = false;
  bool _usesDeepEquality = false;

  String emit() {
    // First pass: figure out which refs the body will actually use.
    final usedRefs = importedSchemas();
    if (implementsClass != null) {
      String? parentRaw;
      for (final entry in schemas.entries) {
        if (_pascalFromSnake(entry.key) == implementsClass) {
          parentRaw = entry.key;
          break;
        }
      }
      if (parentRaw != null) usedRefs.add(parentRaw);
    }

    // Emit the body FIRST: body emission populates the usage flags and
    // the inline-enum / inline-object worklists the header and tail
    // emission depend on.
    final body = StringBuffer();
    if (_isEnum(schema)) {
      body.write(_emitEnum());
    } else if (_isUnion(schema)) {
      body.write(_emitUnion());
    } else if (_isArray(schema)) {
      body.write(_emitArrayAlias());
    } else if (_isObject(schema)) {
      body.write(_emitObject());
    } else {
      body.write('// TODO: unknown schema kind for $name\n');
    }

    // Drain the inline-object worklist. Index-based loop on purpose:
    // emitting an entry can append new entries (nested inline objects).
    var i = 0;
    while (i < _inlineObjects.length) {
      final entry = _inlineObjects[i];
      i++;
      body.writeln();
      body.write(_emitObjectClass(className: entry.className, sch: entry.schema, implementsClass: null));
    }

    // Emit any inline enums collected during body emission.
    for (final ie in _inlineEnums) {
      body.writeln();
      body.write(ie.emit());
      _usesJsonValue = true;
    }

    final header = _emitHeader(
      usedRefs,
      usesJsonAnnotation: _usesJsonValue,
      usesImmutable: _usesImmutable,
      usesDeepEquality: _usesDeepEquality,
    );
    return header + body.toString();
  }

  /// Raw names of the schemas this model's file imports, apart from the
  /// union parent it implements. [Codegen] walks these to select the
  /// models a surface needs, so a schema reached only through a field that
  /// collapses to `Object?` is not generated.
  Set<String> importedSchemas() {
    final usedRefs = _computeUsedRefs(schema);
    usedRefs.remove(rawName);
    // Inline variants synthesized in `_emitUnion` reference refs of
    // their own (e.g. `PermissionRuleConfig.fromJson`). The header
    // import list must include them or the synthesized classes will
    // reference undefined identifiers.
    if (_isUnion(schema)) {
      final variants = readList(schema['anyOf'] ?? schema['oneOf']).map(readObject).toList();
      for (final v in variants) {
        final inlineRefs = _computeUsedRefs(v);
        usedRefs.addAll(inlineRefs);
      }
      // Refs that flow through an enum wrapper also need to be
      // imported.
      final disc = _findDiscriminator(variants);
      if (disc == null) {
        for (final v in variants) {
          final r = v[r'$ref'];
          if (r is String) {
            final vName = _schemaNameFromRef(r);
            if (_isEnum(schemas[vName])) {
              usedRefs.add(vName);
            }
          }
        }
      }
    }
    return usedRefs;
  }

  /// Returns the set of raw schema names that the emitted body actually
  /// references as Dart types. Unlike a deep walk, this only includes refs
  /// that produce a typed identifier in the generated code (field types,
  /// union variants, array items, map values, parent class). Refs buried
  /// inside inline objects that become `Map<String, dynamic>` are skipped.
  Set<String> _computeUsedRefs(Map<String, dynamic> sch) {
    final refs = <String>{};
    void addRef(String s) {
      if (s.startsWith('#/components/schemas/')) {
        refs.add(_schemaNameFromRef(s));
      }
    }

    void visitField(Object? node) {
      if (node is! Map) return;
      // Direct $ref at the top of a field.
      final r = node[r'$ref'];
      if (r is String) {
        addRef(r);
        return;
      }
      // anyOf / oneOf: only follow if exactly one non-null variant.
      for (final key in ['anyOf', 'oneOf']) {
        final v = node[key];
        if (v is List) {
          final nonNull = v.where((x) => x is Map && x['type'] != 'null').map(readObject).toList();
          if (nonNull.length == 1) {
            visitField(nonNull.first);
            return;
          }
          // Multi-variant anyOf collapses to `dynamic`; stop.
          return;
        }
      }
      // Array: only the item $ref matters.
      if (node['type'] == 'array') {
        final items = node['items'];
        if (items is Map) visitField(items);
        return;
      }
      // Inline object with properties: a typed sibling class is
      // synthesized for it, so each property becomes a typed field —
      // recurse so $refs inside it get imported.
      if (node['type'] == 'object') {
        final props = node['properties'];
        if (props is Map && props.isNotEmpty) {
          props.values.forEach(visitField);
          return;
        }
        // Object with additionalProperties as a $ref (map type).
        final ap = node['additionalProperties'];
        if (ap is Map) visitField(ap);
        return;
      }
      // Otherwise: primitive / inline — no typed refs to follow.
    }

    // Walk the schema's properties (each becomes a typed field).
    final properties = readObjectOrNull(sch['properties']);
    if (properties != null) {
      for (final entry in properties.entries) {
        visitField(entry.value);
      }
    }
    // If the schema has no `properties` but defines `additionalProperties`
    // (a map-typed class — e.g. `PermissionObjectConfig`,
    // `ReferenceConfig`), follow the value-side ref so the import for
    // the value class is emitted.
    if (properties == null || properties.isEmpty) {
      final ap = sch['additionalProperties'];
      if (ap is Map) visitField(ap);
    }
    // If this is itself a union (anyOf/oneOf at the top level), each
    // variant is referenced in the discriminator switch — but only if a
    // discriminator value can be resolved. Otherwise (no discriminator
    // found), we still need to import every $ref variant because the
    // type-guard dispatch in `fromJson` calls each one by name.
    final variants = sch['anyOf'] ?? sch['oneOf'];
    if (variants is List) {
      final disc = _findDiscriminator(variants.map(readObject).toList());
      for (final variant in variants) {
        if (variant is! Map) continue;
        final r = variant[r'$ref'];
        if (r is! String) continue;
        final vName = _schemaNameFromRef(r);
        if (disc != null) {
          if (_discriminatorValue(variantName: vName, discName: disc) != null) {
            addRef(r);
          }
        } else {
          // No discriminator: dispatch is by JSON shape, but we still
          // reference the variant type by name (e.g.
          // `PermissionActionConfig.fromJson(json)`), so the import
          // is needed.
          addRef(r);
        }
      }
    }
    // If this is a top-level array, the item ref is a Dart type.
    if (sch['type'] == 'array') {
      final items = sch['items'];
      if (items is Map) visitField(items);
    }
    return refs;
  }

  String _emitHeader(
    Set<String> refs, {
    required bool usesJsonAnnotation,
    required bool usesImmutable,
    required bool usesDeepEquality,
  }) {
    final b = StringBuffer();
    b.writeln('// GENERATED FILE - DO NOT EDIT BY HAND');
    if (sourceHeader case final header? when header.isNotEmpty) {
      for (final line in header.split('\n')) {
        b.writeln('// $line');
      }
    }
    b.writeln();
    // Only emit imports the body actually uses; anything else triggers
    // `unused_import` warnings on every generated file.
    if (usesDeepEquality) {
      b.writeln("import 'package:collection/collection.dart';");
    }
    if (usesJsonAnnotation) {
      b.writeln("import 'package:json_annotation/json_annotation.dart';");
    }
    if (usesImmutable) {
      b.writeln("import 'package:meta/meta.dart';");
    }
    final sortedRefs = refs.toList()..sort();
    for (final ref in sortedRefs) {
      b.writeln("import '${_snakeFromCamel(ref)}.g.dart';");
    }
    b.writeln();
    return b.toString();
  }

  bool _isUnion(Map<String, dynamic> s) {
    final anyOf = s['anyOf'];
    final oneOf = s['oneOf'];
    return (anyOf is List && anyOf.isNotEmpty) || (oneOf is List && oneOf.isNotEmpty);
  }

  bool _isArray(Map<String, dynamic> s) {
    return s['type'] == 'array';
  }

  bool _isObject(Map<String, dynamic> s) {
    return s['type'] == 'object' || (s['properties'] is Map);
  }

  String _emitArrayAlias() {
    // Generate a type alias for a top-level array schema, e.g.
    // `PermissionRuleset` = `List<PermissionRule>`. Implemented as a class
    // with a single static `fromList` factory for JSON compatibility.
    final items = readObjectOrNull(schema['items']);
    final innerDart = items != null ? _dartTypeForInline(items, context: '${name}Item') : 'Object';
    final innerClass = switch (items?[r'$ref']) {
      final String ref => _pascalFromSnake(_schemaNameFromRef(ref)),
      _ => innerDart,
    };
    final isPrimitiveInner = _isInlinePrimitive(innerDart);
    final innerElement = isPrimitiveInner ? 'e as $innerDart' : '$innerClass.fromJson(e as Map<String, dynamic>)';
    _usesImmutable = true;
    _usesDeepEquality = true;
    final b = StringBuffer();
    b.writeln('/// Type alias for `List<$innerClass>` decoded from JSON.');
    b.writeln('@immutable');
    b.writeln('class $name {');
    b.writeln('  const $name({required this.items});');
    b.writeln('  factory $name.fromJson(List<dynamic> json) => $name(items: json.map((e) => $innerElement).toList());');
    if (isPrimitiveInner) {
      b.writeln('  List<dynamic> toJson() => items.toList();');
    } else {
      b.writeln('  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();');
    }
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      identical(this, other) ||');
    b.writeln('      (other is $name &&');
    b.writeln('          const DeepCollectionEquality().equals(other.items, items));');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => const DeepCollectionEquality().hash(items);');
    b.writeln();
    b.writeln('  final List<$innerClass> items;');
    b.writeln('}');
    return b.toString();
  }

  /// Like `_isPrimitiveType` but available as a static method (ModelWriter
  /// cannot reach Codegen's instance state).
  static bool _isInlinePrimitive(String t) {
    return t == 'bool' ||
        t == 'int' ||
        t == 'double' ||
        t == 'String' ||
        t == 'DateTime' ||
        t == 'Uri' ||
        t == 'Object';
  }

  // -------------------------------------------------------------------------
  // Enum emission
  // -------------------------------------------------------------------------

  String _emitEnum() {
    _usesJsonValue = true;
    return _emitEnumBody(enumName: name, values: readList(schema['enum']).map(readString).toList());
  }

  // -------------------------------------------------------------------------
  // Union emission (sealed class with discriminator)
  // -------------------------------------------------------------------------

  String _emitUnion() {
    final b = StringBuffer();

    final variants = readList(schema['anyOf'] ?? schema['oneOf']).map(readObject).toList();
    final declaration = schema['x-sesori-sealed'] == true ? 'sealed class' : 'abstract interface class';

    final disc = _findDiscriminator(variants);
    final inlineVariantClasses = <_InlineVariantClassEntry>[];

    _usesImmutable = true;
    b.writeln('@immutable');
    // A union nested inside another union implements the outer one, so
    // the outer `fromJson` can return the nested union's decode.
    b.writeln(
      implementsClass != null ? '$declaration $name implements $implementsClass {' : '$declaration $name {',
    );
    b.writeln('  const $name();');
    b.writeln();
    b.writeln('  /// Serialize the underlying variant. Variants must override this.');
    b.writeln('  ///');
    b.writeln('  /// The return type is `Object?` (not `Map<String, dynamic>`)');
    b.writeln('  /// because some unions are string-or-object and the string');
    b.writeln('  /// variant encodes as the scalar itself, not a wrapped map.');
    b.writeln('  /// Callers pass the result straight to `jsonEncode` or');
    b.writeln('  /// another `toJson()`, both of which accept `Object?`.');
    b.writeln('  Object? toJson();');
    b.writeln();
    b.writeln('  factory $name.fromJson(Object json) {');
    if (disc != null) {
      // Discriminator-driven dispatch: every variant carries the same
      // string-enum property with a unique value. Works for both
      // $ref variants (decoded via the existing model's fromJson) and
      // inline variants (synthesized into a sibling class below).
      b.writeln('    final map = json as Map<String, dynamic>;');
      b.writeln('    final discriminator = map[${jsonEncode(disc)}];');
      b.writeln('    switch (discriminator) {');
      for (final v in variants) {
        final r = v[r'$ref'];
        if (r is String) {
          final vName = _schemaNameFromRef(r);
          final d = _discriminatorValue(variantName: vName, discName: disc);
          if (d != null) {
            b.writeln('      case ${jsonEncode(d)}:');
            b.writeln('        return ${_pascalFromSnake(vName)}.fromJson(map);');
          }
        } else {
          final d = _inlineDiscriminatorValue(variant: v, discName: disc);
          if (d != null) {
            final inlineName = readStringOrNull(v['x-sesori-variant-name']) ?? '$name${_pascalCore(d)}';
            inlineVariantClasses.add(
              _InlineVariantClassEntry(
                className: inlineName,
                schema: v,
              ),
            );
            b.writeln('      case ${jsonEncode(d)}:');
            b.writeln('        return $inlineName.fromJson(map);');
          }
        }
      }
      b.writeln('      default:');
      b.writeln('        return ${name}Unknown(raw: map);');
      b.writeln('    }');
    } else {
      // No discoverable discriminator: dispatch on JSON shape. We try
      // each variant in order, using a type guard (`json is String`,
      // `json.containsKey('X')`, `json is Map`) followed by a
      // best-effort decode. The first match wins; a final throw
      // covers the truly unknown case.
      var inlineIndex = 0;
      // A later variant with an already-emitted guard is unreachable (the
      // first match wins), e.g. a string enum after a plain string; skip it
      // rather than emit a dead branch and its variant class.
      final emittedGuards = <String>{};
      for (final v in variants) {
        final guard = _unionTypeGuard(v);
        if (guard == null || emittedGuards.contains(guard)) continue;
        final decode = _unionTypeDecode(variant: v, inlineIndex: inlineIndex);
        if (decode == null) continue;
        emittedGuards.add(guard);
        b.writeln('    if ($guard) {');
        b.writeln('      return $decode;');
        b.writeln('    }');
        // If the variant is an enum $ref, wrap it in a synthesized
        // class so the union interface has a non-enum implementation
        // (Dart enums cannot `implements` an interface that
        // declares abstract members). Inline STRING/ARRAY/OBJECT
        // variants get their own synthesized classes too.
        final r = v[r'$ref'];
        if (r is String) {
          final vName = _schemaNameFromRef(r);
          if (_isEnum(schemas[vName])) {
            final inlineName = '$name${inlineIndex.toString().padLeft(2, '0')}Inline';
            inlineVariantClasses.add(
              _InlineVariantClassEntry(
                className: inlineName,
                schema: v,
              ),
            );
          }
        } else {
          final inlineName = '$name${inlineIndex.toString().padLeft(2, '0')}Inline';
          inlineVariantClasses.add(
            _InlineVariantClassEntry(
              className: inlineName,
              schema: v,
            ),
          );
        }
        inlineIndex++;
      }
      b.writeln('    return ${name}Unknown(raw: json);');
    }
    b.writeln('  }');
    b.writeln('}');
    b.writeln();

    // Emit any synthesized inline variant classes that the union
    // references. Each one implements the union interface and exposes
    // a typed `toJson()`.
    for (final entry in inlineVariantClasses) {
      b.writeln(_emitInlineVariantClass(className: entry.className, schema: entry.schema, unionName: name));
      b.writeln();
    }

    // Fallback variant: preserves the raw JSON of shapes this generator
    // version doesn't recognize, so payloads from newer OpenCode servers
    // decode instead of throwing. `toJson` round-trips the raw value.
    _usesDeepEquality = true;
    b.writeln('/// Fallback variant for an unrecognized [$name] payload shape.');
    b.writeln('/// Carries the raw JSON so newer OpenCode servers do not break');
    b.writeln('/// decoding; `toJson` returns the payload unchanged.');
    b.writeln('@immutable');
    final variantModifier = schema['x-sesori-sealed'] == true ? 'final ' : '';
    b.writeln('${variantModifier}class ${name}Unknown implements $name {');
    b.writeln('  const ${name}Unknown({required this.raw});');
    b.writeln();
    b.writeln('  final Object? raw;');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  Object? toJson() => raw;');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      identical(this, other) ||');
    b.writeln('      (other is ${name}Unknown &&');
    b.writeln('          const DeepCollectionEquality().equals(other.raw, raw));');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => const DeepCollectionEquality().hash(raw);');
    b.writeln('}');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Object emission
  // -------------------------------------------------------------------------

  /// Emit a synthesized class for an inline variant in a union. Inline
  /// variants appear directly inside an anyOf/oneOf instead of via $ref;
  /// to give them a name and a typed fromJson/toJson we materialize a
  /// sibling class next to the union. The synthesized name is
  /// `<Union>NNInline` where `NN` is the variant's index in the union
  /// (zero-padded to two digits).
  String _emitInlineVariantClass({
    required String className,
    required Map<String, dynamic> schema,
    required String unionName,
  }) {
    final b = StringBuffer();
    // Wrapper case: a union variant that is a $ref to an enum (or
    // any other type Dart cannot make implement an abstract
    // interface with abstract members) is materialized as a
    // synthesized wrapper class that holds the inner value. This
    // keeps the union interface uniform (every implementer is a
    // class) and lets the dispatch site return a typed object.
    final ref = schema[r'$ref'];
    if (ref is String) {
      final refName = _schemaNameFromRef(ref);
      final refType = _pascalFromSnake(refName);
      if (_isEnum(schemas[refName])) {
        _usesImmutable = true;
        b.writeln('@immutable');
        b.writeln('class $className implements $unionName {');
        b.writeln('  const $className({required this.value});');
        b.writeln('  factory $className.fromJson(String json) {');
        b.writeln('    return $className(value: $refType.fromJson(json));');
        b.writeln('  }');
        b.writeln('  @override');
        // The enum-wrapper exists only to give an abstract-method
        // implementer a non-enum type (Dart enums cannot `implements`
        // an interface with abstract members). The JSON shape of this
        // variant in the union is the SCALAR string the enum encodes,
        // not a wrapped map. Returning the scalar here keeps a
        // read-modify-write round-trip identical to the original
        // server payload (e.g. 'permission: "ask"' stays 'permission:
        // "ask"', not 'permission: {"value": "ask"}').
        b.writeln('  Object? toJson() => value.toJson();');
        b.writeln();
        b.writeln('  @override');
        b.writeln('  bool operator ==(Object other) =>');
        b.writeln('      identical(this, other) ||');
        b.writeln('      (other is $className && other.value == value);');
        b.writeln();
        b.writeln('  @override');
        b.writeln('  int get hashCode => value.hashCode;');
        b.writeln();
        b.writeln('  final $refType value;');
        b.writeln('}');
        return b.toString();
      }
      // For non-enum $ref variants in the no-discriminator path we
      // wouldn't normally synthesize a class, but the dispatch may
      // still need one. Fall through to the other branches.
    }
    final type = schema['type'];
    if (type == 'string') {
      // Inline string variant — render an enum if the schema has an
      // `enum` list, otherwise a simple String wrapper.
      final enumVals = readListOrNull(schema['enum'])?.map(readString).toList();
      if (enumVals != null && enumVals.isNotEmpty) {
        _usesJsonValue = true;
        b.write(_emitEnumBody(enumName: className, values: enumVals));
      } else {
        _usesImmutable = true;
        b.writeln('@immutable');
        b.writeln('class $className implements $unionName {');
        b.writeln('  const $className({required this.value});');
        b.writeln('  factory $className.fromJson(String json) {');
        b.writeln('    return $className(value: json);');
        b.writeln('  }');
        b.writeln('  @override');
        // String shorthand variant — the JSON shape is the scalar
        // string itself, not a wrapped map. Returning the scalar keeps
        // a read-modify-write round-trip identical to the original
        // server payload (e.g. 'ref: "abc"' stays 'ref: "abc"',
        // not 'ref: {"value": "abc"}').
        b.writeln('  Object? toJson() => value;');
        b.writeln();
        b.writeln('  @override');
        b.writeln('  bool operator ==(Object other) =>');
        b.writeln('      identical(this, other) ||');
        b.writeln('      (other is $className && other.value == value);');
        b.writeln();
        b.writeln('  @override');
        b.writeln('  int get hashCode => value.hashCode;');
        b.writeln();
        b.writeln('  final String value;');
        b.writeln('}');
      }
      return b.toString();
    }
    if (type == 'array') {
      // Inline array variant — wrap it in a list class.
      final items = schema['items'];
      String innerDart;
      if (items is Map<String, dynamic>) {
        final ir = items[r'$ref'];
        if (ir is String) {
          innerDart = _pascalFromSnake(_schemaNameFromRef(ir));
        } else {
          innerDart = _dartTypeForInline(items, context: '${className}Item');
        }
      } else {
        innerDart = 'Object?';
      }
      _usesImmutable = true;
      _usesDeepEquality = true;
      b.writeln('@immutable');
      b.writeln('class $className implements $unionName {');
      b.writeln('  const $className({required this.items});');
      b.writeln('  factory $className.fromJson(List<dynamic> json) {');
      b.writeln('    return $className(items: json.cast<$innerDart>());');
      b.writeln('  }');
      b.writeln('  @override');
      // Array shorthand variant — the JSON shape is the scalar list
      // itself, not a wrapped map. Returning the list keeps the
      // round-trip identical to the original server payload.
      b.writeln('  Object? toJson() => items;');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  bool operator ==(Object other) =>');
      b.writeln('      identical(this, other) ||');
      b.writeln('      (other is $className &&');
      b.writeln('          const DeepCollectionEquality().equals(other.items, items));');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  int get hashCode => const DeepCollectionEquality().hash(items);');
      b.writeln();
      b.writeln('  final List<$innerDart> items;');
      b.writeln('}');
      return b.toString();
    }
    if (type == 'object') {
      final properties = readObjectOrNull(schema['properties']);
      if ((properties != null && properties.isNotEmpty) || schema['additionalProperties'] == false) {
        // Structured inline objects use fields; unrestricted objects below
        // retain their keys instead of decoding to an empty class.
        return _emitObjectClass(className: className, sch: schema, implementsClass: unionName);
      }
    }
    // Free-form object or opaque fallback: preserve the original map.
    _usesImmutable = true;
    _usesDeepEquality = true;
    b.writeln('@immutable');
    b.writeln('class $className implements $unionName {');
    b.writeln('  const $className({required this.json});');
    b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    b.writeln('    return $className(json: json);');
    b.writeln('  }');
    b.writeln('  @override');
    b.writeln('  Map<String, dynamic> toJson() => json;');
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      identical(this, other) ||');
    b.writeln('      (other is $className &&');
    b.writeln('          const DeepCollectionEquality().equals(other.json, json));');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => const DeepCollectionEquality().hash(json);');
    b.writeln();
    b.writeln('  final Map<String, dynamic> json;');
    b.writeln('}');
    return b.toString();
  }

  String _emitObject() {
    final properties = readObjectOrNull(schema['properties']) ?? const {};

    // Pure map-typed schema: `type: object, additionalProperties: <schema>`
    // with no `properties`. Generate a class that wraps a single
    // `Map<String, ValueType>` field instead of an empty class, so the
    // generated code round-trips OpenCode config fields like
    // `permission: { bash: { "git status": "allow" } }` and
    // `reference: { myAlias: ... }` instead of silently dropping
    // every entry on `fromJson` and writing `{}` on `toJson`.
    if (properties.isEmpty) {
      final ap = schema['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return _emitMapWrapper(ap: ap);
      }
      // Free-form object schema with no explicit additionalProperties
      // restriction (e.g. JSONSchema). Preserve the raw JSON map rather
      // than discarding every key in an empty class.
      if (ap == true || ap == null) {
        return _emitFreeformMapWrapper();
      }
    }
    return _emitObjectClass(className: name, sch: schema, implementsClass: implementsClass);
  }

  /// Emits a complete plain object class [className] for [sch]. Shared
  /// by top-level object schemas, union inline-object variants (with
  /// [implementsClass] set), and classes synthesized for inline object
  /// properties (e.g. `SessionTime`).
  String _emitObjectClass({
    required String className,
    required Map<String, dynamic> sch,
    required String? implementsClass,
  }) {
    final b = StringBuffer();
    final properties = readObjectOrNull(sch['properties']) ?? const {};
    final required = (readListOrNull(sch['required']) ?? const []).map(readString).toList();

    // Discriminator / literal properties: a required single-value enum
    // property on a class that implements a union is a constant that
    // fully determines the variant. Exposing it as a constructor
    // parameter invites callers to construct a payload with a wrong
    // discriminator value (e.g. `EventAccountRemoved(type: 'account.
    // added')`), which would round-trip to a different variant on
    // deserialization. Hide it from the constructor, fields, and
    // fromJson, and emit the literal value in toJson.
    final literals = <String, String>{};
    if (implementsClass != null) {
      for (final MapEntry(:key, :value) in properties.entries) {
        final psch = readObjectOrNull(value);
        if (psch case {'type': 'string', 'enum': [final String literal]}) {
          literals[key] = literal;
        }
      }
    }

    // Field records, computed ONCE so the constructor, fromJson, toJson,
    // ==, hashCode, and field declarations all agree on each field's
    // type. Computing the Dart type also registers inline-object /
    // inline-enum synthesis as a side effect, so this must happen
    // before any section is emitted.
    final fields = <_FieldRecord>[];
    for (final entry in properties.entries) {
      if (literals.containsKey(entry.key)) continue;
      final fieldName = entry.key;
      final psch = readObject(entry.value);
      final isRequired = required.contains(fieldName);
      final isSchemaNullable = _isNullableSchema(psch);
      // Synthesized-class name for this field if it turns out to be an
      // inline object (e.g. `Session` + `time` -> `SessionTime`).
      final context = '$className${_pascalCore(fieldName)}';
      final baseType = _dartTypeForInline(psch, context: context);
      // Nullability follows the spec's `required` array. A small curated
      // set of string fields is the exception: OpenCode marks
      // `title`/`version` as `required` yet omits them for
      // untitled/unversioned sessions, and `Command.template` can arrive
      // as a non-string. The v1 hand-written models kept these nullable;
      // defaulting a missing value to `''` renders e.g. a blank session
      // title on mobile instead of the untitled fallback. Every other
      // required field (including identity strings like `id`/`sessionID`)
      // stays non-nullable — a missing value there is a real contract
      // violation that should surface loudly rather than be papered over
      // with a synthetic default.
      final isOmittableString =
          baseType == 'String' &&
          (_alwaysNullableStringFields.contains(fieldName) || _omittableStringContexts.contains(context));
      final isNonNull = isRequired && !isSchemaNullable && !isOmittableString;
      fields.add(
        _FieldRecord(
          jsonName: fieldName,
          safeName: _safeIdentifier(fieldName),
          schema: psch,
          isRequired: isRequired,
          dartType: isNonNull ? baseType : '$baseType?',
          context: context,
        ),
      );
    }
    if (className == 'Command' && !fields.any((field) => field.jsonName == 'provider')) {
      fields.add(
        _FieldRecord(
          jsonName: 'provider',
          safeName: 'provider',
          schema: const {'type': 'string'},
          isRequired: false,
          dartType: 'String?',
          context: '${className}Provider',
        ),
      );
    }

    _usesImmutable = true;
    b.writeln('@immutable');
    final modifier = schema['x-sesori-sealed'] == true && implementsClass != null ? 'final ' : '';
    b.writeln(
      implementsClass != null ? '${modifier}class $className implements $implementsClass {' : 'class $className {',
    );
    if (fields.isEmpty) {
      // Empty class: `const Name({});` is a Dart parse error (empty `{}`
      // parameter list). Use `()` instead.
      b.writeln('  const $className();');
    } else {
      b.writeln('  const $className({');
      for (final f in fields) {
        // Every field is a `required` named parameter — even nullable
        // ones. OpenCode may omit a value from JSON (handled by
        // `fromJson` passing `null`), but in Dart we force every caller
        // to acknowledge each field explicitly rather than silently
        // defaulting it to `''`/`0`/`{}`.
        b.writeln('    required this.${f.safeName},');
      }
      b.writeln('  });');
    }
    b.writeln();

    // fromJson
    if (fields.isEmpty) {
      // Empty object: use `const` to satisfy `prefer_const_constructors`.
      // The OpenAPI spec defines this schema as `{}` with no modeled
      // fields, so the API may legitimately return additional
      // properties we discard. Suppress the unused-parameter lint
      // because the parameter exists only to satisfy the `fromJson`
      // contract callers expect.
      b.writeln(
        '  // ignore: avoid_unused_constructor_parameters',
      );
      b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
      b.writeln('    return const $className();');
      b.writeln('  }');
    } else {
      b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
      b.writeln('    return $className(');
      for (final f in fields) {
        b.writeln(
          '      ${_decodeField(name: f.jsonName, sch: f.schema, isNullable: f.isNullable, context: f.context)},',
        );
      }
      b.writeln('    );');
      b.writeln('  }');
    }
    b.writeln();

    // toJson
    if (implementsClass != null) {
      b.writeln('  @override');
    }
    b.writeln('  Map<String, dynamic> toJson() {');
    b.writeln('    return <String, dynamic>{');
    for (final entry in properties.entries) {
      final literal = literals[entry.key];
      if (literal != null) {
        // Discriminator / constant: emit the literal value the class
        // is supposed to carry, not a field reference.
        b.writeln('      ${_safeKey(entry.key)}: ${jsonEncode(literal)},');
        continue;
      }
      final f = fields.firstWhere((x) => x.jsonName == entry.key);
      // `omitWhenNull` stays keyed on the spec `required` array (not the
      // Dart nullability): a required-but-nullable field like
      // `GlobalSession.project` must still serialize its key as `null`
      // rather than vanish, so round-trips preserve the explicit null.
      b.writeln(
        '      ${_encodeField(name: f.jsonName, sch: f.schema, isNullable: f.isNullable, omitWhenNull: !f.isRequired, context: f.context)},',
      );
    }
    for (final f in fields.where((field) => !properties.containsKey(field.jsonName))) {
      b.writeln(
        '      ${_encodeField(name: f.jsonName, sch: f.schema, isNullable: true, omitWhenNull: true, context: f.context)},',
      );
    }
    b.writeln('    };');
    b.writeln('  }');
    b.writeln();

    if (fields.isNotEmpty) {
      b.writeln('  /// Returns a copy with non-null arguments replacing existing values.');
      b.writeln('  /// Nullable fields cannot be set to null through this helper; null means keep.');
      b.writeln('  $className copyWith({');
      for (final f in fields) {
        b.writeln('    ${_copyWithParamType(f.dartType)} ${f.safeName},');
      }
      b.writeln('  }) {');
      b.writeln('    return $className(');
      for (final f in fields) {
        b.writeln('      ${f.safeName}: ${f.safeName} ?? this.${f.safeName},');
      }
      b.writeln('    );');
      b.writeln('  }');
      b.writeln();
    }

    // == / hashCode. Collection-typed fields (and `Object` fields,
    // which may hold decoded JSON maps/lists) use deep structural
    // equality — Dart's `==` on List/Map compares identity, which
    // would make two identical decoded payloads unequal.
    if (fields.isNotEmpty) {
      b.writeln('  @override');
      b.writeln('  bool operator ==(Object other) =>');
      b.writeln('      identical(this, other) ||');
      b.writeln('      (other is $className &&');
      final fieldChecks = fields
          .map((f) {
            if (_needsDeepEquality(f.dartType)) {
              _usesDeepEquality = true;
              return '          const DeepCollectionEquality().equals(other.${f.safeName}, ${f.safeName})';
            }
            return '          other.${f.safeName} == ${f.safeName}';
          })
          .join(' &&\n');
      b.writeln('$fieldChecks);');
      b.writeln();
      b.writeln('  @override');
      final hashExprs = fields.map((f) {
        if (_needsDeepEquality(f.dartType)) {
          _usesDeepEquality = true;
          return 'const DeepCollectionEquality().hash(${f.safeName})';
        }
        return f.safeName;
      }).toList();
      if (fields.length == 1) {
        final f = fields.first;
        if (_needsDeepEquality(f.dartType)) {
          b.writeln('  int get hashCode => const DeepCollectionEquality().hash(${f.safeName});');
        } else {
          b.writeln('  int get hashCode => ${f.safeName}.hashCode;');
        }
      } else if (fields.length <= 20) {
        b.writeln('  int get hashCode => Object.hash(${hashExprs.join(', ')});');
      } else {
        b.writeln('  int get hashCode => Object.hashAll([${hashExprs.join(', ')}]);');
      }
      b.writeln();
    }

    // Fields
    for (final f in fields) {
      b.writeln('  final ${f.dartType} ${f.safeName};');
    }
    b.writeln('}');
    return b.toString();
  }

  /// True when [dartType] needs deep structural comparison in `==` /
  /// `hashCode`: Dart compares `List`/`Map` by identity, and `Object`
  /// fields may hold decoded JSON collections.
  static bool _needsDeepEquality(String dartType) {
    final t = dartType.endsWith('?') ? dartType.substring(0, dartType.length - 1) : dartType;
    return t.startsWith('List<') || t.startsWith('Map<') || t == 'Object';
  }

  static String _copyWithParamType(String dartType) {
    return dartType.endsWith('?') ? dartType : '$dartType?';
  }

  void _registerInlineObject({required String className, required Map<String, dynamic> sch}) {
    if (_inlineObjectNames.contains(className)) return;
    _inlineObjectNames.add(className);
    _inlineObjects.add(_InlineObjectEntry(className: className, schema: sch));
  }

  void _registerInlineEnum({required String className, required List<String> values}) {
    if (!_inlineEnumNames.add(className)) return;
    _inlineEnums.add(InlineEnum(className: className, values: values));
  }

  /// Emit a class for a top-level map-typed schema (no `properties`, but
  /// `additionalProperties: <schema>`). The class has a single field
  /// `value` of type `Map<String, ValueType>` and round-trips through
  /// `fromJson` / `toJson` by decoding/encoding each entry.
  ///
  /// Used for schemas like `PermissionObjectConfig` (typed map of string
  /// → `PermissionActionConfig`) and `ReferenceConfig` (typed map of
  /// string → `ReferenceConfigEntry`).
  String _emitMapWrapper({required Map<String, dynamic> ap}) {
    final b = StringBuffer();
    final valueDart = _dartTypeForInline(ap, context: '${name}Value');
    final isPrimitive = _isInlinePrimitive(valueDart);
    final isNullable = _isNullableSchema(ap);
    final valueType = isNullable ? '$valueDart?' : valueDart;
    final apProps = ap['properties'];
    final isInlineObjectValue =
        ap[r'$ref'] is! String && ap['type'] == 'object' && apProps is Map && apProps.isNotEmpty;

    _usesImmutable = true;
    _usesDeepEquality = true;
    b.writeln('@immutable');
    b.writeln(implementsClass != null ? 'class $name implements $implementsClass {' : 'class $name {');
    b.writeln('  const $name({required this.value});');
    b.writeln();

    // fromJson: decode each entry's value per the inner schema shape.
    // For $ref object values, call `RefType.fromJson(v)`. For $ref array
    // values (top-level array wrappers), call `ArrayType.fromJson(v as
    // List<dynamic>)`. For $ref string-enum values, call
    // `EnumType.fromJson(v as String)`. For primitive values, plain cast.
    String decodeExpr;
    final ref = ap[r'$ref'];
    if (ref is String) {
      final refName = _schemaNameFromRef(ref);
      final refSchema = readObjectOrNull(schemas[refName]);
      final isRefArray = refSchema != null && refSchema['type'] == 'array';
      final isRefStringEnum = refSchema != null && refSchema['type'] == 'string' && refSchema['enum'] is List;
      String cast;
      if (isRefArray) {
        cast = 'List<dynamic>';
      } else if (isRefStringEnum) {
        cast = 'String';
      } else if (_isUnionRef(refName)) {
        // Union factories take `dynamic` and dispatch on shape; a
        // pre-cast to Map<String, dynamic> would break the string-
        // shorthand branch.
        cast = '';
      } else {
        cast = 'Map<String, dynamic>';
      }
      decodeExpr = cast.isEmpty ? '$valueDart.fromJson(v as Object)' : '$valueDart.fromJson(v as $cast)';
    } else if (isInlineObjectValue) {
      // Inline-object values decode through their synthesized class.
      decodeExpr = '$valueDart.fromJson(v as Map<String, dynamic>)';
    } else if (isPrimitive) {
      decodeExpr = 'v as $valueDart';
    } else {
      decodeExpr = 'v as $valueDart';
    }

    b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    b.writeln('    return $name(');
    b.writeln('      value: Map<String, $valueType>.from(');
    b.writeln('        json.map((k, v) => MapEntry(k, $decodeExpr)),');
    b.writeln('      ),');
    b.writeln('    );');
    b.writeln('  }');
    b.writeln();

    b.writeln('  final Map<String, $valueType> value;');
    b.writeln();
    if (implementsClass != null) {
      b.writeln('  @override');
    }
    b.writeln('  Map<String, dynamic> toJson() {');
    if (isPrimitive) {
      b.writeln('    return Map<String, dynamic>.from(value);');
    } else if (ap[r'$ref'] is String || isInlineObjectValue) {
      b.writeln(
        '    return value.map((k, v) => MapEntry(k, v.toJson()));',
      );
    } else {
      b.writeln('    return Map<String, dynamic>.from(value);');
    }
    b.writeln('  }');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      identical(this, other) ||');
    b.writeln('      (other is $name &&');
    b.writeln('          const DeepCollectionEquality().equals(other.value, value));');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => const DeepCollectionEquality().hash(value);');
    b.writeln('}');
    return b.toString();
  }

  /// Emit a class for a free-form object schema (no `properties`, no
  /// explicit `additionalProperties` restriction). The class wraps the
  /// raw `Map<String, dynamic>` so arbitrary JSON keys are preserved on
  /// round-trip (e.g. `JSONSchema`).
  String _emitFreeformMapWrapper() {
    final b = StringBuffer();
    _usesImmutable = true;
    _usesDeepEquality = true;
    b.writeln('@immutable');
    b.writeln(implementsClass != null ? 'class $name implements $implementsClass {' : 'class $name {');
    b.writeln('  const $name({required this.json});');
    b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    b.writeln('    return $name(json: json);');
    b.writeln('  }');
    if (implementsClass != null) {
      b.writeln('  @override');
    }
    b.writeln('  Map<String, dynamic> toJson() => json;');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  bool operator ==(Object other) =>');
    b.writeln('      identical(this, other) ||');
    b.writeln('      (other is $name &&');
    b.writeln('          const DeepCollectionEquality().equals(other.json, json));');
    b.writeln();
    b.writeln('  @override');
    b.writeln('  int get hashCode => const DeepCollectionEquality().hash(json);');
    b.writeln();
    b.writeln('  final Map<String, dynamic> json;');
    b.writeln('}');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Field encoders / decoders
  // -------------------------------------------------------------------------

  /// Core inline type emitter. [context] is the class name an inline
  /// `type: object` schema with `properties` would be synthesized under
  /// (e.g. `SessionTime` for `Session.time`); computing such a type
  /// registers the synthesized class as a side effect. Nested contexts
  /// derive deterministically: array items append `Item`, map values
  /// append `Value`.
  String _dartTypeForInline(Map<String, dynamic> sch, {required String context}) {
    final r = sch[r'$ref'];
    if (r is String) {
      return _pascalFromSnake(_schemaNameFromRef(r));
    }
    final type = sch['type'];
    final format = sch['format'];
    if (type == 'string') {
      if (format == 'date-time') return 'DateTime';
      if (format == 'uri' || format == 'url') return 'Uri';
      final enumVals = sch['enum'];
      if (enumVals is List && enumVals.length > 1) {
        // Multi-value inline enum → a real Dart enum named after the
        // field context (e.g. `Command.source` -> `CommandSource`), so
        // consumers switch on enum members instead of magic strings.
        _registerInlineEnum(className: context, values: enumVals.map(readString).toList());
        return context;
      }
      // Plain string, or a single-value enum (a constant/discriminator,
      // already hidden as a literal on union variants) — use String.
      return 'String';
    }
    if (type == 'integer') return 'int';
    if (type == 'number') return 'double';
    if (type == 'boolean') return 'bool';
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        return 'List<${_dartTypeForInline(items, context: '${context}Item')}>';
      }
      return 'List<dynamic>';
    }
    if (type == 'object') {
      // Inline object with properties: synthesize a typed sibling class
      // instead of collapsing to `Map<String, dynamic>` — collapsing
      // would make generated models WEAKER typed than the hand-written
      // v1 models they are meant to replace.
      final props = sch['properties'];
      if (props is Map<String, dynamic> && props.isNotEmpty) {
        _registerInlineObject(className: context, sch: sch);
        return context;
      }
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return 'Map<String, ${_dartTypeForInline(ap, context: '${context}Value')}>';
      }
      if (ap == true) return 'Map<String, dynamic>';
      return 'Map<String, dynamic>';
    }
    final anyOf = sch['anyOf'];
    if (anyOf is List) {
      final variants = anyOf.map(readObject).toList();
      // null + T -> T?
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeForInline(nonNull.first, context: context);
      }
      return 'Object';
    }
    final enumValues = sch['enum'];
    if (enumValues is List) {
      // Inline enum — register for emission.
      final values = enumValues.map(readString).toList();
      final key = values.join('|');
      if (!_emittedEnumKeys.contains(key)) {
        _emittedEnumKeys.add(key);
        final className = _inlineEnumName(values);
        _inlineEnums.add(InlineEnum(className: className, values: values));
      }
      return _inlineEnumName(values);
    }
    return 'Object';
  }

  String _inlineEnumName(List<String> values) {
    // Stable name based on values, ensures uniqueness within file.
    return values.map(_pascalFromSnake).join('Or');
  }

  /// True if the schema explicitly allows `null` as a value. Detects
  /// `anyOf: [..., {type: null}]` and `oneOf: [..., {type: null}]`.
  bool _isNullableSchema(Map<String, dynamic> sch) {
    for (final key in ['anyOf', 'oneOf']) {
      final v = sch[key];
      if (v is List) {
        for (final item in v) {
          if (item is Map && item['type'] == 'null') return true;
        }
      }
    }
    return false;
  }

  /// True if [refName] resolves to a schema that is a union of multiple
  /// non-null variants (anyOf/oneOf with at least two non-`type:null`
  /// entries). The generated factory for a union takes `dynamic` because
  /// it dispatches on JSON shape (string vs map vs containsKey), so the
  /// call site must NOT pre-cast the value to `Map<String, dynamic>`.
  bool _isUnionRef(String refName) {
    final refSchema = readObjectOrNull(schemas[refName]);
    if (refSchema == null) return false;
    for (final key in ['anyOf', 'oneOf']) {
      final v = refSchema[key];
      if (v is List) {
        final nonNull = v.where((e) => e is Map && e['type'] != 'null').length;
        if (nonNull >= 2) return true;
      }
    }
    return false;
  }

  String _decodeField({
    required String name,
    required Map<String, dynamic> sch,
    required bool isNullable,
    required String context,
  }) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    // No `?? <fallback>` defaults: a non-nullable field reads
    // `json[key] as T` and throws if the server violates the contract by
    // omitting it; a nullable field reads `json[key] as T?` (null when
    // absent). Coercing a missing value into `''`/`0`/`{}` hides bugs.
    final jsonValue = 'json[$keyExpr]';
    final r = sch[r'$ref'];
    if (r is String) {
      final refName = _schemaNameFromRef(r);
      final refType = _pascalFromSnake(refName);
      // Look up the referenced schema to determine its shape (object, array,
      // or string enum).
      final refSchema = readObjectOrNull(schemas[refName]);
      final isRefArray = refSchema != null && refSchema['type'] == 'array';
      final isRefStringEnum = refSchema != null && refSchema['type'] == 'string' && refSchema['enum'] is List;
      if (isRefArray) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as List<dynamic>)';
        }
        return '$safeName: $refType.fromJson($jsonValue as List<dynamic>)';
      }
      if (isRefStringEnum) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as String)';
        }
        return '$safeName: $refType.fromJson($jsonValue as String)';
      }
      // Union refs (PermissionConfig, PermissionRuleConfig, etc.) generate a
      // factory that takes `dynamic` and dispatches on JSON shape. Forcing
      // a `as Map<String, dynamic>` cast at the call site breaks the string
      // shorthand branch and causes the union to never match. Pass the raw
      // value through instead.
      if (_isUnionRef(refName)) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as Object)';
        }
        return '$safeName: $refType.fromJson($jsonValue as Object)';
      }
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as Map<String, dynamic>)';
      }
      return '$safeName: $refType.fromJson($jsonValue as Map<String, dynamic>)';
    }
    // anyOf [T, null] → T? (and T? in any case since one branch is null)
    final anyOf = sch['anyOf'];
    if (anyOf is List) {
      final variants = anyOf.map(readObject).toList();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _decodeField(name: name, sch: nonNull.first, isNullable: isNullable, context: context);
      }
    }
    final type = sch['type'];
    if (type == 'string' && sch['format'] == 'date-time') {
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : DateTime.parse(json[$keyExpr] as String)';
      }
      return '$safeName: DateTime.parse($jsonValue as String)';
    }
    if (type == 'string' && (sch['format'] == 'uri' || sch['format'] == 'url')) {
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : Uri.parse(json[$keyExpr] as String)';
      }
      return '$safeName: Uri.parse($jsonValue as String)';
    }
    final enumValues = sch['enum'];
    if (type == 'string' && enumValues is List) {
      final enumVals = enumValues.map(readString).toList();
      if (enumVals.length > 1) {
        // Multi-value inline enum → generated Dart enum named after the
        // field context (e.g. `CommandSource`). `fromJson` maps values
        // introduced by newer servers to the enum's `unknown` member.
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $context.fromJson(json[$keyExpr] as String)';
        }
        return '$safeName: $context.fromJson($jsonValue as String)';
      }
      // Single-value enum (a constant/discriminator) stays a plain String.
      if (isNullable) {
        return '$safeName: json[$keyExpr] as String?';
      }
      return '$safeName: $jsonValue as String';
    }
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        final itemsRef = items[r'$ref'];
        if (itemsRef is String) {
          final refName = _schemaNameFromRef(itemsRef);
          final refType = _pascalFromSnake(refName);
          // If the items $ref points to a top-level array schema, the
          // element cast must be `as List<dynamic>` not `as Map<String, dynamic>`.
          final refSchema = readObjectOrNull(schemas[refName]);
          final elementCast = (refSchema != null && refSchema['type'] == 'array')
              ? 'List<dynamic>'
              : 'Map<String, dynamic>';
          if (isNullable) {
            return '$safeName: (json[$keyExpr] as List<dynamic>?)?.map((e) => $refType.fromJson(e as $elementCast)).toList()';
          }
          return '$safeName: ($jsonValue as List<dynamic>).map((e) => $refType.fromJson(e as $elementCast)).toList()';
        }
        // Inline-object items decode through their synthesized class.
        final itemProps = items['properties'];
        if (items['type'] == 'object' && itemProps is Map && itemProps.isNotEmpty) {
          final itemClass = '${context}Item';
          if (isNullable) {
            return '$safeName: (json[$keyExpr] as List<dynamic>?)?.map((e) => $itemClass.fromJson(e as Map<String, dynamic>)).toList()';
          }
          return '$safeName: ($jsonValue as List<dynamic>).map((e) => $itemClass.fromJson(e as Map<String, dynamic>)).toList()';
        }
        final innerDart = _dartTypeForInline(items, context: '${context}Item');
        if (isNullable) {
          return '$safeName: (json[$keyExpr] as List<dynamic>?)?.cast<$innerDart>()';
        }
        return '$safeName: ($jsonValue as List<dynamic>).cast<$innerDart>()';
      }
    }
    if (type == 'object') {
      // Inline object with properties: decode through the synthesized
      // sibling class instead of exposing the raw map.
      final props = sch['properties'];
      if (props is Map && props.isNotEmpty) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $context.fromJson(json[$keyExpr] as Map<String, dynamic>)';
        }
        return '$safeName: $context.fromJson($jsonValue as Map<String, dynamic>)';
      }
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        final valueDart = _dartTypeForInline(ap, context: '${context}Value');
        // If the value is a $ref to a top-level schema, the decoding shape
        // depends on whether the ref points to an array wrapper (values
        // decoded via `List.fromJson`) or an object class (values decoded
        // via `Class.fromJson`). Inline schemas (no $ref) use a plain cast.
        final ref = ap[r'$ref'];
        if (ref is String) {
          final refName = _schemaNameFromRef(ref);
          final refSchema = readObjectOrNull(schemas[refName]);
          if (refSchema != null && refSchema['type'] == 'array') {
            if (isNullable) {
              return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, $valueDart.fromJson(v as List<dynamic>)))";
            }
            return "$safeName: ($jsonValue as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v as List<dynamic>)))";
          }
          // Object ref: use `RefType.fromJson(v)` so the JSON map is
          // decoded through the model's factory instead of being
          // mis-cast as a Dart class instance. Union refs must NOT be
          // pre-cast to Map because their factory takes Object and has a
          // string-shorthand branch; cast to Object instead.
          final vCast = _isUnionRef(refName) ? ' as Object' : ' as Map<String, dynamic>';
          if (isNullable) {
            return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, $valueDart.fromJson(v$vCast)))";
          }
          return "$safeName: ($jsonValue as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v$vCast)))";
        }
        // Inline-object map values decode through their synthesized class.
        final apProps = ap['properties'];
        if (ap['type'] == 'object' && apProps is Map && apProps.isNotEmpty) {
          if (isNullable) {
            return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, $valueDart.fromJson(v as Map<String, dynamic>)))";
          }
          return "$safeName: ($jsonValue as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v as Map<String, dynamic>)))";
        }
        if (isNullable) {
          return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as $valueDart))";
        }
        return "$safeName: ($jsonValue as Map<String, dynamic>).map((k, v) => MapEntry(k, v as $valueDart))";
      }
      if (isNullable) {
        return "$safeName: json[$keyExpr] as Map<String, dynamic>?";
      }
      return "$safeName: $jsonValue as Map<String, dynamic>";
    }
    if (type == 'number') {
      // OpenAPI `number` is JSON `num`. Servers may send either an int or
      // a double for the same field, so accept both and normalize via
      // `toDouble()` rather than crashing on `as double?`.
      if (isNullable) {
        return '$safeName: (json[$keyExpr] as num?)?.toDouble()';
      }
      return '$safeName: ($jsonValue as num).toDouble()';
    }
    if (type == 'integer') {
      // jsonDecode may parse `5.0` as a double even when the schema
      // declares the field as integer, so normalise via `toInt()`.
      if (isNullable) {
        return '$safeName: (json[$keyExpr] as num?)?.toInt()';
      }
      return '$safeName: ($jsonValue as num).toInt()';
    }
    if (type == 'boolean' || type == 'string') {
      final dartType = _dartTypeForInline(sch, context: context);
      if (context == 'CommandTemplate') {
        // `Command.template` is documented as a string but some servers
        // send a non-string shape. Fall back to `null` (the field is
        // nullable) rather than a misleading empty string.
        return "$safeName: json[$keyExpr] is String ? json[$keyExpr] as String : null";
      }
      if (isNullable) {
        return '$safeName: json[$keyExpr] as $dartType?';
      }
      return '$safeName: $jsonValue as $dartType';
    }
    final fallbackDartType = _dartTypeForInline(sch, context: context);
    if (fallbackDartType == 'Object') {
      if (isNullable) {
        return '$safeName: json[$keyExpr] as Object?';
      }
      return '$safeName: $jsonValue as Object';
    }
    return '$safeName: json[$keyExpr]';
  }

  String _encodeField({
    required String name,
    required Map<String, dynamic> sch,
    required bool isNullable,
    required bool omitWhenNull,
    required String context,
  }) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final callOp = isNullable ? '?' : '';
    final entryOp = omitWhenNull ? '?' : '';
    // anyOf [T, null] → T? — delegate to the non-null branch.
    final anyOf = sch['anyOf'];
    if (anyOf is List) {
      final variants = anyOf.map(readObject).toList();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _encodeField(
          name: name,
          sch: nonNull.first,
          isNullable: isNullable,
          omitWhenNull: omitWhenNull,
          context: context,
        );
      }
    }
    final r = sch[r'$ref'];
    if (r is String) {
      return '$keyExpr: $entryOp$safeName$callOp.toJson()';
    }
    final type = sch['type'];
    if (type == 'string' && sch['format'] == 'date-time') {
      return '$keyExpr: $entryOp$safeName$callOp.toIso8601String()';
    }
    if (type == 'string' && (sch['format'] == 'uri' || sch['format'] == 'url')) {
      return '$keyExpr: $entryOp$safeName$callOp.toString()';
    }
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        final itemProps = items['properties'];
        final isModelItem =
            items[r'$ref'] is String || (items['type'] == 'object' && itemProps is Map && itemProps.isNotEmpty);
        if (isModelItem) {
          // List of generated model objects ($ref or synthesized
          // inline class). `jsonEncode` cannot encode Dart class
          // instances directly — map each element through its
          // `toJson()` so the encoder sees plain maps.
          return '$keyExpr: $entryOp$safeName$callOp.map((e) => e.toJson()).toList()';
        }
      }
    }
    if (type == 'object') {
      // Inline object with properties: encode through the synthesized
      // class's toJson.
      final props = sch['properties'];
      if (props is Map && props.isNotEmpty) {
        return '$keyExpr: $entryOp$safeName$callOp.toJson()';
      }
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        final apProps = ap['properties'];
        final isModelValue = ap[r'$ref'] is String || (ap['type'] == 'object' && apProps is Map && apProps.isNotEmpty);
        if (isModelValue) {
          // Map of generated model objects. Same constraint as
          // arrays: jsonEncode needs plain maps, not model instances.
          return '$keyExpr: $entryOp$safeName$callOp.map((k, v) => MapEntry(k, v.toJson()))';
        }
      }
    }
    final enumValues = sch['enum'];
    if (type == 'string' && enumValues is List && enumValues.length > 1) {
      // Multi-value inline enum is a generated Dart enum — encode via its
      // `toJson()` (which returns the wire string).
      return '$keyExpr: $entryOp$safeName$callOp.toJson()';
    }
    // Plain strings and single-value enum constants use the raw value.
    return '$keyExpr: $entryOp$safeName';
  }

  // -------------------------------------------------------------------------
  // Discriminator detection
  // -------------------------------------------------------------------------

  String? _findDiscriminator(List<Map<String, dynamic>> variants) {
    // Inspect every variant — both $ref and inline. A discriminator is
    // a string property that (1) every variant declares as a single-
    // value enum, (2) every variant marks as required, and (3) takes a
    // distinct value per variant. We do not restrict ourselves to the
    // conventional `type`/`role`/`kind`/`status` names: any common
    // single-value enum works (e.g. `MCPStatus` uses `status`,
    // `SessionStatus` uses `type`). A $ref variant that is itself a union
    // contributes its leaf variants; they must share one value.
    final resolved = <Map<String, dynamic>>[];
    for (final v in variants) {
      final r = v[r'$ref'];
      if (r is String) {
        resolved.addAll(_unionLeafSchemas(_schemaNameFromRef(r)));
      } else if (v['type'] == 'object') {
        resolved.add(v);
      }
    }
    if (resolved.length < 2) return null;

    // Collect candidate property names that are present in every
    // variant and are single-value enums. Then filter to those that
    // are also marked as required everywhere.
    final allProps = <String>{};
    for (final sch in resolved) {
      final props = readObjectOrNull(sch['properties']);
      if (props == null) return null;
      for (final MapEntry(:key, :value) in props.entries) {
        if (readObjectOrNull(value) case {'enum': List(length: 1)}) allProps.add(key);
      }
    }
    for (final candidate in allProps) {
      var allRequired = true;
      for (final sch in resolved) {
        final required = (readListOrNull(sch['required']) ?? const []).map(readString).toList();
        if (!required.contains(candidate)) {
          allRequired = false;
          break;
        }
      }
      if (allRequired && _hasDistinctValues(variants: variants, discName: candidate)) return candidate;
    }
    return null;
  }

  bool _hasDistinctValues({required List<Map<String, dynamic>> variants, required String discName}) {
    final seen = <String>{};
    for (final v in variants) {
      final r = v[r'$ref'];
      final value = r is String
          ? _discriminatorValue(variantName: _schemaNameFromRef(r), discName: discName)
          : _inlineDiscriminatorValue(variant: v, discName: discName);
      if (value == null || !seen.add(value)) return false;
    }
    return true;
  }

  /// The object schemas behind [schemaName]: the schema itself, or the
  /// leaves of a union of $refs (recursively).
  List<Map<String, dynamic>> _unionLeafSchemas(String schemaName) {
    final schema = readObjectOrNull(schemas[schemaName]);
    if (schema == null) return const [];
    final variants = schema['anyOf'] ?? schema['oneOf'];
    if (variants is! List) return [schema];
    return [
      for (final v in variants.map(readObject).toList())
        if (readStringOrNull(v[r'$ref']) case final ref?) ..._unionLeafSchemas(_schemaNameFromRef(ref)) else v,
    ];
  }

  String? _discriminatorValue({required String variantName, required String discName}) {
    final schema = readObjectOrNull(schemas[variantName]);
    if (schema == null) return null;
    if (schema['anyOf'] is List || schema['oneOf'] is List) {
      // A nested union dispatches as one variant when all its leaves
      // share the same discriminator value.
      final values = {
        for (final leaf in _unionLeafSchemas(variantName)) _inlineDiscriminatorValue(variant: leaf, discName: discName),
      };
      return values.length == 1 ? values.first : null;
    }
    return _inlineDiscriminatorValue(variant: schema, discName: discName);
  }

  /// Returns the discriminator value declared by [variant]'s own
  /// properties: an INLINE variant (one declared directly in the union's
  /// anyOf/oneOf, not via $ref), or a resolved $ref variant's schema.
  String? _inlineDiscriminatorValue({required Map<String, dynamic> variant, required String discName}) {
    final property = readObjectOrNull(readObjectOrNull(variant['properties'])?[discName]);
    final values = readListOrNull(property?['enum']);
    if (values == null || values.isEmpty) return null;
    return readString(values.first);
  }

  /// Build a runtime type guard for a union variant. Returns a string
  /// expression suitable for use in `if (...)`.
  String? _unionTypeGuard(Map<String, dynamic> variant) {
    final r = variant[r'$ref'];
    if (r is String) {
      final vName = _schemaNameFromRef(r);
      final sch = readObjectOrNull(schemas[vName]);
      if (sch == null) return null;
      final t = sch['type'];
      if (t == 'string') return 'json is String';
      if (t == 'array') return 'json is List';
      return 'json is Map';
    }
    final t = variant['type'];
    if (t == 'string') return 'json is String';
    if (t == 'array') return 'json is List';
    if (t == 'object') {
      // Tighten the guard with a `containsKey` so Dart flow analysis
      // narrows `json` to `Map<String, dynamic>` for the decode call
      // below. Without the explicit `is Map<String, dynamic>`, the
      // analyzer can't promote from a plain `is Map`.
      final required = (readListOrNull(variant['required']) ?? const []).map(readString).toList();
      final properties = readObjectOrNull(variant['properties']);
      for (final field in required) {
        if (readObjectOrNull(properties?[field]) case {'enum': [final value]}) {
          return 'json is Map<String, dynamic> && json[${jsonEncode(field)}] == ${jsonEncode(value)}';
        }
      }
      if (required.isNotEmpty) {
        return "json is Map<String, dynamic> && json.containsKey(${jsonEncode(required.first)})";
      }
      return 'json is Map<String, dynamic>';
    }
    return 'json is Map';
  }

  /// Build a decode expression for a union variant. Pairs with
  /// [_unionTypeGuard]. Returns a string expression that returns the
  /// decoded variant. The expression may reference a synthesized
  /// class name (e.g. `Name00Inline`) for inline object variants.
  String? _unionTypeDecode({required Map<String, dynamic> variant, required int inlineIndex}) {
    final r = variant[r'$ref'];
    if (r is String) {
      final vName = _schemaNameFromRef(r);
      final refType = _pascalFromSnake(vName);
      final sch = readObjectOrNull(schemas[vName]);
      if (sch == null) return null;
      final t = sch['type'];
      final inlineName = '$name${inlineIndex.toString().padLeft(2, '0')}Inline';
      if (t == 'string' && sch['enum'] is List) {
        // Enum ref variant: dispatch into the synthesized wrapper
        // class so the union interface has a non-enum
        // implementation.
        return '$inlineName.fromJson(json)';
      }
      if (t == 'array') return '$refType.fromJson(json as List<dynamic>)';
      return '$refType.fromJson(json as Map<String, dynamic>)';
    }
    final t = variant['type'];
    final inlineName = '$name${inlineIndex.toString().padLeft(2, '0')}Inline';
    if (t == 'string') {
      return '$inlineName.fromJson(json)';
    }
    if (t == 'array') {
      return '$inlineName.fromJson(json as List<dynamic>)';
    }
    if (t == 'object') {
      // After `json is Map<String, dynamic> && json.containsKey(...)`
      // json is already promoted to `Map<String, dynamic>`.
      return '$inlineName.fromJson(json)';
    }
    return null;
  }
}

/// A lightweight record for a union's synthesized inline variant
/// class. The actual class body is emitted by
/// [ModelWriter._emitInlineVariantClass] so it can reuse the
/// schema-reading helpers.
class _InlineVariantClassEntry({
  required final String className,
  required final Map<String, dynamic> schema,
});

/// A class synthesized for an inline `type: object` property schema
/// (e.g. `Session.time` → `SessionTime`). Emitted as a sibling of the
/// owning class by [ModelWriter.emit].
class _InlineObjectEntry({
  required final String className,
  required final Map<String, dynamic> schema,
});

/// Everything the object-class emitter needs to know about one field,
/// computed once so the constructor, fromJson, toJson, `==`, hashCode,
/// and field declaration all agree.
class _FieldRecord({
  /// JSON object key as it appears in the spec.
  required final String jsonName,

  /// Dart-safe identifier for the field.
  required final String safeName,

  /// The field's property schema.
  required final Map<String, dynamic> schema,

  /// Whether the spec lists the field in `required`.
  required final bool isRequired,

  /// Final Dart type INCLUDING nullability marker.
  required final String dartType,

  /// Synthesized-class name context for inline objects under this field.
  required final String context,
}) {
  /// Whether the Dart field type is nullable (`dartType` ends with `?`).
  /// This is the single source of truth fromJson/toJson decode use, so
  /// the field declaration and the (de)serialization always agree.
  bool get isNullable => dartType.endsWith('?');
}

/// An enum class synthesized for an inline enum in a property.
class InlineEnum({required final String className, required final List<String> values}) {
  String emit() => _emitEnumBody(enumName: className, values: values);
}

/// Emits a complete enum declaration named [enumName] for the spec
/// [values]. Every generated enum gains an `unknown` fallback member
/// (unless the spec itself already defines one): `fromJson` returns it
/// for values introduced by newer OpenCode servers instead of throwing,
/// and `toJson` encodes the synthetic member as the literal string
/// `unknown` — mirroring the hand-written `CommandSource.unknown`
/// convention already used in this package.
String _emitEnumBody({required String enumName, required List<String> values}) {
  final memberNames = values.map(_camelFromSnake).toList();
  final hasNativeUnknown = memberNames.contains('unknown');
  final b = StringBuffer();
  b.writeln('enum $enumName {');
  for (var i = 0; i < values.length; i++) {
    b.writeln('  @JsonValue(${jsonEncode(values[i])})');
    b.writeln('  ${memberNames[i]},');
  }
  if (!hasNativeUnknown) {
    b.writeln();
    b.writeln('  /// Fallback for values introduced by newer OpenCode servers.');
    b.writeln('  /// Encodes back to the literal string `unknown`.');
    b.writeln('  unknown,');
  }
  b.writeln('  ;');
  b.writeln();
  b.writeln('  static $enumName fromJson(String value) {');
  b.writeln('    switch (value) {');
  for (var i = 0; i < values.length; i++) {
    b.writeln('      case ${jsonEncode(values[i])}:');
    b.writeln('        return $enumName.${memberNames[i]};');
  }
  b.writeln('      default:');
  b.writeln('        return $enumName.unknown;');
  b.writeln('    }');
  b.writeln('  }');
  b.writeln();
  b.writeln('  String toJson() {');
  b.writeln('    switch (this) {');
  for (var i = 0; i < values.length; i++) {
    b.writeln('      case $enumName.${memberNames[i]}:');
    b.writeln('        return ${jsonEncode(values[i])};');
  }
  if (!hasNativeUnknown) {
    b.writeln('      case $enumName.unknown:');
    b.writeln("        return 'unknown';");
  }
  b.writeln('    }');
  b.writeln('  }');
  b.writeln('}');
  return b.toString();
}

// ---------------------------------------------------------------------------
// Naming utilities
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Spec normalization (runs before generation)
// ---------------------------------------------------------------------------

/// Moves inline schemas named by the surface's `hoistSchemas` into
/// `components/schemas` and replaces them with a `$ref`, so inline unions
/// become named, dispatchable union classes. Each location is
/// `<SchemaName>#<json pointer>` (e.g. `Foo#/properties/bar/items`).
void _hoistInlineSchemas({required Map<String, dynamic> schemas, required Map<String, String> hoists}) {
  for (final MapEntry(key: name, value: location) in hoists.entries) {
    final [schemaName, pointer] = location.split('#');
    final segments = pointer.split('/').where((s) => s.isNotEmpty).toList();
    Object? parent = schemas[schemaName];
    for (final segment in segments.take(segments.length - 1)) {
      parent = parent is Map ? parent[segment] : null;
    }
    final last = segments.last;
    final inline = parent is Map ? parent[last] : null;
    if (parent is! Map || inline is! Map<String, dynamic>) {
      stderr.writeln('error: hoistSchemas location $location does not name an inline schema');
      exit(1);
    }
    schemas[name] = inline;
    parent[last] = <String, dynamic>{r'$ref': '#/components/schemas/$name'};
  }
}

/// Replaces `$ref`s to named primitive schemas (e.g. `Money.USD` =
/// `{"type": "number"}`) with a copy of the primitive, so fields decode as
/// Dart primitives instead of referencing a class that cannot exist. An opaque
/// "any non-null JSON" schema (`{"not": {"type": "null"}}`) is inlined too and
/// decodes as `Object`.
void _inlinePrimitiveRefs({required Map<String, dynamic> spec, required Map<String, dynamic> schemas}) {
  bool isPrimitive(Map<dynamic, dynamic> schema) {
    final not = schema['not'];
    return (const {'string', 'number', 'integer', 'boolean'}.contains(schema['type']) && schema['enum'] == null) ||
        (schema.length == 1 && not is Map && not['type'] == 'null');
  }

  void walk(Object? node) {
    if (node is Map<String, dynamic>) {
      final ref = node[r'$ref'];
      if (ref is String && ref.startsWith('#/components/schemas/')) {
        final target = schemas[ref.substring('#/components/schemas/'.length)];
        if (target is Map && isPrimitive(target)) {
          node
            ..remove(r'$ref')
            ..addAll(Map<String, dynamic>.from(target));
        }
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(spec);
}

/// Collapses an `anyOf`/`oneOf` whose variants are all inline strings and
/// which accepts any string (known values plus a free-form fallback) into
/// a plain string schema.
void _collapseOpenStringUnions(Object? node) {
  if (node is Map<String, dynamic>) {
    for (final key in const ['anyOf', 'oneOf']) {
      final variants = node[key];
      if (variants is List &&
          variants.isNotEmpty &&
          variants.every((v) => v is Map && v[r'$ref'] == null && v['type'] == 'string') &&
          variants.any((v) => v is Map && v['enum'] == null)) {
        node
          ..remove(key)
          ..['type'] = 'string';
      }
    }
    node.values.forEach(_collapseOpenStringUnions);
  } else if (node is List) {
    node.forEach(_collapseOpenStringUnions);
  }
}

/// Dotted spec schema names whose Pascal form collides with another schema's.
/// Set once from the spec before generation starts.
var _collidingDottedNames = <String>{};

Set<String> _findCollidingDottedNames(Iterable<String> schemaNames) {
  final namesByPascal = <String, List<String>>{};
  for (final name in schemaNames) {
    namesByPascal.putIfAbsent(_pascalBase(name), () => []).add(name);
  }
  return {
    for (final names in namesByPascal.values)
      if (names.length > 1) ...names.where((name) => name.contains('.')),
  };
}

String _pascalBase(String name) {
  // Strip Effect schema prefix and leading underscores/dots.
  var s = name;
  if (s.startsWith('effect_')) {
    s = s.substring('effect_'.length);
  }
  s = s.replaceAll(RegExp('^[._]+'), '');
  return _pascalCore(s);
}

String _pascalFromSnake(String name) {
  final pascal = _pascalBase(name);
  // A dotted SCHEMA name collapses into the same identifier as a sibling
  // that uses an underscore or no separator (e.g. `Event.tui.command.execute`
  // vs `EventTuiCommandExecute`). Append a short stable hash of the raw name
  // so both siblings stay distinct without leaking the original dots into
  // identifiers (Dart identifiers may not contain `.`).
  if (_collidingDottedNames.contains(name)) {
    return '$pascal${_hashSuffix(name)}';
  }
  return pascal;
}

/// Pascal-cases [s] by splitting on underscores, dashes, and dots —
/// WITHOUT the dotted-name hash suffix that [_pascalFromSnake] appends.
/// Used where the input space is known to be collision-free, such as
/// synthesized nested-class names (always parent-prefixed).
String _pascalCore(String s) {
  final parts = s.split(RegExp(r'[_\-.]+'));
  final out = StringBuffer();
  for (final p in parts) {
    if (p.isEmpty) continue;
    if (_isAllUpper(p)) {
      out.write(p);
    } else {
      // CamelCase split: insert boundary before each uppercase.
      final split = p.split(RegExp('(?=[A-Z])'));
      out.write(split.map((seg) => seg.isEmpty ? '' : seg[0].toUpperCase() + seg.substring(1)).join());
    }
  }
  return out.toString();
}

/// 4-character hash suffix derived from a string, base-36 encoded.
/// Used purely for disambiguating PascalCase collisions caused by raw
/// schema names whose separators (e.g. `.`) are stripped by
/// `_pascalFromSnake`.
String _hashSuffix(String input) {
  // FNV-1a 32-bit; stable, no extra deps, good enough for collision
  // avoidance across a few hundred names.
  var h = 0x811c9dc5;
  final bytes = utf8.encode(input);
  for (final b in bytes) {
    h ^= b;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(36).padLeft(7, '0');
}

/// Whether [schema] is a string enum schema.
bool _isEnum(Object? schema) => schema is Map && schema['enum'] is List && schema['type'] == 'string';

bool _isAllUpper(String s) {
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0x41 || c > 0x5A) return false;
  }
  return s.isNotEmpty;
}

String _camelFromSnake(String name) {
  final pascal = _pascalFromSnake(name);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}

String _snakeFromCamel(String name) {
  final withUnderscores = name.replaceAllMapped(
    RegExp('([a-z0-9])([A-Z])'),
    (m) {
      final g2 = m.group(2) ?? '';
      return '${m.group(1)}_${g2.toLowerCase()}';
    },
  );
  return withUnderscores.replaceAll('-', '_').replaceAll('.', '_').toLowerCase();
}

const _dartReservedWords = {
  // True reserved words — never usable as identifiers.
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  // Contextual keywords that can break in the positions generated code
  // uses them (member declarations, async method bodies). Built-in
  // identifiers that are unambiguous in those positions (e.g. `part`,
  // `required`, `when`, `dynamic`) are deliberately NOT escaped — they
  // are legal field/parameter names.
  'await', 'yield', 'get', 'set', 'operator', 'factory',
  // Names that collide with members the generated classes declare, or
  // that shadow dart:core identifiers the class bodies reference as
  // annotations (a field named `override` shadows `@override`).
  'override', 'hashCode', 'runtimeType', 'toString', 'noSuchMethod',
  'toJson',
};

/// Returns a Dart-safe identifier for the JSON key [name]: reserved
/// words gain a `Value` suffix (backticks are NOT valid Dart), and
/// leading dollar signs / underscores are stripped (they cause parse
/// errors in named constructor parameters). The JSON wire key is
/// unaffected — `_safeKey` always emits the original name.
String _safeIdentifier(String name) {
  // Convert snake_case JSON keys to lowerCamelCase to match Dart identifier
  // convention. This keeps the generated code free of the
  // `non_constant_identifier_names` lint, mirroring the convention used in
  // the hand-written `lib/src/models/` models (e.g. `sessionID`, `parentID`).
  var s = _camelFromSnake(name);
  // Strip leading dollar signs and underscores — they cause parse errors in
  // named constructor parameters.
  while (s.startsWith(r'$') || s.startsWith('_')) {
    s = s.substring(1);
  }
  if (s.isEmpty) s = 'value';
  if (_dartReservedWords.contains(s)) {
    return '${s}Value';
  }
  return s;
}

/// Returns a Dart string literal for a JSON object key.
///
/// Uses a raw string (`r"..."`) only when the key contains a `$` (to avoid
/// the generated site interpreting it as string interpolation). Otherwise a
/// plain double-quoted string is emitted, which keeps the
/// `unnecessary_raw_strings` lint clean across the 332 generated model files.
String _safeKey(String name) {
  if (name.contains(r'$')) {
    return "r${jsonEncode(name)}";
  }
  return jsonEncode(name);
}
