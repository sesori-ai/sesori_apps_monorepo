import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/permission_api.dart";
import "package:sesori_dart_core/src/repositories/permission_repository.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockPermissionApi() extends Mock implements PermissionApi;

void main() {
  late _MockPermissionApi api;
  late PermissionRepository repository;

  setUpAll(() => registerFallbackValue(PermissionReply.once));

  setUp(() {
    api = _MockPermissionApi();
    repository = PermissionRepository(api: api);
  });

  void stubReply(ApiResponse<void> response) => when(
    () => api.replyToPermission(
      requestId: any(named: "requestId"),
      sessionId: any(named: "sessionId"),
      reply: any(named: "reply"),
    ),
  ).thenAnswer((_) async => response);

  Future<ApiResponse<void>> reply() =>
      repository.replyToPermission(requestId: "perm-1", sessionId: "session-1", reply: PermissionReply.once);

  test("a 409 is an answered request the bridge could not apply, not a failure", () async {
    stubReply(
      ApiResponse.error(
        ApiError.nonSuccessCode(
          errorCode: 409,
          rawErrorString: "The task changed since this was proposed, so nothing was applied.",
        ),
      ),
    );

    expect(await reply(), isA<SuccessResponse<void>>());
  });

  test("a 404 is a request no longer pending, for example answered elsewhere, not a failure", () async {
    stubReply(ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "Permission not found")));

    expect(await reply(), isA<SuccessResponse<void>>());
  });

  test("any other error stays a failure", () async {
    final error = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: null);
    stubReply(ApiResponse.error(error));

    expect(await reply(), isA<ErrorResponse<void>>().having((response) => response.error, "error", error));
  });
}
