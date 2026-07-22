import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_config_reader.dart";
import "package:codex_plugin/src/codex_metadata_repository.dart";
import "package:codex_plugin/src/codex_skill_reader.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:test/test.dart";

void main() {
  test("detaching clears app-server loaded-thread state", () async {
    final rolloutApi = CodexRolloutApi(environment: const {});
    final service = CodexSessionService(
      catalogRepository: CodexCatalogRepository(rolloutApi: rolloutApi),
      messageRepository: CodexMessageRepository(rolloutApi: rolloutApi),
      metadataRepository: CodexMetadataRepository(
        skillReader: CodexSkillReader(environment: const {}),
        configReader: CodexConfigReader(environment: const {}),
        launchDirectory: "/repo",
      ),
      launchDirectory: "/repo",
    );
    final firstRepository = _StubThreadRepository();
    service.attachThreadRepository(threadRepository: firstRepository);
    await service.resumeThreadIfNeeded(threadId: "thread-id", force: false);

    service.detachThreadRepository();
    final secondRepository = _StubThreadRepository();
    service.attachThreadRepository(threadRepository: secondRepository);
    await service.resumeThreadIfNeeded(threadId: "thread-id", force: false);

    expect(firstRepository.resumeCount, 1);
    expect(secondRepository.resumeCount, 1);
  });
}

class _StubThreadRepository extends CodexThreadRepository {
  _StubThreadRepository()
    : super(
        appServerApi: CodexAppServerApi(
          client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
        ),
      );

  int resumeCount = 0;

  @override
  Future<CodexThreadRecord> resumeThread({required String threadId}) async {
    resumeCount += 1;
    return CodexThreadRecord(
      id: threadId,
      name: null,
      directory: "/repo",
      createdAt: null,
      updatedAt: null,
      model: null,
      modelProvider: null,
    );
  }
}
