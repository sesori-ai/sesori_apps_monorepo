import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

void main() {
  group("SessionService", () {
    late MockRelayHttpApiClient mockClient;
    late SessionService sessionService;

    setUp(() {
      mockClient = MockRelayHttpApiClient();
      sessionService = SessionService(mockClient);
    });

    group("getSessionDiffs", () {
      test("returns list of FileDiff on success", () async {
        final fileDiffs = [
          const FileDiff(
            file: "lib/main.dart",
            before: "void main() {}",
            after: "void main() { print('hello'); }",
            additions: 1,
            deletions: 0,
            status: FileDiffStatus.modified,
          ),
          const FileDiff(
            file: "lib/new_file.dart",
            before: "",
            after: "class NewClass {}",
            additions: 1,
            deletions: 0,
            status: FileDiffStatus.added,
          ),
        ];

        when(
          () => mockClient.get<List<FileDiff>>(
            "/session/session-123/diff",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(fileDiffs));

        final result = await sessionService.getSessionDiffs("session-123");

        expect(result, isA<SuccessResponse<List<FileDiff>>>());
        final data = (result as SuccessResponse<List<FileDiff>>).data;
        expect(data, equals(fileDiffs));
        expect(data.length, equals(2));
        expect(data[0].file, equals("lib/main.dart"));
        expect(data[1].file, equals("lib/new_file.dart"));
      });

      test("returns empty list when no diffs", () async {
        when(
          () => mockClient.get<List<FileDiff>>(
            "/session/session-456/diff",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.success(<FileDiff>[]));

        final result = await sessionService.getSessionDiffs("session-456");

        expect(result, isA<SuccessResponse<List<FileDiff>>>());
        final data = (result as SuccessResponse<List<FileDiff>>).data;
        expect(data, isEmpty);
      });

      test("returns error response on failure", () async {
        final error = ApiError.generic();

        when(
          () => mockClient.get<List<FileDiff>>(
            "/session/session-789/diff",
            fromJson: any(named: "fromJson"),
          ),
        ).thenAnswer((_) async => ApiResponse.error(error));

        final result = await sessionService.getSessionDiffs("session-789");

        expect(result, isA<ErrorResponse<List<FileDiff>>>());
        final errorResult = (result as ErrorResponse<List<FileDiff>>).error;
        expect(errorResult, isA<GenericError>());
      });
    });
  });
}
