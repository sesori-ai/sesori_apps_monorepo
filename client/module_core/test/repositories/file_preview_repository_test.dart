import "dart:convert";

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

  test("maps text", () async {
    answer(ApiResponse.success(const FilePreviewResponse.text(content: "# Notes")));

    expect(
      await repository.load(path: "/a/b.txt"),
      isA<FilePreviewTextContent>().having((r) => r.content, "content", "# Notes"),
    );
  });

  test("decodes an image", () async {
    answer(
      ApiResponse.success(
        FilePreviewResponse.image(mime: "image/png", base64: base64Encode([1, 2, 3]), byteLength: 3),
      ),
    );

    expect(
      await repository.load(path: "/a/b.txt"),
      isA<FilePreviewImageContent>()
          .having((r) => r.bytes, "bytes", [1, 2, 3])
          .having((r) => r.mime, "mime", "image/png"),
    );
  });

  test("fails an image that does not decode", () async {
    answer(
      ApiResponse.success(
        const FilePreviewResponse.image(mime: "image/png", base64: "not base64!", byteLength: 3),
      ),
    );

    expect(
      await repository.load(path: "/a/b.txt"),
      isA<FilePreviewFailed>().having((r) => r.innerError, "innerError", isA<FormatException>()),
    );
  });

  final unavailable = <FilePreviewResponse, FilePreviewUnavailableReason>{
    const FilePreviewResponse.missing(): FilePreviewUnavailableReason.missing,
    const FilePreviewResponse.tooLarge(): FilePreviewUnavailableReason.tooLarge,
    const FilePreviewResponse.unsupported(): FilePreviewUnavailableReason.unsupported,
    const FilePreviewResponse.denied(): FilePreviewUnavailableReason.denied,
  };
  for (final MapEntry(key: response, value: reason) in unavailable.entries) {
    test("maps ${reason.name}", () async {
      answer(ApiResponse.success(response));

      expect(
        await repository.load(path: "/a/b.txt"),
        isA<FilePreviewContentUnavailable>().having((r) => r.reason, "reason", reason),
      );
    });
  }

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
