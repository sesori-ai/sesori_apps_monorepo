import "dart:io";

import "package:sesori_bridge/src/api/database/daos/agent_pages_dao.dart";
import "package:sesori_bridge/src/api/database/database.dart";
import "package:sesori_bridge/src/api/filesystem_api.dart";
import "package:sesori_bridge/src/foundation/filesystem_permission_validator.dart";
import "package:sesori_bridge/src/repositories/agent_page_repository.dart";
import "package:sesori_bridge/src/repositories/attachment_thumbnail_builder.dart";
import "package:sesori_bridge/src/repositories/filesystem_repository.dart";
import "package:sesori_bridge/src/repositories/models/session_notice.dart";
import "package:sesori_bridge/src/repositories/prompt_upload_repository.dart";
import "package:sesori_bridge/src/repositories/session_repository.dart";
import "package:sesori_bridge/src/repositories/session_unseen_calculator.dart";
import "package:sesori_bridge/src/services/agent_page_answer_notice_builder.dart";
import "package:sesori_bridge/src/services/agent_page_service.dart";
import "package:sesori_bridge/src/services/archived_session_validator.dart";
import "package:sesori_bridge/src/services/session_notice_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show BridgePluginApi;

import "single_plugin_repository_test_support.dart";
import "test_drive_roots_api.dart";

/// Records the notices instead of prompting sessions.
class RecordingSessionNotices() implements SessionNoticeService {
  final List<({String sessionId, SessionNotice notice})> delivered = [];

  @override
  Future<void> deliver({required String sessionId, required SessionNotice notice}) async =>
      delivered.add((sessionId: sessionId, notice: notice));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A real [AgentPageService] on [database], copying page images under
/// [imagesRoot].
({AgentPageService service, AgentPageRepository pages}) buildTestAgentPageService({
  required AppDatabase database,
  required SessionRepository sessions,
  required SessionNoticeService notices,
  required String imagesRoot,
}) {
  final pages = AgentPageRepository(dao: AgentPagesDao(database: database));
  return (
    pages: pages,
    service: AgentPageService(
      pages: pages,
      sessions: sessions,
      filesystem: FilesystemRepository(
        filesystemApi: const FilesystemApi(),
        permissionValidator: const FilesystemPermissionValidator(),
        driveRootsApi: windowsDriveRootsApi,
      ),
      images: PromptUploadRepository(filesystemApi: const FilesystemApi(), uploadsRoot: imagesRoot),
      imageReader: const AttachmentThumbnailBuilder(),
      archive: ArchivedSessionValidator(sessionRepository: sessions),
      notices: notices,
      noticeBuilder: const AgentPageAnswerNoticeBuilder(),
    ),
  );
}

/// [buildTestAgentPageService] for handler tests that never send images.
({AgentPageService service, AgentPageRepository pages, RecordingSessionNotices notices}) buildTestAgentPages({
  required AppDatabase database,
  required BridgePluginApi plugin,
}) {
  final notices = RecordingSessionNotices();
  final built = buildTestAgentPageService(
    database: database,
    sessions: singlePluginSessionRepository(
      plugin: plugin,
      sessionDao: database.sessionDao,
      projectsDao: database.projectsDao,
      unseenCalculator: const SessionUnseenCalculator(),
    ),
    notices: notices,
    imagesRoot: "${Directory.systemTemp.path}/unused-page-images",
  );
  return (service: built.service, pages: built.pages, notices: notices);
}

/// Stores a pending page from [sessionId] and returns its id.
Future<String> addTestPage({required AgentPageRepository pages, required String sessionId}) async {
  final page = await pages.add(
    sessionId: sessionId,
    displaySessionId: null,
    title: "Release plan",
    intro: null,
    sections: const [],
  );
  return page.id;
}
