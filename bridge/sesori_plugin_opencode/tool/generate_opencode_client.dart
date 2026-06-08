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
//   - opencode_client.dart                 — public API client class (Layer 1)
//   - models/openapi/<SchemaName>.dart     — one file per top-level schema (Layer 0)
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
  final sourceCount =
      [tag, branch, commit, localSpecPath].where((e) => e != null).length;
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
      stderr.writeln(
          'error: --commit must be a 40-character hex SHA; got "$commit"');
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
  );
  try {
    await gen.run();
  } finally {
    if (deleteSpecPathOnExit) {
      try {
        File(specPath!).deleteSync();
      } catch (_) {/* best-effort cleanup */}
    }
  }
  stdout.writeln('Done. Output: $outDir');
}

void _printUsage() {
  stderr.writeln('');
  stderr.writeln('Usage: dart run tool/generate_opencode_client.dart '
      '[--tag <tag> | --branch <branch> | --commit <sha> | --local <path>] '
      '[--out-dir <dir>] [--verbose]');
  stderr.writeln('');
  stderr.writeln('  --tag <name>        Fetch the spec from anomalyco/opencode at '
      'the given git tag (e.g. v1.16.2)');
  stderr.writeln('  --branch <name>     Fetch the spec from anomalyco/opencode at '
      'the given git branch (e.g. dev)');
  stderr.writeln('  --commit <sha>      Fetch the spec from anomalyco/opencode at '
      'the given 40-char commit SHA');
  stderr.writeln('  --local <path>      Use a local openapi.json file '
      '(no upstream ref recorded in headers)');
  stderr.writeln('  --out-dir <dir>     Output directory (default: lib/src)');
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
    stderr.writeln(
        'error: failed to fetch $url (HTTP ${response.statusCode})');
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
        'Check your network connection and that the ref exists.');
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
    stderr.writeln(
        'error: git ls-remote returned no entry for $kind "$value"');
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
    this.sourceRef,
  });

  final Map<String, dynamic> spec;
  final String outDir;
  final bool verbose;
  /// Upstream ref (tag, branch, or commit SHA) the spec was fetched
  /// from, pre-resolved to a commit SHA. Recorded in every generated
  /// file header so we always know exactly what the code was generated
  /// from. Null when the generator is run against a local file with no
  /// tracked upstream.
  final SourceRef? sourceRef;

  late final Map<String, dynamic> components =
      (spec['components'] as Map<String, dynamic>?) ?? const {};
  late final Map<String, dynamic> schemas =
      (components['schemas'] as Map<String, dynamic>?) ?? const {};
  late final Map<String, dynamic> paths =
      (spec['paths'] as Map<String, dynamic>?) ?? const {};
  late final List<Operation> operations = _collectOperations();
  /// Maps a schema name → name of the union (sealed/interface) class it
  /// implements. Built from anyOf / oneOf in the schema registry.
  late final Map<String, String> _unionParents = _buildUnionParents();
  /// Pre-scan: list of schema names that are top-level array schemas.
  /// Populated eagerly so the API client emitter can detect them.
  late final Set<String> _arrayWrapperClassNames = _buildArrayWrapperClassNames();

  /// Header block describing the upstream source the code was
  /// generated from. Always returns at least a one-line comment with
  /// the generation timestamp; when [sourceRef] is set, also includes
  /// the upstream ref and resolved commit SHA. Lines are returned
  /// WITHOUT the `// ` prefix so callers can emit them as comments
  /// themselves.
  String sourceHeader() {
    final b = StringBuffer();
    final now = DateTime.now().toUtc().toIso8601String();
    if (sourceRef != null) {
      b.writeln('Source: ${sourceRef!.display}');
    } else {
      b.writeln('Source: local (no upstream ref)');
    }
    b.writeln('Generated: $now');
    return b.toString().trimRight();
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
          if (childSchema != null &&
              childSchema['type'] == 'string' &&
              childSchema['enum'] is List) {
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
    final modelsDir = Directory('$outDir/models/openapi');
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

    final sortedSchemas = schemas.keys.toList()..sort();
    for (final name in sortedSchemas) {
      if (skipSchemas.contains(name)) {
        log('SKIP $name (dotted equivalent exists)');
        continue;
      }
      final schema = schemas[name] as Map<String, dynamic>;
      _writeModelFile(name, schema);
      log('model $name');
    }

    final apiPath = '$outDir/opencode_client.dart';
    // Trim trailing whitespace and ensure the file ends with exactly
    // one newline. The dart analyzer flags `eol_at_end_of_file` if the
    // last byte is not `\n`, and tooling occasionally complains about
    // stray blank lines.
    var apiBody = _emitApiClient().trimRight();
    apiBody = '$apiBody\n';
    File(apiPath).writeAsStringSync(apiBody);
    log('api client -> $apiPath');
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
    final relPath = 'models/openapi/$fileName.dart';
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

  String _emitApiClient() {
    // Collect all schema names referenced by operations (return types, body
    // types, parameter types). Emit a per-type import for each.
    final referenced = _collectOperationSchemas();
    final imports = <String>[];
    for (final schemaName in referenced) {
      imports.add("import 'models/openapi/${_snakeFromCamel(schemaName)}.dart';");
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
        final nonNull = v
            .where((x) => x is Map && x['type'] != 'null')
            .cast<Map<String, dynamic>>()
            .toList();
        if (nonNull.length == 1) {
          _collectTypesFromSchema(
              nonNull.first.cast<String, dynamic>(), out);
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
    b.writeln('class OpenCodeClient {');
    b.writeln('  OpenCodeClient({');
    b.writeln('    required this.baseUrl,');
    b.writeln('    required String password,');
    b.writeln('    http.Client? httpClient,');
    b.writeln('  })  : _password = password,');
    b.writeln('        _http = httpClient ?? http.Client();');
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
    b.writeln('  void close() => _http.close();');
    b.writeln();
    b.writeln('  // -------------------------------------------------------------------');
    b.writeln('  // Operations');
    b.writeln('  // -------------------------------------------------------------------');
    b.writeln();

    final writtenMethods = <String>{};
    for (final op in operations) {
      if (writtenMethods.contains(op.methodName)) continue;
      writtenMethods.add(op.methodName);
      b.writeln(_emitApiMethod(op));
      b.writeln();
    }

    b.writeln('}');

    b.writeln();
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
    final queryBuffer = StringBuffer('{');
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
    queryBuffer.write(queryParts.join(', '));
    queryBuffer.write('}');

    b.writeln('    final uri = Uri.parse(baseUrl).replace(');
    b.writeln('      path: $pathExpr,');
    b.writeln('      queryParameters: $queryBuffer,');
    b.writeln('    );');

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
    return t == 'bool' || t == 'int' || t == 'double' || t == 'String' || t == 'DateTime' || t == 'Uri' || t == 'Object';
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

  String _escapeDartString(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll(r'$', r'\$').replaceAll("'", r"\'");
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
  late final String methodName;

  static String _methodNameFromId(String? id, String verb, String path) {
    if (id != null && id.isNotEmpty) {
      // OpenAPI `operationId` like "app.agents" or "event.subscribe" become
      // `appAgents` / `eventSubscribe` to satisfy `non_constant_identifier_names`.
      return _camelFromSnake(id.replaceAll('-', '_'));
    }
    final cleaned = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.startsWith('{')
            ? 'by${s.substring(1, s.length - 1)}'
            : s)
        .join('_');
    return _camelFromSnake('${verb}_$cleaned');
  }
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
          dartType = _dartTypeFromSchema(sch);
        }
      }
    } else {
      isNoContent = true;
    }
  }
  String? description;
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
      final variants =
          ((schema['anyOf'] ?? schema['oneOf']) as List).cast<Map<String, dynamic>>();
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
    final usesAnno = _isEnum(schema) || _inlineEnums.isNotEmpty;
    final header = _emitHeader(usedRefs, usesJsonAnnotation: usesAnno);
    if (_isEnum(schema)) return header + _emitEnum();
    if (_isUnion(schema)) return header + _emitUnion();
    if (_isArray(schema)) return header + _emitArrayAlias();
    if (_isObject(schema)) return header + _emitObject();
    return '$header// TODO: unknown schema kind for $name\n';
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
          final nonNull = v
              .where((x) => x is Map && x['type'] != 'null')
              .cast<Map<String, dynamic>>()
              .toList();
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
      // Object with additionalProperties as a $ref (map type).
      if (node['type'] == 'object') {
        final ap = node['additionalProperties'];
        if (ap is Map) visitField(ap);
        // Otherwise it's an inline object that becomes Map<String, dynamic>
        // or has its own properties; don't recurse — those properties become
        // raw map entries, not typed fields.
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

  String _emitHeader(Set<String> refs, {required bool usesJsonAnnotation}) {
    final b = StringBuffer();
    b.writeln('// GENERATED FILE - DO NOT EDIT BY HAND');
    if (sourceHeader != null && sourceHeader!.isNotEmpty) {
      for (final line in sourceHeader!.split('\n')) {
        b.writeln('// $line');
      }
    }
    b.writeln();
    // Only emit the json_annotation import if the body actually uses it
    // (e.g. enum @JsonValue annotations). Otherwise it triggers
    // `unused_import` warnings on every generated file.
    if (usesJsonAnnotation) {
      b.writeln("import 'package:json_annotation/json_annotation.dart';");
      b.writeln();
    }
    final sortedRefs = refs.toList()..sort();
    for (final ref in sortedRefs) {
      b.writeln("import '${_snakeFromCamel(ref)}.dart';");
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
    final innerDart = items != null ? _dartTypeForInline(items) : 'Object';
    final innerClass = items != null && items[r'$ref'] is String
        ? _pascalFromSnake(_schemaNameFromRef(items[r'$ref'] as String))
        : innerDart;
    final isPrimitiveInner = _isInlinePrimitive(innerDart);
    final innerElement = isPrimitiveInner
        ? 'e as $innerDart'
        : '$innerClass.fromJson(e as Map<String, dynamic>)';
    final b = StringBuffer();
    b.writeln('/// Type alias for `List<$innerClass>` decoded from JSON.');
    b.writeln('class $name {');
    b.writeln('  const $name({required this.items});');
    b.writeln('  factory $name.fromJson(List<dynamic> json) => $name(items: json.map((e) => $innerElement).toList());');
    if (isPrimitiveInner) {
      b.writeln('  List<dynamic> toJson() => items.toList();');
    } else {
      b.writeln('  List<dynamic> toJson() => items.map((e) => e.toJson()).toList();');
    }
    b.writeln('  final List<$innerClass> items;');
    b.writeln('}');
    return b.toString();
  }

  /// Like `_isPrimitiveType` but available as a static method (ModelWriter
  /// cannot reach Codegen's instance state).
  static bool _isInlinePrimitive(String t) {
    return t == 'bool' || t == 'int' || t == 'double' || t == 'String' || t == 'DateTime' || t == 'Uri' || t == 'Object';
  }

  // -------------------------------------------------------------------------
  // Enum emission
  // -------------------------------------------------------------------------

  String _emitEnum() {
    final b = StringBuffer();
    b.writeln('enum $name {');
    final values = (schema['enum'] as List).cast<String>();
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('  @JsonValue(${jsonEncode(v)})');
      b.writeln('  $memberName,');
    }
    b.writeln('  ;');
    b.writeln();
    b.writeln('  static $name fromJson(String value) {');
    b.writeln('    switch (value) {');
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('      case ${jsonEncode(v)}:');
      b.writeln('        return $name.$memberName;');
    }
    b.writeln('      default:');
    b.writeln("        throw FormatException('Unknown $name value: \$value');");
    b.writeln('    }');
    b.writeln('  }');
    b.writeln();
    b.writeln('  String toJson() {');
    b.writeln('    switch (this) {');
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('      case $name.$memberName:');
      b.writeln('        return ${jsonEncode(v)};');
    }
    b.writeln('    }');
    b.writeln('  }');
    b.writeln('}');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Union emission (sealed class with discriminator)
  // -------------------------------------------------------------------------

  String _emitUnion() {
    final b = StringBuffer();

    final variants =
        ((schema['anyOf'] ?? schema['oneOf']) as List).cast<Map<String, dynamic>>();

    final disc = _findDiscriminator(variants);
    final inlineVariantClasses = <_InlineVariantClassEntry>[];

    b.writeln('abstract interface class $name {');
    b.writeln('  const $name();');
    b.writeln();
    b.writeln('  /// Serialize the underlying variant. Variants must override this.');
    b.writeln('  ///');
    b.writeln('  /// The return type is `dynamic` (not `Map<String, dynamic>`)');
    b.writeln('  /// because some unions are string-or-object and the string');
    b.writeln('  /// variant encodes as the scalar itself, not a wrapped map.');
    b.writeln('  /// Callers pass the result straight to `jsonEncode` or');
    b.writeln('  /// another `toJson()`, both of which accept `dynamic`.');
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
      var inlineIndex = 0;
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
            final inlineName = '${_safeIdentifier(name)}${inlineIndex.toString().padLeft(2, '0')}Inline';
            inlineIndex++;
            inlineVariantClasses.add(_InlineVariantClassEntry(
              className: inlineName,
              schema: v,
            ));
            b.writeln('      case ${jsonEncode(d)}:');
            b.writeln('        return $inlineName.fromJson(map);');
          }
        }
      }
      b.writeln('      default:');
      b.writeln("        throw FormatException('Unknown $name value: \$discriminator');");
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
            final inlineName = '${_safeIdentifier(name)}${inlineIndex.toString().padLeft(2, '0')}Inline';
            inlineVariantClasses.add(_InlineVariantClassEntry(
              className: inlineName,
              schema: v,
            ));
          }
        } else {
          final inlineName = '${_safeIdentifier(name)}${inlineIndex.toString().padLeft(2, '0')}Inline';
          inlineVariantClasses.add(_InlineVariantClassEntry(
            className: inlineName,
            schema: v,
          ));
        }
        inlineIndex++;
      }
      b.writeln("    throw FormatException('Unknown $name value: \$json');");
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
        b.writeln('  dynamic toJson() => value.toJson();');
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
        b.writeln('enum $className {');
        for (final v in enumVals) {
          b.writeln('  @JsonValue(${jsonEncode(v)})');
          b.writeln('  ${_camelFromSnake(v)},');
        }
        b.writeln('  ;');
        b.writeln();
        b.writeln('  static $className fromJson(String value) {');
        b.writeln('    switch (value) {');
        for (final v in enumVals) {
          b.writeln('      case ${jsonEncode(v)}:');
          b.writeln('        return $className.${_camelFromSnake(v)};');
        }
        b.writeln('      default:');
        b.writeln("        throw FormatException('Unknown $className value: \$value');");
        b.writeln('    }');
        b.writeln('  }');
        b.writeln();
        b.writeln('  String toJson() {');
        b.writeln('    switch (this) {');
        for (final v in enumVals) {
          b.writeln('      case $className.${_camelFromSnake(v)}:');
          b.writeln('        return ${jsonEncode(v)};');
        }
        b.writeln('    }');
        b.writeln('  }');
        b.writeln('}');
      } else {
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
        b.writeln('  dynamic toJson() => value;');
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
          innerDart = _dartTypeForInline(items);
        }
      } else {
        innerDart = 'Object';
      }
      b.writeln('class $className implements $unionName {');
      b.writeln('  const $className({required this.items});');
      b.writeln('  factory $className.fromJson(List<dynamic> json) {');
      b.writeln('    return $className(items: json.cast<$innerDart>());');
      b.writeln('  }');
      b.writeln('  @override');
      b.writeln('  Map<String, dynamic> toJson() {');
      b.writeln("    return <String, dynamic>{ 'items': items };");
      b.writeln('  }');
      b.writeln('  final List<$innerDart> items;');
      b.writeln('}');
      return b.toString();
    }
    if (type == 'object') {
      // Inline object variant — render a typed class with the
      // schema's properties. The class implements the union
      // interface and exposes a typed `toJson()`.
      final props = (schema['properties'] as Map<String, dynamic>?) ?? const {};
      final required =
          ((schema['required'] as List?) ?? const []).cast<String>();
      // Same discriminator-literal handling as `_emitObject`:
      // a required single-value enum property of an inline
      // variant is the class's own constant and must not be
      // exposed as a constructor parameter.
      final literals = <String, String>{};
      for (final entry in props.entries) {
        final sch = entry.value as Map<String, dynamic>?;
        if (sch == null) continue;
        if (sch['type'] != 'string') continue;
        final vals = sch['enum'];
        if (vals is! List || vals.length != 1) continue;
        literals[entry.key] = vals.first as String;
      }
      b.writeln('class $className implements $unionName {');
      final realProps =
          props.entries.where((e) => !literals.containsKey(e.key)).toList();
      if (realProps.isEmpty) {
        b.writeln('  const $className();');
      } else {
        b.writeln('  const $className({');
        for (final entry in realProps) {
          final fieldName = entry.key;
          final safeName = _safeIdentifier(fieldName);
          final isRequired = required.contains(fieldName);
          if (isRequired) {
            b.writeln('    required this.$safeName,');
          } else {
            b.writeln('    this.$safeName,');
          }
        }
        b.writeln('  });');
      }
      b.writeln();
      if (realProps.isEmpty) {
        // Empty variant: no fields to decode, the json parameter is
        // unused. Suppress the lint because the signature is dictated
        // by the parent union's dispatch, not by the implementation.
        b.writeln(
          '  // ignore: avoid_unused_constructor_parameters',
        );
      }
      b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
      if (realProps.isEmpty) {
        b.writeln('    return const $className();');
      } else {
        b.writeln('    return $className(');
        for (final entry in realProps) {
          final fieldName = entry.key;
          final isRequired = required.contains(fieldName);
          final propSch = entry.value as Map<String, dynamic>;
          b.writeln('      ${_decodeField(fieldName, propSch, isRequired)},');
        }
        b.writeln('    );');
      }
      b.writeln('  }');
      b.writeln();
      b.writeln('  @override');
      b.writeln('  dynamic toJson() {');
      b.writeln('    return <String, dynamic>{');
      for (final entry in props.entries) {
        final fieldName = entry.key;
        final literal = literals[fieldName];
        if (literal != null) {
          b.writeln('      ${_safeKey(fieldName)}: ${jsonEncode(literal)},');
          continue;
        }
        final isRequired = required.contains(fieldName);
        final propSch = entry.value as Map<String, dynamic>;
        // Delegate to _encodeField so that typed model fields
        // (e.g. `PermissionRuleConfig`) get their `.toJson()` called
        // — emitting the raw field would leave Dart class instances
        // in the map and crash `jsonEncode` on the consumer side.
        b.writeln('      ${_encodeField(fieldName, propSch, isNullable: !isRequired)},');
      }
      b.writeln('    };');
      b.writeln('  }');
      b.writeln();
      for (final entry in props.entries) {
        if (literals.containsKey(entry.key)) continue;
        final fieldName = entry.key;
        final safeName = _safeIdentifier(fieldName);
        final propSch = entry.value as Map<String, dynamic>;
        final isRequired = required.contains(fieldName);
        final isNullable = _isNullableSchema(propSch);
        final dartType = _dartTypeForInline(propSch);
        // Optional fields need a `?` so callers can assign `null`
        // to them — even when the underlying schema does not
        // explicitly allow null. The required check below is
        // consistent with the existing `_emitObject` rule.
        final nullableMark = (isRequired && !isNullable) ? '' : '?';
        b.writeln('  final $dartType$nullableMark $safeName;');
      }
      b.writeln('}');
      return b.toString();
    }
    // Fallback: emit an opaque Map wrapper.
    b.writeln('class $className implements $unionName {');
    b.writeln('  const $className(this.json);');
    b.writeln('  factory $className.fromJson(Map<String, dynamic> json) {');
    b.writeln('    return $className(json);');
    b.writeln('  }');
    b.writeln('  @override');
    b.writeln('  Map<String, dynamic> toJson() => json;');
    b.writeln('  final Map<String, dynamic> json;');
    b.writeln('}');
    return b.toString();
  }

  String _emitObject() {
    final b = StringBuffer();

    final properties =
        (schema['properties'] as Map<String, dynamic>?) ?? const {};

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
        return _emitMapWrapper(b, ap);
      }
    }
    final required =
        ((schema['required'] as List?) ?? const []).cast<String>();

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
        final sch = entry.value as Map<String, dynamic>?;
        if (sch == null) continue;
        if (sch['type'] != 'string') continue;
        final vals = sch['enum'];
        if (vals is! List || vals.length != 1) continue;
        literals[entry.key] = vals.first as String;
      }
    }

    b.writeln(implementsClass != null
        ? 'class $name implements $implementsClass {'
        : 'class $name {');
    // A class becomes empty (no constructor params) when it has no
    // properties at all OR every property is a literal discriminator.
    final realProps =
        properties.entries.where((e) => !literals.containsKey(e.key)).toList();
    if (realProps.isEmpty) {
      // Empty class: `const Name({});` is a Dart parse error (empty `{}`
      // parameter list). Use `()` instead.
      b.writeln('  const $name();');
    } else {
      b.writeln('  const $name({');
      for (final entry in realProps) {
        final fieldName = entry.key;
        final safeName = _safeIdentifier(fieldName);
        final isRequired = required.contains(fieldName);
        // A field is a `required` constructor param whenever the schema marks
        // it as required, even when the type is nullable. The `required`
        // keyword in Dart means the caller must provide the argument; a
        // nullable type simply allows passing `null`.
        if (isRequired) {
          b.writeln('    required this.$safeName,');
        } else {
          b.writeln('    this.$safeName,');
        }
      }
      b.writeln('  });');
    }
    b.writeln();

    // fromJson
    if (realProps.isEmpty) {
      // Empty object: use `const` to satisfy `prefer_const_constructors`.
      // The OpenAPI spec defines this schema as `{}` with no modeled
      // fields, so the API may legitimately return additional
      // properties we discard. Suppress the unused-parameter lint
      // because the parameter exists only to satisfy the `fromJson`
      // contract callers expect.
      b.writeln(
        '  // ignore: avoid_unused_constructor_parameters',
      );
      b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
      b.writeln('    return const $name();');
      b.writeln('  }');
    } else {
      b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
      b.writeln('    return $name(');
      for (final entry in properties.entries) {
        if (literals.containsKey(entry.key)) continue;
        final fieldName = entry.key;
        final isRequired = required.contains(fieldName);
        final sch = entry.value as Map<String, dynamic>;
        b.writeln(
          '      ${_decodeField(fieldName, sch, isRequired)},',
        );
      }
      b.writeln('    );');
      b.writeln('  }');
    }
    b.writeln();
    b.writeln();

    // toJson
    if (implementsClass != null) {
      b.writeln('  @override');
    }
    b.writeln('  Map<String, dynamic> toJson() {');
    b.writeln('    return <String, dynamic>{');
    for (final entry in properties.entries) {
      final fieldName = entry.key;
      final literal = literals[fieldName];
      if (literal != null) {
        // Discriminator / constant: emit the literal value the class
        // is supposed to carry, not a field reference.
        b.writeln('      ${_safeKey(fieldName)}: ${jsonEncode(literal)},');
        continue;
      }
      final sch = entry.value as Map<String, dynamic>;
      final isRequired = required.contains(fieldName);
      final isNullable = _isNullableSchema(sch) || !isRequired;
      b.writeln('      ${_encodeField(fieldName, sch, isNullable: isNullable)},');
    }
    b.writeln('    };');
    b.writeln('  }');
    b.writeln();

    // Fields
    for (final entry in properties.entries) {
      if (literals.containsKey(entry.key)) continue;
      final fieldName = entry.key;
      final safeName = _safeIdentifier(fieldName);
      final sch = entry.value as Map<String, dynamic>;
      final isRequired = required.contains(fieldName);
      final isNullable = _isNullableSchema(sch);
      final dartType = _dartTypeForInline(sch);
      // `Object` is non-nullable — optional fields need `?` appended.
      final isNonNull = isRequired && !isNullable;
      final finalType = isNonNull ? dartType : '$dartType?';
      b.writeln('  final $finalType $safeName;');
    }
    b.writeln('}');

    // Emit any inline enums we collected.
    for (final ie in _inlineEnums) {
      b.writeln();
      b.writeln(ie.emit());
    }

    return b.toString();
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
    final valueDart = _dartTypeForInline(ap);
    final isPrimitive = _isInlinePrimitive(valueDart);
    final isNullable = _isNullableSchema(ap);
    final valueType = isNullable ? '$valueDart?' : valueDart;

    b.writeln(implementsClass != null
        ? 'class $name implements $implementsClass {'
        : 'class $name {');
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
      final isRefStringEnum = refSchema != null &&
          refSchema['type'] == 'string' &&
          refSchema['enum'] is List;
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
      decodeExpr = cast.isEmpty
          ? '$valueDart.fromJson(v as Object)'
          : '$valueDart.fromJson(v as $cast)';
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
    } else if (ap[r'$ref'] is String) {
      b.writeln(
        '    return value.map((k, v) => MapEntry(k, v.toJson()));',
      );
    } else {
      b.writeln('    return Map<String, dynamic>.from(value);');
    }
    b.writeln('  }');
    b.writeln('}');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Field encoders / decoders
  // -------------------------------------------------------------------------

  String _dartTypeForInline(Map<String, dynamic> sch) {
    final r = sch[r'$ref'];
    if (r is String) {
      return _pascalFromSnake(_schemaNameFromRef(r));
    }
    final type = sch['type'];
    final format = sch['format'];
    if (type == 'string') {
      if (format == 'date-time') return 'DateTime';
      if (format == 'uri' || format == 'url') return 'Uri';
      // Inline enum — use String (avoid generating enum classes that may
      // collide with top-level types or have invalid Dart identifiers).
      return 'String';
    }
    if (type == 'integer') return 'int';
    if (type == 'number') return 'double';
    if (type == 'boolean') return 'bool';
    if (type == 'array') {
      final items = sch['items'];
      if (items is Map<String, dynamic>) {
        return 'List<${_dartTypeForInline(items)}>';
      }
      return 'List<dynamic>';
    }
    if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return 'Map<String, ${_dartTypeForInline(ap)}>';
      }
      if (ap == true) return 'Map<String, dynamic>';
      return 'Map<String, dynamic>';
    }
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      // null + T -> T?
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeForInline(nonNull.first);
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

  String _decodeField(String name, Map<String, dynamic> sch, bool isRequired) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final isNullable = _isNullableSchema(sch) || !isRequired;
    final r = sch[r'$ref'];
    if (r is String) {
      final refName = _schemaNameFromRef(r);
      final refType = _pascalFromSnake(refName);
      // Look up the referenced schema to determine its shape (object, array,
      // or string enum).
      final refSchema = schemas[refName] as Map<String, dynamic>?;
      final isRefArray = refSchema != null && refSchema['type'] == 'array';
      final isRefStringEnum = refSchema != null &&
          refSchema['type'] == 'string' &&
          refSchema['enum'] is List;
      if (isRefArray) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as List<dynamic>)';
        }
        return '$safeName: $refType.fromJson(json[$keyExpr] as List<dynamic>)';
      }
      if (isRefStringEnum) {
        if (isNullable) {
          return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as String)';
        }
        return '$safeName: $refType.fromJson(json[$keyExpr] as String)';
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
        return '$safeName: $refType.fromJson(json[$keyExpr] as Object)';
      }
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : $refType.fromJson(json[$keyExpr] as Map<String, dynamic>)';
      }
      return '$safeName: $refType.fromJson(json[$keyExpr] as Map<String, dynamic>)';
    }
    // anyOf [T, null] → T? (and T? in any case since one branch is null)
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _decodeField(name, nonNull.first, false);
      }
    }
    final type = sch['type'];
    if (type == 'string' && sch['format'] == 'date-time') {
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : DateTime.parse(json[$keyExpr] as String)';
      }
      return '$safeName: DateTime.parse(json[$keyExpr] as String)';
    }
    if (type == 'string' && (sch['format'] == 'uri' || sch['format'] == 'url')) {
      if (isNullable) {
        return '$safeName: json[$keyExpr] == null ? null : Uri.parse(json[$keyExpr] as String)';
      }
      return '$safeName: Uri.parse(json[$keyExpr] as String)';
    }
    if (type == 'string' && sch['enum'] is List) {
      // Inline enums use plain String; no separate enum class.
      if (isNullable) {
        return '$safeName: json[$keyExpr] as String?';
      }
      return '$safeName: json[$keyExpr] as String';
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
          return '$safeName: (json[$keyExpr] as List<dynamic>).map((e) => $refType.fromJson(e as $elementCast)).toList()';
        }
        final innerDart = _dartTypeForInline(items);
        if (isNullable) {
          return '$safeName: (json[$keyExpr] as List<dynamic>?)?.cast<$innerDart>()';
        }
        return '$safeName: (json[$keyExpr] as List<dynamic>).cast<$innerDart>()';
      }
    }
    if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        final valueDart = _dartTypeForInline(ap);
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
            return "$safeName: (json[$keyExpr] as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v as List<dynamic>)))";
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
          return "$safeName: (json[$keyExpr] as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v$vCast)))";
        }
        if (isNullable) {
          return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as $valueDart))";
        }
        return "$safeName: (json[$keyExpr] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as $valueDart))";
      }
      if (isNullable) {
        return "$safeName: json[$keyExpr] as Map<String, dynamic>?";
      }
      return "$safeName: json[$keyExpr] as Map<String, dynamic>";
    }
    if (type == 'number') {
      // OpenAPI `number` is JSON `num`. Servers may send either an int or
      // a double for the same field, so accept both and normalize via
      // `toDouble()` rather than crashing on `as double?`.
      if (isNullable) {
        return '$safeName: (json[$keyExpr] as num?)?.toDouble()';
      }
      return '$safeName: (json[$keyExpr] as num).toDouble()';
    }
    if (type == 'integer') {
      // jsonDecode may parse `5.0` as a double even when the schema
      // declares the field as integer, so normalise via `toInt()`.
      if (isNullable) {
        return '$safeName: (json[$keyExpr] as num?)?.toInt()';
      }
      return '$safeName: (json[$keyExpr] as num).toInt()';
    }
    if (type == 'boolean' || type == 'string') {
      final dartType = _dartTypeForInline(sch);
      if (isNullable) {
        return '$safeName: json[$keyExpr] as $dartType?';
      }
      return '$safeName: json[$keyExpr] as $dartType';
    }
    final fallbackDartType = _dartTypeForInline(sch);
    if (fallbackDartType == 'Object') {
      if (isNullable) {
        return '$safeName: json[$keyExpr] as Object?';
      }
      return '$safeName: json[$keyExpr] as Object';
    }
    return '$safeName: json[$keyExpr]';
  }

  String _encodeField(String name, Map<String, dynamic> sch, {required bool isNullable}) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final callOp = isNullable ? '?' : '';
    final entryOp = isNullable ? '?' : '';
    // anyOf [T, null] → T? — delegate to the non-null branch.
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _encodeField(name, nonNull.first, isNullable: true);
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
      if (items is Map<String, dynamic> && items[r'$ref'] is String) {
        // List of generated model objects. `jsonEncode` cannot encode
        // Dart class instances directly — map each element through
        // its `toJson()` so the encoder sees plain maps.
        return '$keyExpr: $entryOp$safeName$callOp.map((e) => e.toJson()).toList()';
      }
    }
    if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic> && ap[r'$ref'] is String) {
        // Map of generated model objects. Same constraint as
        // arrays: jsonEncode needs plain maps, not model instances.
        return '$keyExpr: $entryOp$safeName$callOp.map((k, v) => MapEntry(k, v.toJson()))';
      }
    }
    // Inline enums (and any other string fields) just use the raw value.
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

  String? _discriminatorValue(
      String variantName, Map<String, dynamic> schemas, String? discName) {
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
  String? _inlineDiscriminatorValue(
      Map<String, dynamic> variant, String discName) {
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
      final inlineName = '${_safeIdentifier(name)}${inlineIndex.toString().padLeft(2, '0')}Inline';
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
    final inlineName = '${_safeIdentifier(name)}${inlineIndex.toString().padLeft(2, '0')}Inline';
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

/// An enum class synthesized for an inline enum in a property.
class InlineEnum {
  InlineEnum({required this.className, required this.values});
  final String className;
  final List<String> values;

  String emit() {
    final b = StringBuffer();
    b.writeln('enum $className {');
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('  @JsonValue(${jsonEncode(v)})');
      b.writeln('  $memberName,');
    }
    b.writeln('  ;');
    b.writeln();
    b.writeln('  static $className fromJson(String value) {');
    b.writeln('    switch (value) {');
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('      case ${jsonEncode(v)}:');
      b.writeln('        return $className.$memberName;');
    }
    b.writeln('      default:');
    b.writeln("        throw FormatException('Unknown $className value: \$value');");
    b.writeln('    }');
    b.writeln('  }');
    b.writeln();
    b.writeln('  String toJson() {');
    b.writeln('    switch (this) {');
    for (final v in values) {
      final memberName = _camelFromSnake(v);
      b.writeln('      case $className.$memberName:');
      b.writeln('        return ${jsonEncode(v)};');
    }
    b.writeln('    }');
    b.writeln('  }');
    b.writeln('}');
    return b.toString();
  }
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

  // Split on underscores, dashes, and dots.
  final parts = s.split(RegExp(r'[_\-.]+'));
  final out = StringBuffer();
  for (final p in parts) {
    if (p.isEmpty) continue;
    if (_isAllUpper(p)) {
      out.write(p);
    } else {
      // CamelCase split: insert boundary before each uppercase.
      final split = p.split(RegExp('(?=[A-Z])'));
      out.write(split
          .map((seg) => seg.isEmpty ? '' : seg[0].toUpperCase() + seg.substring(1))
          .join());
    }
  }
  final pascal = out.toString();
  // When the raw name contained a dot, `_pascalFromSnake` collapses the
  // two sides into the same identifier as a sibling that uses an
  // underscore. Append a short stable hash of the raw name so both
  // siblings stay distinct without leaking the original dots into
  // identifiers (Dart identifiers may not contain `.`).
  if (name.contains('.')) {
    return '$pascal${_hashSuffix(name)}';
  }
  return pascal;
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
  return withUnderscores.replaceAll('-', '_').toLowerCase();
}

const _dartReservedWords = {
  'abstract', 'as', 'assert', 'async', 'await', 'break', 'case', 'catch',
  'class', 'const', 'continue', 'covariant', 'default', 'deferred', 'do',
  'dynamic', 'else', 'enum', 'export', 'extends', 'extension', 'external',
  'factory', 'false', 'final', 'finally', 'for', 'Function', 'get', 'hide',
  'if', 'implements', 'import', 'in', 'interface', 'is', 'late', 'library',
  'mixin', 'new', 'null', 'on', 'operator', 'part', 'required', 'rethrow',
  'return', 'sealed', 'show', 'static', 'super', 'switch', 'sync', 'this',
  'throw', 'true', 'try', 'typedef', 'var', 'void', 'when', 'while',
  'with', 'yield',
};

/// Returns `name` quoted with backticks if it would otherwise collide with
/// a Dart reserved word, or stripped of a leading underscore (which would
/// otherwise require the experimental `private-named-parameters` feature).
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
    return '`$s`';
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
