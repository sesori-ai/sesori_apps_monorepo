import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/models/project_not_found_exception.dart";
import "../services/archived_session_validator.dart";
import "../services/stale_session_prompt_options_exception.dart";
import "http_method.dart";
import "routed_request.dart";

export "http_method.dart";

abstract class GetRequestHandler<RES extends Object>(
  String path,
) extends RequestHandlerBase {
  this : super(HttpMethod.get, path);

  Future<RES> handle(
    RelayRequest request,
  );

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    final result = await handle(request);
    return buildOkJsonResponse(request: request, body: result);
  }
}

abstract class _BodyRequestHandlerBase<REQ, RES extends Object>(
  super.method,
  super.path, {
  required final REQ Function(Map<String, dynamic> json) _fromJson,
}) extends RequestHandlerBase {
  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  }) async {
    final body = request.body;
    if (body == null) {
      return buildErrorResponse(request, 400, "Bad Request: missing JSON body");
    }
    final Map<String, dynamic>? decoded;
    try {
      decoded = jsonDecodeMap(body);
    } catch (_) {
      return buildErrorResponse(request, 400, "Bad Request: malformed JSON");
    }
    final REQ bodyParsed;
    try {
      bodyParsed = _fromJson(decoded);
    } catch (err) {
      return buildErrorResponse(request, 400, "Bad Request: invalid JSON body: $err");
    }
    final result = await handleParsed(request, body: bodyParsed, targetParams: targetParams);
    return buildOkJsonResponse(request: request, body: result);
  }

  Future<RES> handleParsed(
    RelayRequest request, {
    required REQ body,
    required RequestTargetParams targetParams,
  });
}

abstract class BodyRequestHandler<REQ, RES extends Object>(
  super.method,
  super.path, {
  required super.fromJson,
}) extends _BodyRequestHandlerBase<REQ, RES> {
  @override
  Future<RES> handleParsed(
    RelayRequest request, {
    required REQ body,
    required RequestTargetParams targetParams,
  }) => handle(request, body: body);

  Future<RES> handle(
    RelayRequest request, {
    required REQ body,
  });
}

abstract class TargetBodyRequestHandler<REQ, RES extends Object>(
  super.method,
  super.path, {
  required super.fromJson,
}) extends _BodyRequestHandlerBase<REQ, RES> {
  @override
  Future<RES> handleParsed(
    RelayRequest request, {
    required REQ body,
    required RequestTargetParams targetParams,
  }) => handle(
    request,
    body: body,
    pathParams: targetParams.pathParams,
  );

  Future<RES> handle(
    RelayRequest request, {
    required REQ body,
    required Map<String, String> pathParams,
  });
}

typedef RequestTargetParams = ({Map<String, String> pathParams, Map<String, String> queryParams});

/// A single interceptor in the request routing chain.
///
/// Subclasses declare their [method] and [path] pattern in the constructor.
/// [RequestRouter] compares the parsed request method and target against
/// [method] and [path], resolving `:param` placeholders automatically.
///
/// Example:
/// ```dart
/// class GetSessionMessagesHandler extends RequestHandler {
///   GetSessionMessagesHandler(this._plugin)
///       : super(HttpMethod.get, "/session/:id/message");
/// }
/// ```
abstract class const RequestHandlerBase(
  /// HTTP method this handler responds to.
  final HttpMethod method,

  /// URL path pattern, optionally containing `:param` placeholders.
  /// Use `"*"` to match any path (catch-all).
  ///
  /// Examples: `"/project"`, `"/session/:id/message"`.
  final String path,
) {
  String get diagnosticLabel => "${method.diagnosticLabel} $path";

  // ── Matching ────────────────────────────────────────────────────────────────

  /// Matches the router's parsed method and target against this declaration.
  bool matches({required HttpMethod requestMethod, required Uri target}) {
    if (!method.matches(requestMethod: requestMethod)) return false;
    if (path == "*") return true;
    return _matchPathParams(target.path, path) != null;
  }

  /// Extracts route values from the target parsed once by [RequestRouter].
  ({
    Map<String, String> pathParams,
    Map<String, String> queryParams,
  })
  extractTargetParams({required Uri target}) {
    final uri = target;
    final pathParams = path == "*" ? <String, String>{} : (_matchPathParams(uri.path, path) ?? {});
    final queryParams = Map<String, String>.from(uri.queryParameters);
    return (pathParams: pathParams, queryParams: queryParams);
  }

  // ── Handler contract ────────────────────────────────────────────────────────

  /// Produces a [RelayResponse] for [request].
  ///
  /// Only called when [matches] returned `true` for the same request.
  ///
  /// [targetParams] contains values extracted from `:param` placeholders in
  /// [path] and key/value pairs from the query string.
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required RequestTargetParams targetParams,
  });

  Future<RoutedRequestOutcome> routeInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) => _guard(
    request: request,
    operation: () => handleRouteInternal(request: request, targetParams: targetParams),
  );

  Future<RoutedRequestOutcome> handleRouteInternal({
    required RelayRequest request,
    required RequestTargetParams targetParams,
  }) async => ResponseOnly(
    response: await handleInternal(request, targetParams: targetParams),
  );

  Future<RoutedRequestOutcome> _guard({
    required RelayRequest request,
    required Future<RoutedRequestOutcome> Function() operation,
  }) async {
    try {
      return await operation();
    } on ProjectNotFoundException {
      return ResponseOnly(response: buildErrorResponse(request, 404, "project not found"));
    } on SessionArchivedReadOnlyException catch (error) {
      return ResponseOnly(
        response: buildArchivedRejectionResponse(request: request, rejection: error.rejection),
      );
    } on StaleSessionPromptOptionsException catch (error) {
      Log.w("${request.method} ${request.path}: stale session options", error.cause, error.causeStackTrace);
      return ResponseOnly(
        response: buildStaleOptionsRejectionResponse(request: request, message: error.message),
      );
    } on PluginOperationException catch (error, stackTrace) {
      Log.w("${request.method} ${request.path}: upstream failure", error, stackTrace);
      return ResponseOnly(response: buildErrorResponse(request, error.statusCode ?? 502, error.toString()));
    } on RelayResponse catch (error, stackTrace) {
      if (error.status < 200 || error.status >= 300) return ResponseOnly(response: error);
      Log.w("${request.method} ${request.path}: handler threw success response", error, stackTrace);
      return ResponseOnly(
        response: buildErrorResponse(request, 500, "Internal Server Error: threw success response"),
      );
    } on Object catch (error, stackTrace) {
      Log.w("${request.method} ${request.path}: handler failed", error, stackTrace);
      return ResponseOnly(response: buildErrorResponse(request, 500, "Internal Server Error: $error"));
    }
  }

  // ── Shared helpers ──────────────────────────────────────────────────────────

  /// Case-insensitive header lookup.
  String? findHeader(Map<String, String> headers, String key) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == key.toLowerCase()) return entry.value;
    }
    return null;
  }

  /// Builds a 200 JSON response.
  RelayResponse buildOkJsonResponse({required RelayRequest request, required Object body}) => RelayResponse(
    id: request.id,
    status: 200,
    headers: {"content-type": "application/json"},
    body: jsonEncode(body),
  );

  RelayResponse buildJsonErrorResponse({required RelayRequest request, required int status, required Object body}) =>
      RelayResponse(
        id: request.id,
        status: status,
        headers: {"content-type": "application/json"},
        body: jsonEncode(body),
      );

  /// Builds the 409 response every archived-session refusal shares.
  RelayResponse buildArchivedRejectionResponse({
    required RelayRequest request,
    required SessionArchivedRejection rejection,
  }) => buildJsonErrorResponse(request: request, status: 409, body: rejection.toJson());

  /// Builds the 409 response telling the client its session options selection
  /// (agent, model, or variant) is no longer offered and must be refreshed
  /// before resending.
  RelayResponse buildStaleOptionsRejectionResponse({required RelayRequest request, required String? message}) =>
      buildJsonErrorResponse(
        request: request,
        status: 409,
        body: SendPromptErrorResponse(code: SendPromptErrorCode.staleSessionOptions, message: message).toJson(),
      );

  String requireNonEmpty({required RelayRequest request, required String value, required String label}) {
    if (value.isEmpty) throw buildErrorResponse(request, 400, "empty $label");
    return value;
  }

  /// Builds an error response with the given [status] and plain-text [message].
  RelayResponse buildErrorResponse(
    RelayRequest request,
    int status,
    String message,
  ) => RelayResponse(
    id: request.id,
    status: status,
    headers: {},
    body: message,
  );

  // ── Path matching internals ─────────────────────────────────────────────────

  /// Matches [requestPath] against [pattern], returning extracted params or
  /// `null` when there is no match.
  ///
  /// Pattern segments starting with `:` are named placeholders that match any
  /// single path segment and capture its value.
  ///
  /// Example: `_matchPathParams("/session/abc/message", "/session/:id/message")`
  /// → `{"id": "abc"}`.
  static Map<String, String>? _matchPathParams(
    String requestPath,
    String pattern,
  ) {
    final patternSegs = pattern.split("/").where((s) => s.isNotEmpty).toList();
    final requestSegs = requestPath.split("/").where((s) => s.isNotEmpty).toList();

    if (patternSegs.length != requestSegs.length) return null;

    final params = <String, String>{};
    for (var i = 0; i < patternSegs.length; i++) {
      final pSeg = patternSegs[i];
      final rSeg = requestSegs[i];
      if (pSeg.startsWith(":")) {
        params[pSeg.substring(1)] = rSeg;
      } else if (pSeg != rSeg) {
        return null;
      }
    }
    return params;
  }
}
