import "dart:typed_data";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockFilePreviewRepository() extends Mock implements FilePreviewRepository;

const _reference = FileReference(absolutePath: "/a/notes.md", line: null);

void main() {
  late _MockFilePreviewRepository repository;

  setUp(() => repository = _MockFilePreviewRepository());

  Future<FilePreviewState> settledState({required FilePreviewResult result}) async {
    when(() => repository.load(path: "/a/notes.md")).thenAnswer((_) async => result);
    final cubit = FilePreviewCubit(repository: repository, reference: _reference);
    expect(cubit.state, isA<FilePreviewLoading>());
    final state = await cubit.stream.first;
    await cubit.close();
    return state;
  }

  test("shows text", () async {
    final state = await settledState(result: const FilePreviewTextContent(content: "# Notes"));
    expect(state, isA<FilePreviewShowsText>().having((s) => s.content, "content", "# Notes"));
  });

  test("shows an image", () async {
    final state = await settledState(
      result: FilePreviewImageContent(bytes: Uint8List.fromList([1, 2, 3]), mime: "image/png"),
    );
    expect(
      state,
      isA<FilePreviewShowsImage>()
          .having((s) => s.bytes, "bytes", [1, 2, 3])
          .having((s) => s.mime, "mime", "image/png"),
    );
  });

  final unavailable = <FilePreviewResult, FilePreviewUnavailableReason>{
    for (final reason in [
      FilePreviewUnavailableReason.missing,
      FilePreviewUnavailableReason.tooLarge,
      FilePreviewUnavailableReason.unsupported,
      FilePreviewUnavailableReason.denied,
    ])
      FilePreviewContentUnavailable(reason: reason): reason,
    const FilePreviewBridgeTooOld(): FilePreviewUnavailableReason.bridgeTooOld,
    FilePreviewFailed(innerError: ApiError.generic(), stackTrace: StackTrace.empty):
        FilePreviewUnavailableReason.failed,
  };
  for (final MapEntry(key: result, value: reason) in unavailable.entries) {
    test("explains ${reason.name}", () async {
      final state = await settledState(result: result);
      expect(state, isA<FilePreviewUnavailable>().having((s) => s.reason, "reason", reason));
    });
  }
}
