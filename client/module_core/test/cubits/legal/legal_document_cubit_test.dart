import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockLegalRepository extends Mock implements LegalRepository {}

void main() {
  late _MockLegalRepository repository;

  setUpAll(() {
    registerFallbackValue(LegalDocument.terms);
  });

  setUp(() {
    repository = _MockLegalRepository();
  });

  test("loads the requested document's markdown", () async {
    when(() => repository.getMarkdown(document: any(named: "document")))
        .thenAnswer((_) async => ApiResponse.success("# Terms"));

    final cubit = LegalDocumentCubit(repository: repository, document: LegalDocument.terms);
    await cubit.stream.firstWhere((state) => state is! LegalDocumentLoading);

    expect(cubit.state, const LegalDocumentState.loaded(markdown: "# Terms"));
    verify(() => repository.getMarkdown(document: LegalDocument.terms)).called(1);
  });

  test("maps a transport failure to a domain reason", () async {
    when(() => repository.getMarkdown(document: any(named: "document")))
        .thenAnswer((_) async => ApiResponse.error(ApiError.dartHttpClient(Exception("offline"))));

    final cubit = LegalDocumentCubit(repository: repository, document: LegalDocument.privacy);
    await cubit.stream.firstWhere((state) => state is! LegalDocumentLoading);

    expect(cubit.state, const LegalDocumentState.failed(reason: RemoteFailureReason.networkDown));
  });

  test("retry re-fetches after a failure", () async {
    var attempt = 0;
    when(() => repository.getMarkdown(document: any(named: "document"))).thenAnswer((_) async {
      attempt++;
      return attempt == 1
          ? ApiResponse.error(ApiError.generic())
          : ApiResponse.success("# Privacy Policy");
    });

    final cubit = LegalDocumentCubit(repository: repository, document: LegalDocument.privacy);
    await cubit.stream.firstWhere((state) => state is LegalDocumentFailed);

    await cubit.retry();

    expect(cubit.state, const LegalDocumentState.loaded(markdown: "# Privacy Policy"));
  });
}
