import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  late MockFilesystemApi api;
  late FilePreviewRepository repository;

  setUp(() {
    api = MockFilesystemApi();
    repository = FilePreviewRepository(api: api);
  });

  void answer(ApiResponse<FilePreviewResponse> response) =>
      when(() => api.readFilePreview(path: "/a/b.txt")).thenAnswer((_) async => response);

  test("passes the bridge's outcome through", () async {
    answer(ApiResponse.success(const FilePreviewResponse.missing()));

    final result = await repository.load(path: "/a/b.txt");

    expect(result, isA<FilePreviewLoaded>().having((r) => r.response, "response", const FilePreviewResponse.missing()));
  });

  test("reads a 404 as a bridge without the route", () async {
    answer(ApiResponse.error(ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "no handler found")));

    expect(await repository.load(path: "/a/b.txt"), isA<FilePreviewBridgeTooOld>());
  });

  test("keeps any other failure", () async {
    final error = ApiError.nonSuccessCode(errorCode: 500, rawErrorString: "boom");
    answer(ApiResponse.error(error));

    expect(
      await repository.load(path: "/a/b.txt"),
      isA<FilePreviewFailed>().having((r) => r.innerError, "innerError", error),
    );
  });
}
