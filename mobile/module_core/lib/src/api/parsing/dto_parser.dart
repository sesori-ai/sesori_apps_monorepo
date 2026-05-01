import "dart:async";

import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonDecodeMap;

import "../../concurrency/impl/isolate/isolate.dart";
import "../../concurrency/worker.dart";
import "../../logging/logging.dart";

/// Parser runs on dedicated isolate for VM to avoid blocking main thread
///
/// On web: we use the main thread (because comms with web workers require data marshalling,
/// which basically means we end up parsing the result on main thread anyways)
@pragma("vm:prefer-inline")
@pragma("wasm:prefer-inline")
@pragma("dart2js:tryInline")
Future<T> _parseJson<T>(String json, ParseJsonTask<T> task) => isolatesPool.run<String, T>(task, json);

class ParseJsonTask<T> implements IsolateTask<String, T> {
  // ignore: no_slop_linter/prefer_specific_type, DTO fromJson signatures accept dynamic JSON maps
  final T Function(Map<String, dynamic> json) fromJson;

  const ParseJsonTask(this.fromJson);

  @override
  FutureOr<T> Function(String arg) get staticFunction =>
      (arg) => fromJson(jsonDecodeMap(arg));
}

class JsonDtoParser {
  JsonDtoParser();

  Future<ApiResponse<T>> parseDto<T>(
    final Uri uri, {
    required final ParseJsonTask<T> parseJsonTask,
    required final int statusCode,
    required final String? jsonData,
  }) async {
    ApiError getApiError() => ApiError.nonSuccessCode(
      errorCode: statusCode,
      rawErrorString: jsonData,
    );

    if (jsonData == null) {
      return ApiResponse.error(getApiError());
    }

    if (statusCode >= 200 && statusCode < 300) {
      try {
        final parsed = await _parseJson<T>(jsonData, parseJsonTask);
        return ApiResponse.success(parsed);
      } on Object catch (e, st) {
        loge("Failed to parse json", e, st);
        return ApiResponse.error(ApiError.jsonParsing(jsonData));
      }
    } else {
      return ApiResponse.error(getApiError());
    }
  }
}
