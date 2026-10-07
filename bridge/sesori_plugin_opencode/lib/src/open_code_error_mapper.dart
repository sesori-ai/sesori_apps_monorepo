/// The name and message of an OpenCode message error.
///
/// OpenCode's structured errors are `{ "name": ..., "data": { "message": ... } }`,
/// but `error` is typed `Object?`, so a non-map payload (e.g. a bare string)
/// is possible. Never let a present error fall through as a plain assistant
/// message — that is exactly the silent error loss the assistant message
/// mapper exists to prevent — so fall back to `toString()` for a non-map error.
({String name, String errorMessage}) openCodeError({required Object error}) {
  final errorMap = error is Map<String, dynamic> ? error : null;
  final data = errorMap?["data"];
  final dataMap = data is Map<String, dynamic> ? data : const <String, dynamic>{};
  return (
    name: errorMap?["name"]?.toString() ?? "UnknownError",
    errorMessage: dataMap["message"]?.toString() ?? (errorMap == null ? error.toString() : "Unknown error"),
  );
}
