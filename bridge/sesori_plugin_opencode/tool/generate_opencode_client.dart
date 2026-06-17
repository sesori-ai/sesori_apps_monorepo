// GENERATED FILE - DO NOT EDIT BY HAND
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
// Exactly one of --tag, --branch, --commit, or --local is required. There
// is no default: this script will not guess what you meant.
//
// This script consumes an OpenAPI 3.1 JSON document (OpenCode's
// `packages/sdk/openapi.json`) and emits, relative to outDir:
//   - opencode_client.dart                 — public API client class (Layer 1, only with --with-client)
//   - models/openapi/<SchemaName>.g.dart   — one file per included top-level schema (Layer 0)
//
// Models live under `models/openapi/` to avoid filename collisions with the
// hand-written v1 models already in `models/` (e.g. session.dart, message.dart).
// Layer-mirror rule (bridge/AGENTS.md): directory structure mirrors layers.
//
// Generated code uses package:http directly (no codegen runtime),
// immutable classes with hand-written fromJson/toJson (no freezed/json_serializable),
// and Dart 3 sealed classes for unions.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const _upstreamOwner = 'anomalyco';
const _upstreamRepo = 'opencode';
const _specPathInRepo = 'packages/sdk/openapi.json';

/// Resolved upstream ref description passed to the codegen. Exactly one
/// of [tag], [branch], [commit] is non-null. [commitSha] is the 40-char
/// hex commit SHA the ref points at (always populated when [kind] is set).
class SourceRef {
  SourceRef({required this.kind, required this.value, required this.commitSha});

  /// One of 'tag', 'branch', 'commit'.
  final String kind;

  /// The user-supplied ref string (`v1.16.2`, `dev`, or a 40-char SHA).
  final String value;

  /// The 40-char hex commit SHA the ref resolves to. Pre-resolved at
  /// startup via `git ls-remote` so generation is fully offline after
  /// the initial fetch.
  final String commitSha;

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
  var verbose = false;
  var withClient = false;

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
      case '--verbose':
      case '-v':
        verbose = true;
      case '--with-client':
        withClient = true;
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

  // Exactly one of --tag / --branch / --commit / --local is required.
  final sourceCount = [tag, branch, commit, localSpecPath].where((e) => e != null).length;
  if (sourceCount == 0) {
    stderr.writeln('error: one of --tag, --branch, --commit, or --local is required');
    _printUsage();
    exit(2);
  }
  if (sourceCount > 1) {
    stderr.writeln('error: --tag, --branch, --commit, and --local are mutually exclusive');
    _printUsage();
    exit(2);
  }

  String? specPath;
  SourceRef? sourceRef;
  var deleteSpecPathOnExit = false;

  if (tag != null) {
    sourceRef = await _resolveAndFetch(
      kind: 'tag',
      value: tag,
      verbose: verbose,
      onSpecPath: (p) {
        specPath = p;
        deleteSpecPathOnExit = true;
      },
    );
  } else if (branch != null) {
    sourceRef = await _resolveAndFetch(
      kind: 'branch',
      value: branch,
      verbose: verbose,
      onSpecPath: (p) {
        specPath = p;
        deleteSpecPathOnExit = true;
      },
    );
  } else if (commit != null) {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(commit)) {
      stderr.writeln('error: --commit must be a 40-character hex SHA; got "$commit"');
      exit(2);
    }
    sourceRef = SourceRef(kind: 'commit', value: commit, commitSha: commit);
    specPath = await _fetchSpec(
      commit,
      verbose: verbose,
    );
    deleteSpecPathOnExit = true;
  } else {
    specPath = localSpecPath;
  }

  stdout.writeln('Reading OpenAPI spec: $specPath');
  final raw = File(specPath!).readAsStringSync();
  final spec = jsonDecode(raw) as Map<String, dynamic>;

  final gen = Codegen(
    spec: spec,
    outDir: outDir,
    verbose: verbose,
    sourceRef: sourceRef,
    withClient: withClient,
  );
  try {
    await gen.run();
  } finally {
    if (deleteSpecPathOnExit) {
      try {
        File(specPath!).deleteSync();
      } catch (_) {
        /* best-effort cleanup */
      }
    }
  }
  stdout.writeln('Done. Output: $outDir');
}

void _printUsage() {
  stderr.writeln('');
  stderr.writeln(
    'Usage: dart run tool/generate_opencode_client.dart '
    '[--tag <tag> | --branch <branch> | --commit <sha> | --local <path>] '
    '[--out-dir <dir>] [--with-client] [--verbose]',
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
  stderr.writeln('  --with-client       Also generate opencode_client.dart (default: off)');
  stderr.writeln('  --verbose, -v       Print extra progress information');
}

/// Fetch the OpenCode openapi.json from upstream at [ref] (a branch name,
/// tag name, or commit SHA) and return the path to the downloaded temp
/// file. Caller is responsible for deleting the file.
Future<String> _fetchSpec(String ref, {required bool verbose}) async {
  final url = Uri.parse(
    'https://raw.githubusercontent.com/$_upstreamOwner/$_upstreamRepo/'
    '$ref/$_specPathInRepo',
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

/// Resolve [value] (a tag or branch name) to its 40-char commit SHA via
/// `git ls-remote`, then fetch the spec at that commit. The resolved
/// SHA is recorded in every generated file header.
Future<SourceRef> _resolveAndFetch({
  required String kind,
  required String value,
  required bool verbose,
  required void Function(String specPath) onSpecPath,
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
    if (r.stderr is String && (r.stderr as String).isNotEmpty) {
      stderr.writeln(r.stderr);
    }
    exit(1);
  }
  // Output line shape: "<sha>\trefs/<kind>/<ref>"
  String? sha;
  for (final line in (r.stdout as String).split('\n')) {
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
  final specPath = await _fetchSpec(sha, verbose: verbose);
  onSpecPath(specPath);
  return SourceRef(kind: kind, value: value, commitSha: sha);
}

class Codegen {
  Codegen({
    required this.spec,
    required this.outDir,
    required this.verbose,
    required this.withClient,
    this.sourceRef,
  });

  final Map<String, dynamic> spec;
  final String outDir;
  final bool verbose;
  final bool withClient;

  /// Upstream ref (tag, branch, or commit SHA) the spec was fetched
  /// from, pre-resolved to a commit SHA. Recorded in every generated
  /// file header so we always know exactly what the code was generated
  /// from. Null when the generator is run against a local file with no
  /// tracked upstream.
  final SourceRef? sourceRef;

  late final Map<String, dynamic> components = (spec['components'] as Map<String, dynamic>?) ?? const {};
  late Map<String, dynamic> schemas = Map<String, dynamic>.from(
    (components['schemas'] as Map<String, dynamic>?) ?? const {},
  );
  late final Map<String, dynamic> paths = (spec['paths'] as Map<String, dynamic>?) ?? const {};
  late List<Operation> operations = _collectOperations();

  /// Maps a schema name → name of the union (sealed/interface) class it
  /// implements. Built from anyOf / oneOf in the schema registry.
  late final Map<String, String> _unionParents = _buildUnionParents();

  /// Pre-scan: list of schema names that are top-level array schemas.
  /// Populated eagerly so the API client emitter can detect them.
  late final Set<String> _arrayWrapperClassNames = _buildArrayWrapperClassNames();

  /// Header block describing the upstream source the code was
  /// generated from: the upstream ref and resolved commit SHA when
  /// [sourceRef] is set, or a `local` marker otherwise. Deliberately
  /// contains NO generation timestamp — regenerating against an
  /// unchanged spec must produce byte-identical output so diffs show
  /// only real upstream changes. Lines are returned WITHOUT the `// `
  /// prefix so callers can emit them as comments themselves.
  String sourceHeader() {
    if (sourceRef != null) {
      return 'Source: ${sourceRef!.display}';
    }
    return 'Source: local (no upstream ref)';
  }

  Future<void> run() async {
    _run();
  }

  Set<String> _buildArrayWrapperClassNames() {
    final out = <String>{};
    schemas.forEach((rawName, schema) {
      if (schema is! Map<String, dynamic>) return;
      if (schema['type'] == 'array') {
        out.add(_pascalFromSnake(rawName.toString()));
      }
    });
    return out;
  }

  Map<String, String> _buildUnionParents() {
    final out = <String, String>{};
    schemas.forEach((rawName, schema) {
      if (schema is! Map<String, dynamic>) return;
      final variants = (schema['anyOf'] as List?) ?? (schema['oneOf'] as List?);
      if (variants == null) return;
      final cleanParent = _pascalFromSnake(rawName);
      for (final v in variants) {
        if (v is! Map<String, dynamic>) continue;
        final r = v[r'$ref'];
        if (r is String && r.startsWith('#/components/schemas/')) {
          final childRaw = _schemaNameFromRef(r);
          // Skip enum variants: Dart enums cannot `implements` an
          // abstract interface class with abstract members, so treating
          // an enum as a union variant would generate broken code.
          final childSchema = schemas[childRaw] as Map<String, dynamic>?;
          if (childSchema != null && childSchema['type'] == 'string' && childSchema['enum'] is List) {
            continue;
          }
          out[childRaw] = cleanParent;
        }
      }
    });
    return out;
  }

  void log(String msg) {
    if (verbose) stdout.writeln('[codegen] $msg');
  }

  void _run() {
    final surface = _loadSurface();
    _synthesizeInlineResponseModels();
    operations = _selectSurfaceOperations(surface.operations);
    final selectedSchemas = _selectSurfaceSchemas(surface.extraSchemas);
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
      final schema = schemas[name] as Map<String, dynamic>;
      _writeModelFile(name, schema);
      log('model $name');
    }

    final selectedParentClasses = sortedSchemas.map(_pascalFromSnake).toSet();
    final missingParentClasses = <String>{};
    for (final name in sortedSchemas) {
      final parent = _unionParents[name];
      if (parent != null && !selectedParentClasses.contains(parent)) {
        missingParentClasses.add(parent);
      }
    }
    for (final parent in missingParentClasses.toList()..sort()) {
      _writeUnionParentStub(parent);
      log('union parent stub $parent');
    }

    final apiFile = File('$outDir/opencode_client.dart');
    if (withClient) {
      var apiBody = _emitApiClient().trimRight();
      apiBody = '$apiBody\n';
      apiFile.writeAsStringSync(apiBody);
      log('api client -> ${apiFile.path}');
    } else if (apiFile.existsSync()) {
      apiFile.deleteSync();
      log('deleted ${apiFile.path} (--with-client not set)');
    }
  }

  SurfaceSpec _loadSurface() {
    final file = File('tool/opencode_v1_surface.json');
    if (!file.existsSync()) {
      throw StateError('Missing tool/opencode_v1_surface.json');
    }
    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return SurfaceSpec.fromJson(json);
  }

  List<Operation> _selectSurfaceOperations(List<String> allowedIds) {
    final byId = <String, Operation>{
      for (final op in operations)
        if (op.operationId != null) op.operationId!: op,
    };
    final missing = allowedIds.where((id) => !byId.containsKey(id)).toList();
    if (missing.isNotEmpty) {
      stderr.writeln('error: OpenAPI spec is missing allowlisted operationId(s): ${missing.join(', ')}');
      exit(1);
    }
    return allowedIds.map((id) => byId[id]!).toList()..sort((a, b) => a.methodName.compareTo(b.methodName));
  }

  Set<String> _selectSurfaceSchemas(List<String> extraSchemas) {
    final roots = <String>{...extraSchemas};
    for (final op in operations) {
      final response = op.successResponse;
      if (response != null) _collectTypesFromDartType(response.dartType, roots);
      if (op.requestBodySchema != null) _collectRefsFromSchema(op.requestBodySchema!, roots);
      for (final p in op.parameters) {
        if (p.schema != null) _collectRefsFromSchema(p.schema!, roots);
      }
    }
    roots.addAll(_eventSchemasFromManifest());
    final closure = <String>{};
    final stack = roots.where(schemas.containsKey).toList();
    while (stack.isNotEmpty) {
      final name = stack.removeLast();
      if (!closure.add(name)) continue;
      final schema = schemas[name];
      if (schema is! Map<String, dynamic>) continue;
      final refs = <String>{};
      _collectRefsFromSchema(schema, refs);
      for (final ref in refs) {
        if (schemas.containsKey(ref) && !closure.contains(ref)) stack.add(ref);
      }
    }
    return closure;
  }

  Set<String> _eventSchemasFromManifest() {
    final file = File('tool/opencode_events_v1.json');
    if (!file.existsSync()) return const {};
    final manifest = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final events = (manifest['events'] as List).cast<Map<String, dynamic>>();
    final manifestTypes = events.map((e) => e['type'] as String).toSet();
    final out = <String>{};
    for (final type in manifestTypes) {
      final schemaName = _eventSchemaNameForType(type);
      if (schemas.containsKey(schemaName)) {
        out.add(schemaName);
      } else {
        stderr.writeln('warning: manifest event "$type" has no OpenAPI Event schema');
      }
    }
    final specEvents = schemas.keys.where((name) => name.startsWith('Event.')).toList()..sort();
    for (final schemaName in specEvents) {
      final type = schemaName.substring('Event.'.length);
      if (!manifestTypes.contains(type)) {
        stderr.writeln('warning: OpenAPI schema $schemaName is absent from tool/opencode_events_v1.json');
      }
    }
    return out;
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

  void _collectRefsFromSchema(Map<String, dynamic> sch, Set<String> out) {
    final r = sch[r'$ref'];
    if (r is String) {
      out.add(_schemaNameFromRef(r));
      return;
    }
    for (final key in ['anyOf', 'oneOf', 'allOf']) {
      final variants = sch[key];
      if (variants is List) {
        for (final item in variants) {
          if (item is Map<String, dynamic>) _collectRefsFromSchema(item, out);
        }
      }
    }
    final props = sch['properties'];
    if (props is Map) {
      for (final value in props.values) {
        if (value is Map<String, dynamic>) _collectRefsFromSchema(value, out);
      }
    }
    final items = sch['items'];
    if (items is Map<String, dynamic>) _collectRefsFromSchema(items, out);
    final ap = sch['additionalProperties'];
    if (ap is Map<String, dynamic>) _collectRefsFromSchema(ap, out);
  }

  void _synthesizeInlineResponseModels() {
    const names = {
      'global.health': 'GlobalHealthResponse',
      'session.messages': 'SessionMessagesResponseItem',
      'session.command': 'SessionCommandResponse',
      'config.providers': 'ConfigProvidersResponse',
      'provider.list': 'ProviderListResponse',
    };
    for (final op in operations) {
      final className = names[op.operationId];
      if (className == null) continue;
      final schema = op.successResponseSchema;
      if (schema == null) continue;
      if (schema['type'] == 'array') {
        final items = schema['items'];
        if (items is Map<String, dynamic>) {
          schemas[className] = items;
          op.successResponse?.dartType = 'List<$className>';
        }
      } else {
        schemas[className] = schema;
        op.successResponse?.dartType = className;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Operation collection
  // ---------------------------------------------------------------------------

  static const _httpVerbs = ['get', 'post', 'put', 'patch', 'delete'];

  List<Operation> _collectOperations() {
    final out = <Operation>[];
    paths.forEach((path, item) {
      if (item is! Map<String, dynamic>) return;
      for (final verb in _httpVerbs) {
        final op = item[verb];
        if (op is! Map<String, dynamic>) continue;
        out.add(Operation.fromOpenApi(path: path, method: verb, op: op));
      }
    });
    out.sort((a, b) => a.methodName.compareTo(b.methodName));
    return out;
  }

  // ---------------------------------------------------------------------------
  // File emission
  // ---------------------------------------------------------------------------

  void _writeModelFile(String rawName, Map<String, dynamic> schema) {
    final cleanName = _pascalFromSnake(rawName);
    final fileName = _snakeFromCamel(rawName);
    final relPath = 'models/openapi/$fileName.g.dart';
    final writer = ModelWriter(
      name: cleanName,
      rawName: rawName,
      schema: schema,
      schemas: schemas,
      implementsClass: _unionParents[rawName],
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

  String _emitApiClient() {
    // Collect all schema names referenced by operations (return types, body
    // types, parameter types). Emit a per-type import for each.
    final referenced = _collectOperationSchemas();
    final imports = <String>[];
    for (final schemaName in referenced) {
      imports.add("import 'models/openapi/${_snakeFromCamel(schemaName)}.g.dart';");
    }
    imports.sort();

    final b = StringBuffer();
    b.writeln('// GENERATED FILE - DO NOT EDIT BY HAND');
    b.writeln('//');
    b.writeln('// Auto-generated OpenCode v2 client generated from the OpenAPI spec.');
    for (final line in sourceHeader().split('\n')) {
      b.writeln('// $line');
    }
    b.writeln('//');
    b.writeln('// To regenerate, run:');
    b.writeln('//   make opencode-codegen OPENCODE_TAG=<tag>');
    b.writeln('//   make opencode-codegen OPENCODE_BRANCH=<branch>');
    b.writeln('//   make opencode-codegen OPENCODE_COMMIT=<40-char-sha>');
    b.writeln('//   make opencode-codegen OPENCODE_SPEC=/path/to/openapi.json');
    b.writeln();
    b.writeln("import 'dart:async';");
    b.writeln("import 'dart:convert';");
    b.writeln();
    b.writeln("import 'package:http/http.dart' as http;");
    b.writeln("import 'package:meta/meta.dart';");
    b.writeln();
    imports.forEach(b.writeln);
    b.writeln();

    b.writeln(_emitClientClass());
    return b.toString();
  }

  /// Returns the set of schema names referenced by all operations.
  Set<String> _collectOperationSchemas() {
    final out = <String>{};
    for (final op in operations) {
      final r = op.successResponse;
      if (r != null) {
        _collectTypesFromDartType(r.dartType, out);
      }
      if (op.requestBodySchema != null) {
        _collectTypesFromSchema(op.requestBodySchema!, out);
      }
      for (final p in op.parameters) {
        if (p.schema != null) _collectTypesFromSchema(p.schema!, out);
      }
    }
    return out;
  }

  void _collectTypesFromDartType(String dartType, Set<String> out) {
    // Strip List<...>, Map<String, ...>, ? nullability, etc.
    final base = dartType.replaceAll(RegExp(r'[\?<>\[\], ]'), '').trim();
    if (base.isEmpty) return;
    // Check if it's a top-level schema name
    if (schemas.containsKey(base)) {
      out.add(base);
    }
    // Also handle List<X> by extracting X
    final listMatch = RegExp(r'List<(\w+)>').firstMatch(dartType);
    if (listMatch != null) {
      final inner = listMatch.group(1)!;
      if (schemas.containsKey(inner)) out.add(inner);
    }
  }

  void _collectTypesFromSchema(Map<String, dynamic> sch, Set<String> out) {
    final r = sch[r'$ref'];
    if (r is String) {
      final name = _schemaNameFromRef(r);
      if (schemas.containsKey(name)) out.add(name);
      return;
    }
    // anyOf / oneOf: if there is exactly one non-null variant, the type
    // resolves to that variant's type; otherwise the type collapses to
    // `dynamic` (or `Map<String, dynamic>` for request bodies), and the
    // individual variant refs are NOT referenced as Dart types.
    for (final key in ['anyOf', 'oneOf']) {
      final v = sch[key];
      if (v is List) {
        final nonNull = v.where((x) => x is Map && x['type'] != 'null').cast<Map<String, dynamic>>().toList();
        if (nonNull.length == 1) {
          _collectTypesFromSchema(nonNull.first.cast<String, dynamic>(), out);
        }
        return;
      }
    }
    final type = sch['type'];
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) _collectTypesFromSchema(items, out);
    } else if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) _collectTypesFromSchema(ap, out);
    }
  }

  String _emitClientClass() {
    final b = StringBuffer();
    b.writeln('/// OpenCode REST API client.');
    b.writeln('///');
    b.writeln('/// HTTP Basic auth: username `opencode`, password supplied at construction.');
    b.writeln('@immutable');
    b.writeln('class OpenCodeClient {');
    b.writeln('  const OpenCodeClient({');
    b.writeln('    required this.baseUrl,');
    b.writeln('    required String password,');
    b.writeln('    required http.Client httpClient,');
    b.writeln('  })  : _password = password,');
    b.writeln('        _http = httpClient;');
    b.writeln();
    b.writeln('  /// Base URL of the OpenCode server, e.g. `http://127.0.0.1:4096`.');
    b.writeln('  final String baseUrl;');
    b.writeln('  final String _password;');
    b.writeln('  final http.Client _http;');
    b.writeln();
    b.writeln('  Map<String, String> get _authHeaders => {');
    b.writeln(r"    'Authorization': 'Basic ${base64Encode(utf8.encode('opencode:$_password'))}',");
    b.writeln('  };');
    b.writeln();
    b.writeln('  /// Builds the request URI for [path], preserving any path prefix');
    b.writeln('  /// on [baseUrl] and omitting the query string entirely when');
    b.writeln('  /// [query] is empty (avoids a trailing `?`).');
    b.writeln('  Uri _uri(String path, Map<String, String> query) {');
    b.writeln('    final base = Uri.parse(baseUrl);');
    b.writeln("    final basePath = base.path.endsWith('/')");
    b.writeln('        ? base.path.substring(0, base.path.length - 1)');
    b.writeln('        : base.path;');
    b.writeln('    return base.replace(');
    b.writeln(r"      path: '$basePath$path',");
    b.writeln('      queryParameters: query.isEmpty ? null : query,');
    b.writeln('    );');
    b.writeln('  }');
    b.writeln();
    b.writeln('  void close() => _http.close();');
    b.writeln();
    b.writeln('  // -------------------------------------------------------------------');
    b.writeln('  // Operations');
    b.writeln('  // -------------------------------------------------------------------');
    b.writeln();

    final methodOwners = <String, Operation>{};
    for (final op in operations) {
      final existing = methodOwners[op.methodName];
      if (existing != null) {
        if (existing.operationId != null && existing.operationId == op.operationId) {
          // The same operation exposed on an alias path; first wins.
          continue;
        }
        // Two DIFFERENT operations collapsing onto the same method name
        // would silently drop one of them. Abort loudly so the naming
        // logic gets explicit disambiguation instead.
        throw StateError(
          'Method name collision: "${op.methodName}" generated from both '
          '"${existing.method.toUpperCase()} ${existing.path}" '
          '(operationId: ${existing.operationId}) and '
          '"${op.method.toUpperCase()} ${op.path}" '
          '(operationId: ${op.operationId}).',
        );
      }
      methodOwners[op.methodName] = op;
      b.writeln(_emitApiMethod(op));
      b.writeln();
    }

    b.writeln('}');

    b.writeln();
    b.writeln('@immutable');
    b.writeln('class OpenCodeApiException implements Exception {');
    b.writeln('  const OpenCodeApiException({');
    b.writeln('    required this.statusCode,');
    b.writeln('    required this.body,');
    b.writeln('  });');
    b.writeln();
    b.writeln('  final int statusCode;');
    b.writeln('  final String body;');
    b.writeln();
    b.writeln('  @override');
    b.writeln(r'  String toString() => "OpenCodeApiException($statusCode): $body";');
    b.writeln('}');
    return b.toString().trimRight();
  }

  // ---------------------------------------------------------------------------
  // API method emission
  // ---------------------------------------------------------------------------

  String _emitApiMethod(Operation op) {
    final b = StringBuffer();
    final methodName = op.methodName;

    final pathParams = <Parameter>[];
    final queryParams = <Parameter>[];
    for (final p in op.parameters) {
      if (p.inBody == 'path') {
        pathParams.add(p);
      } else if (p.inBody == 'query') {
        queryParams.add(p);
      }
    }

    final response = op.successResponse;
    final responseType = _responseTypeString(response);

    b.writeln('/// ${op.summary ?? op.description ?? "${op.method.toUpperCase()} ${op.path}"}');
    if (op.description != null && op.description != op.summary) {
      b.writeln('///');
      b.writeln('/// ${op.description}');
    }
    b.writeln('///');
    b.writeln("/// `operationId`: `${op.operationId ?? methodName}`");

    final params = <String>[];
    for (final p in pathParams) {
      final dartType = _dartTypeForParameter(p.schema);
      params.add('required $dartType ${_safeIdentifier(p.name)}');
    }
    if (op.requestBodySchema != null) {
      // Inline (non-$ref) request bodies are emitted as Map<String, dynamic>
      // — they don't get a synthetic class.
      if (op.requestBodySchema![r'$ref'] is String) {
        final bodyType = _classNameForRef(op.requestBodySchema!);
        params.add('required $bodyType body');
      } else {
        params.add('required Map<String, dynamic> body');
      }
    }
    for (final p in queryParams) {
      final dartType = _dartTypeForParameter(p.schema);
      if (p.required) {
        params.add('required $dartType ${p.name}');
      } else {
        params.add('$dartType? ${p.name}');
      }
    }

    final paramsString = params.isEmpty ? '()' : '({\n    ${params.join(',\n    ')},\n  })';
    b.writeln('Future<$responseType> $methodName$paramsString async {');

    // Build path with substitutions: '/session/{sessionID}/message/{messageID}'
    final pathExpr = _buildPathExpression(op.path);

    // Build query parameters map
    final queryParts = <String>[];
    for (final p in queryParams) {
      // Object-typed query parameters (e.g. `Map<String, dynamic>? location`)
      // can't use `toString()` — that produces Dart's debug format
      // `{directory: /repo}` rather than a query-serializable value.
      // JSON-encode them so the server sees a structured payload (the
      // server is expected to URL-decode the JSON string).
      final isMap = p.schema != null && p.schema!['type'] == 'object';
      final valueExpr = isMap ? 'jsonEncode(${p.name})' : '${p.name}.toString()';
      if (p.required) {
        queryParts.add("'${p.name}': $valueExpr");
      } else {
        queryParts.add("if (${p.name} != null) '${p.name}': $valueExpr");
      }
    }
    final queryExpr = queryParts.isEmpty ? 'const <String, String>{}' : '<String, String>{${queryParts.join(', ')}}';

    b.writeln('    final uri = _uri($pathExpr, $queryExpr);');

    b.writeln('    final headers = <String, String>{');
    b.writeln('      ..._authHeaders,');
    b.writeln("      'Content-Type': 'application/json',");
    b.writeln('    };');

    if (op.requestBodySchema != null) {
      // If the body is a $ref to a generated class, call .toJson(). If it's
      // an inline schema (Map<String, dynamic>), serialize directly.
      if (op.requestBodySchema![r'$ref'] is String) {
        b.writeln('    final encoded = jsonEncode(body.toJson());');
      } else {
        b.writeln('    final encoded = jsonEncode(body);');
      }
    }

    final methodUpper = op.method.toLowerCase();
    final bodyArg = op.requestBodySchema != null ? ', body: encoded' : '';
    b.writeln('    final http.Response resp = await _http.$methodUpper(uri, headers: headers$bodyArg);');

    b.writeln('    if (resp.statusCode < 200 || resp.statusCode >= 300) {');
    b.writeln('      throw OpenCodeApiException(');
    b.writeln('        statusCode: resp.statusCode,');
    b.writeln('        body: resp.body,');
    b.writeln('      );');
    b.writeln('    }');

    if (response == null || response.isNoContent) {
      b.writeln('    return;');
    } else if (_isPrimitiveType(response.dartType)) {
      b.writeln('    return ${_parsePrimitive(response.dartType, 'resp.body')};');
    } else if (_arrayWrapperClassNames.contains(response.dartType)) {
      // Top-level array schema — response body is a raw JSON array.
      b.writeln('    final decoded = jsonDecode(resp.body) as List<dynamic>;');
      b.writeln('    return ${response.dartType}.fromJson(decoded);');
    } else if (response.dartType.startsWith('List<')) {
      // Extract inner type between the first '<' and the last '>'.
      final inner = response.dartType.substring(5, response.dartType.length - 1);
      b.writeln('    final decoded = jsonDecode(resp.body) as List<dynamic>;');
      if (_isPrimitiveType(inner)) {
        b.writeln('    return decoded.cast<$inner>();');
      } else if (inner.contains('<')) {
        // Nested generic — fall back to a manual mapping.
        b.writeln('    return []; // TODO: nested generic $inner');
      } else {
        b.writeln('    return decoded.map((e) => $inner.fromJson(e as Map<String, dynamic>)).toList();');
      }
    } else {
      b.writeln('    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;');
      b.writeln('    return ${response.dartType}.fromJson(decoded);');
    }

    b.writeln('  }');
    return b.toString();
  }

  // ---------------------------------------------------------------------------
  // Type emission
  // ---------------------------------------------------------------------------

  /// Used for query / path parameters — always returns a non-nullable Dart type
  /// (we accept the runtime value as-is).
  String _dartTypeForParameter(Map<String, dynamic>? sch) {
    if (sch == null) return 'String';
    return _dartTypeForSchema(sch, nullable: false);
  }

  /// Core type emitter.
  String _dartTypeForSchema(Map<String, dynamic> sch, {required bool nullable}) {
    final r = sch[r'$ref'];
    if (r is String) {
      final name = _schemaNameFromRef(r);
      return _wrap(_pascalFromSnake(name), nullable);
    }
    final type = sch['type'];
    final format = sch['format'];
    if (type == 'string') {
      if (format == 'date-time') return _wrap('DateTime', nullable);
      if (format == 'uri' || format == 'url') return _wrap('Uri', nullable);
      return _wrap('String', nullable);
    }
    if (type == 'integer') return _wrap('int', nullable);
    if (type == 'number') return _wrap('double', nullable);
    if (type == 'boolean') return _wrap('bool', nullable);
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        return _wrap('List<${_dartTypeForSchema(items, nullable: false)}>', nullable);
      }
      return _wrap('List<Object>', nullable);
    }
    if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return _wrap('Map<String, ${_dartTypeForSchema(ap, nullable: false)}>', nullable);
      }
      if (ap == true) {
        return _wrap('Map<String, Object>', nullable);
      }
      return _wrap('Map<String, Object>', nullable);
    }
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      // If one variant is `null`, use the non-null variant's type.
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeForSchema(nonNull.first, nullable: nullable);
      }
      // Multiple non-null variants: emit as String (best-effort fallback).
      return _wrap('String', nullable);
    }
    if (sch['enum'] is List) {
      return _wrap('String', nullable);
    }
    return _wrap('Object', nullable);
  }

  String _wrap(String t, bool nullable) => nullable ? '$t?' : t;

  bool _isPrimitiveType(String t) {
    return t == 'bool' ||
        t == 'int' ||
        t == 'double' ||
        t == 'String' ||
        t == 'DateTime' ||
        t == 'Uri' ||
        t == 'Object';
  }

  String _parsePrimitive(String type, String body) {
    if (type == 'bool') return 'jsonDecode($body) as bool';
    if (type == 'int') return 'int.parse($body)';
    if (type == 'double') return 'double.parse($body)';
    if (type == 'DateTime') return 'DateTime.parse($body)';
    if (type == 'Uri') return 'Uri.parse($body)';
    if (type == 'Object') return 'jsonDecode($body) as Object';
    return body;
  }

  /// Used for typed body parameters and response types.
  String _classNameForRef(Map<String, dynamic> ref) {
    final r = ref[r'$ref'] as String;
    final name = _schemaNameFromRef(r);
    return _pascalFromSnake(name);
  }

  String _responseTypeString(ResponseSpec? r) {
    if (r == null) return 'void';
    if (r.isNoContent) return 'void';
    return r.dartType;
  }

  /// Builds a string expression that evaluates to the URL path with
  /// {paramName} interpolations.
  /// E.g., '/session/{sessionID}' -> "'/session/' + sessionID"
  String _buildPathExpression(String path) {
    final re = RegExp(r'\{([^}]+)\}');
    final matches = re.allMatches(path).toList();
    if (matches.isEmpty) {
      return "'${_escapeDartString(path)}'";
    }
    // Emit a single interpolated string literal: `'/auth/$id/...'` rather
    // than concatenating fragments with `+`. Keeps the generated code free
    // of the `prefer_interpolation_to_compose_strings` lint.
    final out = StringBuffer("'");
    var lastEnd = 0;
    for (final m in matches) {
      if (m.start > lastEnd) {
        out.write(_escapeDartString(path.substring(lastEnd, m.start)));
      }
      out.write(r'${Uri.encodeComponent(');
      out.write(_safeIdentifier(m.group(1) ?? ''));
      out.write(')}');
      lastEnd = m.end;
    }
    if (lastEnd < path.length) {
      out.write(_escapeDartString(path.substring(lastEnd)));
    }
    out.write("'");
    return out.toString();
  }

  String _escapeDartString(String s) => s.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$').replaceAll("'", r"\'");
}

String _schemaNameFromRef(String ref) {
  const prefix = '#/components/schemas/';
  if (!ref.startsWith(prefix)) {
    throw ArgumentError('Invalid \$ref: $ref');
  }
  return ref.substring(prefix.length);
}

// ---------------------------------------------------------------------------
// Operation / Parameter / Response models
// ---------------------------------------------------------------------------

class Operation {
  Operation.fromOpenApi({
    required this.path,
    required this.method,
    required this.op,
  }) {
    operationId = op['operationId'] as String?;
    summary = op['summary'] as String?;
    description = op['description'] as String?;

    final params = (op['parameters'] as List?) ?? const [];
    for (final p in params) {
      if (p is! Map<String, dynamic>) continue;
      parameters.add(Parameter.fromOpenApi(p));
    }

    final rb = op['requestBody'];
    if (rb is Map<String, dynamic>) {
      final content = rb['content'] as Map<String, dynamic>?;
      if (content != null) {
        final json = content['application/json'] as Map<String, dynamic>?;
        if (json != null) {
          final sch = json['schema'] as Map<String, dynamic>?;
          if (sch != null) requestBodySchema = sch;
        }
      }
    }

    final responses = op['responses'] as Map<String, dynamic>?;
    if (responses != null) {
      ResponseSpec? found;
      for (final code in ['200', '201', '202', '203', '204']) {
        final r = responses[code];
        if (r is Map<String, dynamic>) {
          found = ResponseSpec.fromOpenApi(r);
          if (code == '204') found.isNoContent = true;
          break;
        }
      }
      successResponse = found;
    }

    methodName = _methodNameFromId(operationId, method, path);
  }

  late final String path;
  late final String method;
  final Map<String, dynamic> op;
  String? operationId;
  String? summary;
  String? description;
  final List<Parameter> parameters = [];
  Map<String, dynamic>? requestBodySchema;
  ResponseSpec? successResponse;
  Map<String, dynamic>? get successResponseSchema => successResponse?.schema;
  late final String methodName;

  static String _methodNameFromId(String? id, String verb, String path) {
    if (id != null && id.isNotEmpty) {
      // OpenAPI `operationId` like "app.agents" or "event.subscribe" become
      // `appAgents` / `eventSubscribe`. Uses `_camelCore` (NOT
      // `_camelFromSnake`): the hash suffix that disambiguates dotted
      // SCHEMA names must not leak into method names. operationIds are
      // unique by spec; if two ever camelize to the same method name,
      // `_emitClientClass` aborts generation with a `StateError`.
      return _camelCore(id);
    }
    final cleaned = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.startsWith('{') ? 'by${s.substring(1, s.length - 1)}' : s)
        .join('_');
    return _camelCore('${verb}_$cleaned');
  }
}

class SurfaceSpec {
  SurfaceSpec({
    required this.operations,
    required this.extraSchemas,
  });

  factory SurfaceSpec.fromJson(Map<String, dynamic> json) {
    return SurfaceSpec(
      operations: (json['operations'] as List).cast<String>(),
      extraSchemas: ((json['extraSchemas'] as List?) ?? const []).cast<String>(),
    );
  }

  final List<String> operations;
  final List<String> extraSchemas;
}

class Parameter {
  Parameter.fromOpenApi(Map<String, dynamic> p) {
    name = p['name'] as String;
    inBody = p['in'] as String;
    required = (p['required'] as bool?) ?? false;
    schema = p['schema'] as Map<String, dynamic>?;
  }
  late final String name;
  late final String inBody;
  late final bool required;
  Map<String, dynamic>? schema;
}

class ResponseSpec {
  ResponseSpec.fromOpenApi(Map<String, dynamic> r) {
    description = r['description'] as String?;
    final content = r['content'] as Map<String, dynamic>?;
    if (content != null) {
      final json = content['application/json'] as Map<String, dynamic>?;
      if (json != null) {
        final sch = json['schema'] as Map<String, dynamic>?;
        if (sch != null) {
          schema = sch;
          dartType = _dartTypeFromSchema(sch);
        }
      }
    } else {
      isNoContent = true;
    }
  }
  String? description;
  Map<String, dynamic>? schema;
  String dartType = 'Object';
  bool isNoContent = false;

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
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
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

class ModelWriter {
  ModelWriter({
    required this.name,
    required this.rawName,
    required this.schema,
    required this.schemas,
    this.implementsClass,
    this.sourceHeader,
  });

  /// Cleaned, valid Dart class name.
  final String name;

  /// Original schema name as it appears in the OpenAPI document.
  final String rawName;
  final Map<String, dynamic> schema;
  final Map<String, dynamic> schemas;

  /// If this schema is a variant of a union, the name of the union class it
  /// implements.
  final String? implementsClass;

  /// Multi-line comment block describing the upstream ref / commit /
  /// generation timestamp. Emitted at the top of every generated file
  /// so consumers and reviewers always know what the code was
  /// generated from.
  final String? sourceHeader;

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
  static const _alwaysNullableStringFields = {'title', 'version'};

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
    final usedRefs = _computeUsedRefs(schema);
    usedRefs.remove(rawName);
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
    // Inline variants synthesized in `_emitUnion` reference refs of
    // their own (e.g. `PermissionRuleConfig.fromJson`). The header
    // import list must include them or the synthesized classes will
    // reference undefined identifiers.
    if (_isUnion(schema)) {
      final variants = ((schema['anyOf'] ?? schema['oneOf']) as List).cast<Map<String, dynamic>>();
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
            final sch = schemas[vName] as Map<String, dynamic>?;
            if (sch != null && sch['type'] == 'string' && sch['enum'] is List) {
              usedRefs.add(vName);
            }
          }
        }
      }
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
      body.write(_emitObjectClass(entry.className, entry.schema));
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
          final nonNull = v.where((x) => x is Map && x['type'] != 'null').cast<Map<String, dynamic>>().toList();
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
    final properties = sch['properties'] as Map?;
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
      final disc = _findDiscriminator(variants.cast<Map<String, dynamic>>());
      for (final variant in variants) {
        if (variant is! Map) continue;
        final r = variant[r'$ref'];
        if (r is! String) continue;
        final vName = _schemaNameFromRef(r);
        if (disc != null) {
          if (_discriminatorValue(vName, schemas, disc) != null) {
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
    if (sourceHeader != null && sourceHeader!.isNotEmpty) {
      for (final line in sourceHeader!.split('\n')) {
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

  bool _isEnum(Map<String, dynamic> s) {
    return s['enum'] is List && s['type'] == 'string';
  }

  bool _isUnion(Map<String, dynamic> s) {
    return (s['anyOf'] is List && (s['anyOf'] as List).isNotEmpty) ||
        (s['oneOf'] is List && (s['oneOf'] as List).isNotEmpty);
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
    final items = schema['items'] as Map<String, dynamic>?;
    final innerDart = items != null ? _dartTypeForInline(items, context: '${name}Item') : 'Object';
    final innerClass = items != null && items[r'$ref'] is String
        ? _pascalFromSnake(_schemaNameFromRef(items[r'$ref'] as String))
        : innerDart;
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
    final values = (schema['enum'] as List).cast<String>();
    return _emitEnumBody(name, values);
  }

  // -------------------------------------------------------------------------
  // Union emission (sealed class with discriminator)
  // -------------------------------------------------------------------------

  String _emitUnion() {
    final b = StringBuffer();

    final variants = ((schema['anyOf'] ?? schema['oneOf']) as List).cast<Map<String, dynamic>>();

    final disc = _findDiscriminator(variants);
    final inlineVariantClasses = <_InlineVariantClassEntry>[];

    _usesImmutable = true;
    b.writeln('@immutable');
    b.writeln('abstract interface class $name {');
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
          final d = _discriminatorValue(vName, schemas, disc);
          if (d != null) {
            b.writeln('      case ${jsonEncode(d)}:');
            b.writeln('        return ${_pascalFromSnake(vName)}.fromJson(map);');
          }
        } else {
          final d = _inlineDiscriminatorValue(v, disc);
          if (d != null) {
            final inlineName = '$name${_pascalCore(d)}';
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
      for (final v in variants) {
        final guard = _unionTypeGuard(v, inlineIndex);
        final decode = _unionTypeDecode(v, inlineIndex);
        if (guard == null || decode == null) continue;
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
          final sch = schemas[vName] as Map<String, dynamic>?;
          if (sch != null && sch['type'] == 'string' && sch['enum'] is List) {
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
      b.writeln(_emitInlineVariantClass(entry.className, entry.schema, name));
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
    b.writeln('class ${name}Unknown implements $name {');
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
  String _emitInlineVariantClass(
    String className,
    Map<String, dynamic> schema,
    String unionName,
  ) {
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
      final sch = schemas[refName] as Map<String, dynamic>?;
      final isEnum = sch != null && sch['type'] == 'string' && sch['enum'] is List;
      if (isEnum) {
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
      final enumVals = (schema['enum'] as List?)?.cast<String>();
      if (enumVals != null && enumVals.isNotEmpty) {
        _usesJsonValue = true;
        b.write(_emitEnumBody(className, enumVals));
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
        innerDart = 'Object';
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
      // Inline object variant — same emission as a top-level object
      // class, with the union interface attached (which also enables
      // the discriminator-literal handling).
      return _emitObjectClass(className, schema, implementsClass: unionName);
    }
    // Fallback: emit an opaque Map wrapper.
    _usesImmutable = true;
    _usesDeepEquality = true;
    b.writeln('@immutable');
    b.writeln('class $className implements $unionName {');
    b.writeln('  const $className(this.json);');
    b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    b.writeln('    return $className(json);');
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
    final properties = (schema['properties'] as Map<String, dynamic>?) ?? const {};

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
        return _emitMapWrapper(StringBuffer(), ap);
      }
      // Free-form object schema with no explicit additionalProperties
      // restriction (e.g. JSONSchema). Preserve the raw JSON map rather
      // than discarding every key in an empty class.
      if (ap == true || ap == null) {
        return _emitFreeformMapWrapper(StringBuffer());
      }
    }
    return _emitObjectClass(name, schema, implementsClass: implementsClass);
  }

  /// Emits a complete plain object class [className] for [sch]. Shared
  /// by top-level object schemas, union inline-object variants (with
  /// [implementsClass] set), and classes synthesized for inline object
  /// properties (e.g. `SessionTime`).
  String _emitObjectClass(
    String className,
    Map<String, dynamic> sch, {
    String? implementsClass,
  }) {
    final b = StringBuffer();
    final properties = (sch['properties'] as Map<String, dynamic>?) ?? const {};
    final required = ((sch['required'] as List?) ?? const []).cast<String>();

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
      for (final entry in properties.entries) {
        final psch = entry.value as Map<String, dynamic>?;
        if (psch == null) continue;
        if (psch['type'] != 'string') continue;
        final vals = psch['enum'];
        if (vals is! List || vals.length != 1) continue;
        literals[entry.key] = vals.first as String;
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
      final psch = entry.value as Map<String, dynamic>;
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
          baseType == 'String' && (_alwaysNullableStringFields.contains(fieldName) || context == 'CommandTemplate');
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
    b.writeln(implementsClass != null ? 'class $className implements $implementsClass {' : 'class $className {');
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
          '      ${_decodeField(f.jsonName, f.schema, f.isNullable, context: f.context)},',
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
        '      ${_encodeField(f.jsonName, f.schema, isNullable: f.isNullable, omitWhenNull: !f.isRequired, context: f.context)},',
      );
    }
    for (final f in fields.where((field) => !properties.containsKey(field.jsonName))) {
      b.writeln(
        '      ${_encodeField(f.jsonName, f.schema, isNullable: true, omitWhenNull: true, context: f.context)},',
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

  void _registerInlineObject(String className, Map<String, dynamic> sch) {
    if (_inlineObjectNames.contains(className)) return;
    _inlineObjectNames.add(className);
    _inlineObjects.add(_InlineObjectEntry(className: className, schema: sch));
  }

  void _registerInlineEnum(String className, List<String> values) {
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
  String _emitMapWrapper(StringBuffer b, Map<String, dynamic> ap) {
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
    if (ap[r'$ref'] is String) {
      final refName = _schemaNameFromRef(ap[r'$ref'] as String);
      final refSchema = schemas[refName] as Map<String, dynamic>?;
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
  String _emitFreeformMapWrapper(StringBuffer b) {
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
        _registerInlineEnum(context, enumVals.cast<String>());
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
        _registerInlineObject(context, sch);
        return context;
      }
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return 'Map<String, ${_dartTypeForInline(ap, context: '${context}Value')}>';
      }
      if (ap == true) return 'Map<String, dynamic>';
      return 'Map<String, dynamic>';
    }
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      // null + T -> T?
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeForInline(nonNull.first, context: context);
      }
      return 'Object';
    }
    if (sch['enum'] is List) {
      // Inline enum — register for emission.
      final values = (sch['enum'] as List).cast<String>();
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
    final refSchema = schemas[refName] as Map<String, dynamic>?;
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

  String _decodeField(
    String name,
    Map<String, dynamic> sch,
    bool isNullable, {
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
      final refSchema = schemas[refName] as Map<String, dynamic>?;
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
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _decodeField(name, nonNull.first, isNullable, context: context);
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
    if (type == 'string' && sch['enum'] is List) {
      final enumVals = (sch['enum'] as List).cast<String>();
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
          final refSchema = schemas[refName] as Map<String, dynamic>?;
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
        if (ap[r'$ref'] is String) {
          final refName = _schemaNameFromRef(ap[r'$ref'] as String);
          final refSchema = schemas[refName] as Map<String, dynamic>?;
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

  String _encodeField(
    String name,
    Map<String, dynamic> sch, {
    required bool isNullable,
    required bool omitWhenNull,
    required String context,
  }) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final callOp = isNullable ? '?' : '';
    final entryOp = omitWhenNull ? '?' : '';
    // anyOf [T, null] → T? — delegate to the non-null branch.
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _encodeField(name, nonNull.first, isNullable: isNullable, omitWhenNull: omitWhenNull, context: context);
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
    if (type == 'string' && sch['enum'] is List && (sch['enum'] as List).length > 1) {
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
    // value enum, and (2) every variant marks as required. We do not
    // restrict ourselves to the conventional `type`/`role`/`kind`/
    // `status` names: any common single-value enum works (e.g.
    // `MCPStatus` uses `status`, `SessionStatus` uses `type`).
    final resolved = <Map<String, dynamic>>[];
    for (final v in variants) {
      final r = v[r'$ref'];
      if (r is String) {
        final s = schemas[_schemaNameFromRef(r)] as Map<String, dynamic>?;
        if (s != null) resolved.add(s);
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
      final props = sch['properties'] as Map<String, dynamic>?;
      if (props == null) return null;
      for (final key in props.keys) {
        final p = props[key] as Map<String, dynamic>?;
        final enumVals = p?['enum'] as List?;
        if (enumVals != null && enumVals.length == 1) {
          allProps.add(key);
        }
      }
    }
    for (final candidate in allProps) {
      var allRequired = true;
      for (final sch in resolved) {
        final required = ((sch['required'] as List?) ?? const []).cast<String>();
        if (!required.contains(candidate)) {
          allRequired = false;
          break;
        }
      }
      if (allRequired) return candidate;
    }
    return null;
  }

  String? _discriminatorValue(String variantName, Map<String, dynamic> schemas, String? discName) {
    if (discName == null) return null;
    final schema = schemas[variantName] as Map<String, dynamic>?;
    if (schema == null) return null;
    final props = schema['properties'] as Map<String, dynamic>?;
    if (props == null) return null;
    final p = props[discName] as Map<String, dynamic>?;
    if (p == null) return null;
    final enumVals = p['enum'] as List?;
    if (enumVals == null || enumVals.isEmpty) return null;
    return enumVals.first as String;
  }

  /// Returns the discriminator value for an INLINE variant (one
  /// declared directly in the union's anyOf/oneOf, not via $ref).
  String? _inlineDiscriminatorValue(Map<String, dynamic> variant, String discName) {
    final props = variant['properties'] as Map<String, dynamic>?;
    if (props == null) return null;
    final p = props[discName] as Map<String, dynamic>?;
    if (p == null) return null;
    final enumVals = p['enum'] as List?;
    if (enumVals == null || enumVals.isEmpty) return null;
    return enumVals.first as String;
  }

  /// Build a runtime type guard for a union variant. Returns a string
  /// expression suitable for use in `if (...)`. `inlineIndex` is the
  /// variant's position in the union, used to construct synthesized
  /// class names.
  String? _unionTypeGuard(Map<String, dynamic> variant, int inlineIndex) {
    final r = variant[r'$ref'];
    if (r is String) {
      final vName = _schemaNameFromRef(r);
      final sch = schemas[vName] as Map<String, dynamic>?;
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
      final required = ((variant['required'] as List?) ?? const []).cast<String>();
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
  String? _unionTypeDecode(Map<String, dynamic> variant, int inlineIndex) {
    final r = variant[r'$ref'];
    if (r is String) {
      final vName = _schemaNameFromRef(r);
      final refType = _pascalFromSnake(vName);
      final sch = schemas[vName] as Map<String, dynamic>?;
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
class _InlineVariantClassEntry {
  _InlineVariantClassEntry({
    required this.className,
    required this.schema,
  });
  final String className;
  final Map<String, dynamic> schema;
}

/// A class synthesized for an inline `type: object` property schema
/// (e.g. `Session.time` → `SessionTime`). Emitted as a sibling of the
/// owning class by [ModelWriter.emit].
class _InlineObjectEntry {
  _InlineObjectEntry({
    required this.className,
    required this.schema,
  });
  final String className;
  final Map<String, dynamic> schema;
}

/// Everything the object-class emitter needs to know about one field,
/// computed once so the constructor, fromJson, toJson, `==`, hashCode,
/// and field declaration all agree.
class _FieldRecord {
  _FieldRecord({
    required this.jsonName,
    required this.safeName,
    required this.schema,
    required this.isRequired,
    required this.dartType,
    required this.context,
  });

  /// JSON object key as it appears in the spec.
  final String jsonName;

  /// Dart-safe identifier for the field.
  final String safeName;

  /// The field's property schema.
  final Map<String, dynamic> schema;

  /// Whether the spec lists the field in `required`.
  final bool isRequired;

  /// Final Dart type INCLUDING nullability marker.
  final String dartType;

  /// Whether the Dart field type is nullable (`dartType` ends with `?`).
  /// This is the single source of truth fromJson/toJson decode use, so
  /// the field declaration and the (de)serialization always agree.
  bool get isNullable => dartType.endsWith('?');

  /// Synthesized-class name context for inline objects under this field.
  final String context;
}

/// An enum class synthesized for an inline enum in a property.
class InlineEnum {
  InlineEnum({required this.className, required this.values});
  final String className;
  final List<String> values;

  String emit() => _emitEnumBody(className, values);
}

/// Emits a complete enum declaration named [enumName] for the spec
/// [values]. Every generated enum gains an `unknown` fallback member
/// (unless the spec itself already defines one): `fromJson` returns it
/// for values introduced by newer OpenCode servers instead of throwing,
/// and `toJson` encodes the synthetic member as the literal string
/// `unknown` — mirroring the hand-written `CommandSource.unknown`
/// convention already used in this package.
String _emitEnumBody(String enumName, List<String> values) {
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

String _pascalFromSnake(String name) {
  // Strip Effect schema prefix and leading underscores/dots.
  var s = name;
  if (s.startsWith('effect_')) {
    s = s.substring('effect_'.length);
  }
  s = s.replaceAll(RegExp('^[._]+'), '');

  final pascal = _pascalCore(s);
  // When the raw SCHEMA name contained a dot, `_pascalFromSnake` collapses
  // the two sides into the same identifier as a sibling that uses an
  // underscore (e.g. `Event.tui.command.execute` vs
  // `EventTuiCommandExecute`). Append a short stable hash of the raw name
  // so both siblings stay distinct without leaking the original dots into
  // identifiers (Dart identifiers may not contain `.`).
  if (name.contains('.')) {
    return '$pascal${_hashSuffix(name)}';
  }
  return pascal;
}

/// Pascal-cases [s] by splitting on underscores, dashes, and dots —
/// WITHOUT the dotted-name hash suffix that [_pascalFromSnake] appends.
/// Used where the input space is known to be collision-free: API method
/// names (operationIds are unique by spec; collisions abort generation)
/// and synthesized nested-class names (always parent-prefixed).
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

/// lowerCamelCase form of [_pascalCore] (no hash suffix).
String _camelCore(String name) {
  final pascal = _pascalCore(name);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
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
