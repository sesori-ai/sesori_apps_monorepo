// GENERATED FILE - DO NOT EDIT BY HAND
//
// Usage:
//   dart run tool/generate_opencode_client.dart [path/to/openapi.json] [output/dir]
//
// Defaults:
//   spec:    /Users/alexandrudochioiu/sesori-ai/opencode/packages/sdk/openapi.json
//   outDir:  lib/src
//
// This script consumes an OpenAPI 3.1 JSON document (OpenCode's `packages/sdk/openapi.json`)
// and emits, relative to outDir:
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

Future<void> main(List<String> args) async {
  final specPath = args.isNotEmpty
      ? args[0]
      : '/Users/alexandrudochioiu/sesori-ai/opencode/packages/sdk/openapi.json';
  final outDir = args.length >= 2 ? args[1] : 'lib/src';
  final verbose = args.contains('--verbose') || args.contains('-v');

  stdout.writeln('Reading OpenAPI spec: $specPath');
  final raw = File(specPath).readAsStringSync();
  final spec = jsonDecode(raw) as Map<String, dynamic>;

  final gen = Codegen(spec: spec, outDir: outDir, verbose: verbose);
  gen.run();
  stdout.writeln('Done. Output: $outDir');
}

class Codegen {
  Codegen({
    required this.spec,
    required this.outDir,
    required this.verbose,
  });

  final Map<String, dynamic> spec;
  final String outDir;
  final bool verbose;

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
          final childRaw = r.substring('#/components/schemas/'.length);
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

  void run() {
    final modelsDir = Directory('$outDir/models/openapi');
    modelsDir.createSync(recursive: true);

    final sortedSchemas = schemas.keys.toList()..sort();
    for (final name in sortedSchemas) {
      final schema = schemas[name] as Map<String, dynamic>;
      _writeModelFile(name, schema);
      log('model $name');
    }

    final apiPath = '$outDir/opencode_client.dart';
    File(apiPath).writeAsStringSync(_emitApiClient());
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
    );
    File('$outDir/$relPath').writeAsStringSync(writer.emit());
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
    b.writeln('//');
    b.writeln('// To regenerate, run:');
    b.writeln('//   dart run tool/generate_opencode_client.dart');
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
      final name = r.substring('#/components/schemas/'.length);
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
      if (p.required) {
        queryParts.add("'${p.name}': ${p.name}.toString()");
      } else {
        queryParts.add("if (${p.name} != null) '${p.name}': ${p.name}.toString()");
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

    b.writeln('    if (resp.statusCode >= 400) {');
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
      final name = r.substring('#/components/schemas/'.length);
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
      return _wrap('List<dynamic>', nullable);
    }
    if (type == 'object') {
      final ap = sch['additionalProperties'];
      if (ap is Map<String, dynamic>) {
        return _wrap('Map<String, ${_dartTypeForSchema(ap, nullable: false)}>', nullable);
      }
      if (ap == true) {
        return _wrap('Map<String, dynamic>', nullable);
      }
      return _wrap('Map<String, dynamic>', nullable);
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
    return _wrap('dynamic', nullable);
  }

  String _wrap(String t, bool nullable) => nullable ? '$t?' : t;

  bool _isPrimitiveType(String t) {
    return t == 'bool' || t == 'int' || t == 'double' || t == 'String' || t == 'DateTime' || t == 'Uri' || t == 'dynamic';
  }

  String _parsePrimitive(String type, String body) {
    if (type == 'bool') return '$body == "true"';
    if (type == 'int') return 'int.parse($body)';
    if (type == 'double') return 'double.parse($body)';
    if (type == 'DateTime') return 'DateTime.parse($body)';
    if (type == 'Uri') return 'Uri.parse($body)';
    if (type == 'dynamic') return 'jsonDecode($body) as dynamic';
    return body;
  }

  /// Used for typed body parameters and response types.
  String _classNameForRef(Map<String, dynamic> ref) {
    final r = ref[r'$ref'] as String;
    final name = r.substring('#/components/schemas/'.length);
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
      out.write(r'$');
      out.write(_safeIdentifier(m.group(1) ?? ''));
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
  String dartType = 'dynamic';
  bool isNoContent = false;

  static String _dartTypeFromSchema(Map<String, dynamic> sch) {
    final r = sch[r'$ref'];
    if (r is String) {
      final name = r.substring('#/components/schemas/'.length);
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
      return 'List<dynamic>';
    }
    if (sch['anyOf'] is List) {
      final variants = (sch['anyOf'] as List).cast<Map<String, dynamic>>();
      final nonNull = variants.where((v) => v['type'] != 'null').toList();
      if (nonNull.length == 1) {
        return _dartTypeFromSchema(nonNull.first);
      }
      return 'dynamic';
    }
    return 'dynamic';
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
        refs.add(s.substring('#/components/schemas/'.length));
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
    // If this is itself a union (anyOf/oneOf at the top level), each
    // variant is referenced in the discriminator switch — but only if a
    // discriminator value can be resolved. Otherwise the switch case is
    // omitted and the variant import would be unused.
    final variants = sch['anyOf'] ?? sch['oneOf'];
    if (variants is List) {
      final disc = _findDiscriminator(variants.cast<Map<String, dynamic>>());
      for (final variant in variants) {
        if (variant is! Map) continue;
        final r = variant[r'$ref'];
        if (r is! String) continue;
        final vName = r.substring('#/components/schemas/'.length);
        if (_discriminatorValue(vName, schemas, disc) != null) {
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
    final innerDart = items != null ? _dartTypeForInline(items) : 'dynamic';
    final innerClass = items != null && items[r'$ref'] is String
        ? _pascalFromSnake((items[r'$ref'] as String).substring('#/components/schemas/'.length))
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
    return t == 'bool' || t == 'int' || t == 'double' || t == 'String' || t == 'DateTime' || t == 'Uri' || t == 'dynamic';
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
    final variantNames = <String>[];

    b.writeln('abstract interface class $name {');
    b.writeln('  const $name();');
    b.writeln();
    b.writeln('  /// Serialize the underlying variant. Variants must override this.');
    b.writeln('  Map<String, dynamic> toJson();');
    b.writeln();
    b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    b.writeln('    final discriminator = json[${jsonEncode(disc ?? 'type')}];');
    b.writeln('    switch (discriminator) {');
    for (final v in variants) {
      final r = v[r'$ref'];
      if (r is String) {
        final vName = r.substring('#/components/schemas/'.length);
        variantNames.add(vName);
        final d = _discriminatorValue(vName, schemas, disc);
        if (d != null) {
          b.writeln('      case ${jsonEncode(d)}:');
          b.writeln('        return ${_pascalFromSnake(vName)}.fromJson(json);');
        }
      } else {
        // Inline variant — skip with a TODO.
        b.writeln('      // inline variant skipped: $name');
      }
    }
    b.writeln('      default:');
    b.writeln("        throw FormatException('Unknown $name value: \$discriminator');");
    b.writeln('    }');
    b.writeln('  }');
    b.writeln('}');
    return b.toString();
  }

  // -------------------------------------------------------------------------
  // Object emission
  // -------------------------------------------------------------------------

  String _emitObject() {
    final b = StringBuffer();

    final properties =
        (schema['properties'] as Map<String, dynamic>?) ?? const {};
    final required =
        ((schema['required'] as List?) ?? const []).cast<String>();

    b.writeln(implementsClass != null
        ? 'class $name implements $implementsClass {'
        : 'class $name {');
    if (properties.isEmpty) {
      // Empty class: `const Name({});` is a Dart parse error (empty `{}`
      // parameter list). Use `()` instead.
      b.writeln('  const $name();');
    } else {
      b.writeln('  const $name({');
      for (final entry in properties.entries) {
        final fieldName = entry.key;
        final safeName = _safeIdentifier(fieldName);
        final sch = entry.value as Map<String, dynamic>;
        final isRequired = required.contains(fieldName);
        final isNullable = _isNullableSchema(sch);
        // A field is a `required` constructor param only when the schema marks
        // it as required AND it does not allow null. If it allows null, the
        // type itself is nullable, so `required` would be a contradiction.
        if (isRequired && !isNullable) {
          b.writeln('    required this.$safeName,');
        } else {
          b.writeln('    this.$safeName,');
        }
      }
      b.writeln('  });');
    }
    b.writeln();

    // fromJson
    b.writeln('  factory $name.fromJson(Map<String, dynamic> json) {');
    if (properties.isEmpty) {
      // Empty object: use `const` to satisfy `prefer_const_constructors`,
      // and assert on `json` to satisfy `avoid_unused_constructor_parameters`.
      b.writeln('    assert(json.isEmpty);');
      b.writeln('    return const $name();');
    } else {
      b.writeln('    return $name(');
      for (final entry in properties.entries) {
        final fieldName = entry.key;
        final isRequired = required.contains(fieldName);
        final sch = entry.value as Map<String, dynamic>;
        b.writeln(
          '      ${_decodeField(fieldName, sch, isRequired)},',
        );
      }
      b.writeln('    );');
    }
    b.writeln('  }');
    b.writeln();

    // toJson
    if (implementsClass != null) {
      b.writeln('  @override');
    }
    b.writeln('  Map<String, dynamic> toJson() {');
    b.writeln('    return <String, dynamic>{');
    for (final entry in properties.entries) {
      final fieldName = entry.key;
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
      final fieldName = entry.key;
      final safeName = _safeIdentifier(fieldName);
      final sch = entry.value as Map<String, dynamic>;
      final isRequired = required.contains(fieldName);
      final isNullable = _isNullableSchema(sch);
      final dartType = _dartTypeForInline(sch);
      // `dynamic` is already nullable — adding `?` is unnecessary.
      final isNonNull = isRequired && !isNullable;
      final finalType = isNonNull
          ? dartType
          : (dartType == 'dynamic' ? 'dynamic' : '$dartType?');
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

  // -------------------------------------------------------------------------
  // Field encoders / decoders
  // -------------------------------------------------------------------------

  String _dartTypeForInline(Map<String, dynamic> sch) {
    final r = sch[r'$ref'];
    if (r is String) {
      return _pascalFromSnake(r.substring('#/components/schemas/'.length));
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
      return 'dynamic';
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
    return 'dynamic';
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

  String _decodeField(String name, Map<String, dynamic> sch, bool isRequired) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final isNullable = _isNullableSchema(sch) || !isRequired;
    final r = sch[r'$ref'];
    if (r is String) {
      final refName = r.substring('#/components/schemas/'.length);
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
          final refName = itemsRef.substring('#/components/schemas/'.length);
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
        // If the value is a $ref to a top-level array schema, the element
        // cast must be `as List<dynamic>` not `as $valueDart`. Detect that.
        if (ap[r'$ref'] is String) {
          final refName = (ap[r'$ref'] as String).substring('#/components/schemas/'.length);
          final refSchema = schemas[refName] as Map<String, dynamic>?;
          if (refSchema != null && refSchema['type'] == 'array') {
            if (isNullable) {
              return "$safeName: (json[$keyExpr] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, $valueDart.fromJson(v as List<dynamic>)))";
            }
            return "$safeName: (json[$keyExpr] as Map<String, dynamic>).map((k, v) => MapEntry(k, $valueDart.fromJson(v as List<dynamic>)))";
          }
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
    if (type == 'integer' || type == 'number' || type == 'boolean' || type == 'string') {
      final dartType = _dartTypeForInline(sch);
      if (isNullable) {
        return '$safeName: json[$keyExpr] as $dartType?';
      }
      return '$safeName: json[$keyExpr] as $dartType';
    }
    return '$safeName: json[$keyExpr]';
  }

  String _encodeField(String name, Map<String, dynamic> sch, {required bool isNullable}) {
    final keyExpr = _safeKey(name);
    final safeName = _safeIdentifier(name);
    final op = isNullable ? '?' : '';
    final r = sch[r'$ref'];
    if (r is String) {
      return '$keyExpr: $safeName$op.toJson()';
    }
    final type = sch['type'];
    if (type == 'string' &&
        (sch['format'] == 'date-time' || sch['format'] == 'uri' || sch['format'] == 'url')) {
      return '$keyExpr: $safeName$op.toIso8601String()';
    }
    // Inline enums (and any other string fields) just use the raw value.
    return '$keyExpr: $safeName';
  }

  // -------------------------------------------------------------------------
  // Discriminator detection
  // -------------------------------------------------------------------------

  String? _findDiscriminator(List<Map<String, dynamic>> variants) {
    final refVariants = <String, Map<String, dynamic>>{};
    for (final v in variants) {
      final r = v[r'$ref'];
      if (r is String) {
        final name = r.substring('#/components/schemas/'.length);
        refVariants[name] = schemas[name] as Map<String, dynamic>;
      }
    }
    if (refVariants.isEmpty) return null;

    for (final candidate in ['type', 'role', 'kind']) {
      var allHave = true;
      for (final schema in refVariants.values) {
        final props = schema['properties'] as Map<String, dynamic>?;
        if (props == null || !props.containsKey(candidate)) {
          allHave = false;
          break;
        }
        final propSchema = props[candidate] as Map<String, dynamic>;
        final enumVals = propSchema['enum'] as List?;
        if (enumVals == null || enumVals.length != 1) {
          allHave = false;
          break;
        }
      }
      if (allHave) return candidate;
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
  return out.toString();
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
