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
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  });

  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    try {
      final result = await handle(
        request,
        pathParams: pathParams,
        queryParams: queryParams,
        fragment: fragment,
      );

      return buildOkJsonResponse(request, result);
    } on ProjectNotFoundException {
      return buildErrorResponse(request, 404, "project not found");
    } on SessionArchivedReadOnlyException catch (err) {
      return buildArchivedRejectionResponse(request, err.rejection);
    } on PluginOperationException catch (err, stackTrace) {
      Log.w("${request.method} ${request.path}: upstream failure", err, stackTrace);
      return buildErrorResponse(request, err.statusCode ?? 502, err.toString());
    } on RelayResponse catch (err) {
      if (err.status >= 200 && err.status < 300) {
        // we don't expect to throw success responses from handleBody
        // -- so we'll treat this as an internal server error
        throw buildErrorResponse(request, 500, "Internal Server Error: threw success response");
      } else {
        // just return the error response
        return err;
      }
    } catch (err, stackTrace) {
      Log.w("${request.method} ${request.path}: handler failed", err, stackTrace);
      return buildErrorResponse(request, 500, "Internal Server Error: $err");
    }
  }
}

abstract class BodyRequestHandler<REQ, RES extends Object>(
  super.method,
  super.path, {
  required final REQ Function(Map<String, dynamic> json) _fromJson,
}) extends RequestHandlerBase {
  @override
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
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
    try {
      final result = await handle(
        request,
        body: bodyParsed,
        pathParams: pathParams,
        queryParams: queryParams,
        fragment: fragment,
      );

      return buildOkJsonResponse(request, result);
    } on ProjectNotFoundException {
      return buildErrorResponse(request, 404, "project not found");
    } on SessionArchivedReadOnlyException catch (err) {
      return buildArchivedRejectionResponse(request, err.rejection);
    } on StaleSessionPromptOptionsException catch (err) {
      // The client only learns the opaque code, so this is the sole place that
      // retains which plugin operation rejected the selection and where.
      Log.w("${request.method} ${request.path}: stale session options", err.cause, err.causeStackTrace);
      return buildStaleOptionsRejectionResponse(request, err.message);
    } on PluginOperationException catch (err, stackTrace) {
      Log.w("${request.method} ${request.path}: upstream failure", err, stackTrace);
      return buildErrorResponse(request, err.statusCode ?? 502, err.toString());
    } on RelayResponse catch (err) {
      if (err.status >= 200 && err.status < 300) {
        // we don't expect to throw success responses from handleBody
        // -- so we'll treat this as an internal server error
        throw buildErrorResponse(request, 500, "Internal Server Error: threw success response");
      } else {
        // just return the error response
        return err;
      }
    } catch (err, stackTrace) {
      Log.w("${request.method} ${request.path}: handler failed", err, stackTrace);
      return buildErrorResponse(request, 500, "Internal Server Error: $err");
    }
  }

  Future<RES> handle(
    RelayRequest request, {
    required REQ body,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  });
}

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
    String? fragment,
  })
  extractTargetParams({required Uri target}) {
    final uri = target;
    final pathParams = path == "*" ? <String, String>{} : (_matchPathParams(uri.path, path) ?? {});
    final queryParams = Map<String, String>.from(uri.queryParameters);
    final fragment = uri.fragment.isEmpty ? null : uri.fragment;
    return (pathParams: pathParams, queryParams: queryParams, fragment: fragment);
  }

  // ── Handler contract ────────────────────────────────────────────────────────

  /// Produces a [RelayResponse] for [request].
  ///
  /// Only called when [matches] returned `true` for the same request.
  ///
  /// - [pathParams] — values extracted from `:param` placeholders in [path],
  ///   e.g. `"/session/:id/message"` yields `{"id": "abc"}`.
  /// - [queryParams] — key/value pairs from the query string.
  /// - [fragment] — URL fragment (`#…`), or `null` if absent.
  Future<RelayResponse> handleInternal(
    RelayRequest request, {
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  });

  Future<RoutedRequestOutcome> routeInternal({
    required RelayRequest request,
    required Map<String, String> pathParams,
    required Map<String, String> queryParams,
    required String? fragment,
  }) async {
    return ResponseOnly(
      response: await handleInternal(
        request,
        pathParams: pathParams,
        queryParams: queryParams,
        fragment: fragment,
      ),
    );
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
  RelayResponse buildOkJsonResponse(RelayRequest request, Object body) => RelayResponse(
    id: request.id,
    status: 200,
    headers: {"content-type": "application/json"},
    body: jsonEncode(body),
  );

  /// Builds the 409 response every archived-session refusal shares.
  RelayResponse buildArchivedRejectionResponse(
    RelayRequest request,
    SessionArchivedRejection rejection,
  ) => RelayResponse(
    id: request.id,
    status: 409,
    headers: {"content-type": "application/json"},
    body: jsonEncode(rejection.toJson()),
  );

  /// Builds the 409 response telling the client its session options selection
  /// (agent, model, or variant) is no longer offered and must be refreshed
  /// before resending.
  RelayResponse buildStaleOptionsRejectionResponse(RelayRequest request, String? message) => RelayResponse(
    id: request.id,
    status: 409,
    headers: {"content-type": "application/json"},
    body: jsonEncode(
      SendPromptErrorResponse(code: SendPromptErrorCode.staleSessionOptions, message: message).toJson(),
    ),
  );

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
