import "dart:async";
import "dart:typed_data";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log, PluginOperationException;
import "package:sesori_shared/sesori_shared.dart";

import "../repositories/agent_page_repository.dart";
import "../repositories/attachment_thumbnail_builder.dart";
import "../repositories/filesystem_repository.dart";
import "../repositories/mappers/agent_page_mapper.dart";
import "../repositories/models/agent_page.dart";
import "../repositories/models/sesori_mcp_caller.dart";
import "../repositories/models/session_operation.dart";
import "../repositories/prompt_upload_repository.dart";
import "../repositories/session_repository.dart";
import "agent_page_answer_notice_builder.dart";
import "archived_session_validator.dart";
import "session_notice_service.dart";

/// The pages agents send the user through Sesori's MCP server.
///
/// A page rides the pending-question pipeline as a marker, so every surface
/// shows its session as needing the user. Its images are copied when it is
/// sent, so the page keeps them however the originals change. Logs carry ids
/// and outcomes, never page content or answers.
class AgentPageService({
  required final AgentPageRepository _pages,
  required final SessionRepository _sessions,
  required final FilesystemRepository _filesystem,
  required final PromptUploadRepository _images,
  required final AttachmentThumbnailBuilder _imageReader,
  required final ArchivedSessionValidator _archive,
  required final SessionNoticeService _notices,
  required final AgentPageAnswerNoticeBuilder _noticeBuilder,
}) {
  static const int maxTitleLength = 200;
  static const int maxImages = 20;
  static const int maxQuestions = 50;
  static const int maxOptions = 12;

  /// Each image is also capped at [maxTranscriptImageBytes].
  static const int maxPageImageBytes = 50 * 1024 * 1024;

  /// Copies the page's images and shows the page to the user. Returns at
  /// once: the answer reaches the session as a notice.
  Future<AgentPageSendResult> send({required SesoriMcpCaller caller, required AgentPageDraft draft}) async {
    final String rootSessionId;
    try {
      rootSessionId = (await _sessions.resolveSessionFamily(
        sessionId: caller.sessionId,
        operation: SessionOperation.sendPage,
      )).rootSessionId;
    } on PluginOperationException {
      return const AgentPageCallerGone();
    }
    if (_limitProblem(draft: draft) case final problem?) return problem;

    final images = <String, _ReadImage>{};
    var pageBytes = 0;
    for (final image in _imagesOf(draft: draft)) {
      if (images.containsKey(image.path)) continue;
      switch (await _readImage(path: image.path)) {
        case _RejectedImage(:final result):
          return result;
        case final _ReadImage read:
          pageBytes += read.bytes.length;
          if (pageBytes > maxPageImageBytes) return const AgentPageOverLimit(limit: AgentPageLimit.imageBytes);
          images[read.path] = read;
      }
    }

    final copies = <String, String>{};
    try {
      for (final image in images.values) {
        copies[image.path] = await _images.save(
          sessionId: caller.sessionId,
          bytes: image.bytes,
          filename: p.basename(image.path),
        );
      }
      PageImage copied(AgentPageImageDraft draft) {
        final image = images[draft.path];
        final copy = copies[draft.path];
        if (image == null || copy == null) throw StateError("image ${draft.path} was not copied");
        return PageImage(path: copy, width: image.width, height: image.height, caption: draft.caption);
      }

      final page = await _pages.add(
        sessionId: caller.sessionId,
        // Sub-agent pages show on the root session, like plugin questions.
        displaySessionId: rootSessionId == caller.sessionId ? null : rootSessionId,
        title: draft.title,
        intro: draft.intro,
        sections: [
          for (final section in draft.sections)
            PageSection(
              heading: section.heading,
              body: section.body,
              images: [for (final image in section.images) copied(image)],
              questions: [
                for (final question in section.questions)
                  PageQuestion(
                    id: question.id,
                    title: question.title,
                    body: question.body,
                    images: [for (final image in question.images) copied(image)],
                    kind: switch (question.kind) {
                      AgentPageSingleChoiceDraft(:final options) => PageQuestionKind.single(
                        options: _options(options: options, copied: copied),
                      ),
                      AgentPageMultipleChoiceDraft(:final options) => PageQuestionKind.multiple(
                        options: _options(options: options, copied: copied),
                      ),
                      AgentPageTextDraft() => const PageQuestionKind.text(),
                    },
                    isRequired: question.isRequired,
                  ),
              ],
            ),
        ],
      );
      Log.i("Session ${caller.sessionId} sent page ${page.id} with ${images.length} images");
      return AgentPageSent(page: page);
    } on Object {
      await Future.wait([for (final copy in copies.values) _images.deleteSaved(path: copy)]);
      rethrow;
    }
  }

  /// The markers of the pages to show on [sessionId]'s screen, leaving out
  /// pages of archived sessions.
  Future<List<PendingQuestion>> pendingQuestions({required String sessionId}) async {
    final shown = <String, bool>{};
    return [
      for (final page in await _pages.pendingPages(sessionId: sessionId))
        if (shown[page.sessionId] ??= await _isShown(sessionId: page.sessionId)) page.toPendingQuestion(),
    ];
  }

  /// Dismisses [requestId] when it names a page shown on [sessionId]. The
  /// question routes can only cancel a page, so a reply dismisses it too.
  ///
  /// Throws [SessionArchivedReadOnlyException] when the page's session is
  /// archived.
  Future<AgentPageInterception> dismiss({required String requestId, required String sessionId}) async {
    final stored = await _pages.find(id: requestId);
    if (stored == null) return const NotAgentPage();
    final page = stored.page;
    if (sessionId != page.sessionId && sessionId != (page.displaySessionId ?? page.sessionId)) {
      return const NotAgentPage();
    }
    await _archive.requireNotArchived(sessionId: page.sessionId);
    final settled = await _pages.settle(id: requestId, outcome: const AgentPageDismissed());
    if (settled == null) return const AgentPageAlreadySettled();
    Log.i("Page $requestId was dismissed");
    unawaited(
      _notices.deliver(
        sessionId: settled.displaySessionId ?? settled.sessionId,
        notice: _noticeBuilder.dismissed(page: settled),
      ),
    );
    return const AgentPageReplyDismissed();
  }

  AgentPageSendResult? _limitProblem({required AgentPageDraft draft}) {
    if (draft.title.length > maxTitleLength) return const AgentPageOverLimit(limit: AgentPageLimit.titleLength);
    if (_imagesOf(draft: draft).length > maxImages) return const AgentPageOverLimit(limit: AgentPageLimit.images);
    final questions = [for (final section in draft.sections) ...section.questions];
    if (questions.length > maxQuestions) return const AgentPageOverLimit(limit: AgentPageLimit.questions);
    final questionIds = <String>{};
    for (final question in questions) {
      if (!questionIds.add(question.id)) return AgentPageDuplicateQuestionId(questionId: question.id);
      final options = switch (question.kind) {
        AgentPageSingleChoiceDraft(:final options) || AgentPageMultipleChoiceDraft(:final options) => options,
        AgentPageTextDraft() => const <AgentPageOptionDraft>[],
      };
      if (options.length > maxOptions) return AgentPageTooManyOptions(questionId: question.id);
      final optionIds = <String>{};
      for (final option in options) {
        if (!optionIds.add(option.id)) {
          return AgentPageDuplicateOptionId(questionId: question.id, optionId: option.id);
        }
      }
    }
    return null;
  }

  /// Every image [draft] declares, in page order.
  List<AgentPageImageDraft> _imagesOf({required AgentPageDraft draft}) {
    return [
      for (final section in draft.sections) ...[
        ...section.images,
        for (final question in section.questions) ...[
          ...question.images,
          ...switch (question.kind) {
            AgentPageSingleChoiceDraft(:final options) || AgentPageMultipleChoiceDraft(:final options) => [
              for (final option in options) ?option.image,
            ],
            AgentPageTextDraft() => const <AgentPageImageDraft>[],
          },
        ],
      ],
    ];
  }

  /// The image at [path] with its size, or why it cannot be shown. Its
  /// content must be the image its extension names.
  Future<_ImageRead> _readImage({required String path}) async {
    _RejectedImage rejected(AgentPageImageProblem problem) => _RejectedImage(
      result: AgentPageImageRejected(path: path, problem: problem),
    );
    if (!p.isAbsolute(path)) return rejected(AgentPageImageProblem.notAbsolute);
    switch (_filesystem.readImageFile(absolutePath: path)) {
      case ImageFileContent(:final bytes, :final mime):
        if (_imageReader.detectSupportedMime(bytes: bytes) != mime) return rejected(AgentPageImageProblem.notImage);
        final dimensions = await _imageReader.readDimensions(bytes: bytes);
        if (dimensions == null) return rejected(AgentPageImageProblem.notImage);
        return _ReadImage(path: path, bytes: bytes, width: dimensions.width, height: dimensions.height);
      case ImageFileMissing():
        return rejected(AgentPageImageProblem.missing);
      case ImageFileDenied():
        return rejected(AgentPageImageProblem.denied);
      case ImageFileTooLarge():
        return rejected(AgentPageImageProblem.tooLarge);
      case ImageFileUnsupported():
        return rejected(AgentPageImageProblem.notImage);
    }
  }

  List<PageOption> _options({
    required List<AgentPageOptionDraft> options,
    required PageImage Function(AgentPageImageDraft draft) copied,
  }) {
    return [
      for (final option in options)
        PageOption(
          id: option.id,
          label: option.label,
          description: option.description,
          image: switch (option.image) {
            final image? => copied(image),
            null => null,
          },
          recommended: option.recommended,
        ),
    ];
  }

  Future<bool> _isShown({required String sessionId}) async {
    final stored = await _sessions.getStoredSession(sessionId: sessionId);
    return stored != null && stored.archivedAt == null;
  }
}

sealed class const _ImageRead();

final class const _ReadImage({
  required final String path,
  required final Uint8List bytes,
  required final int width,
  required final int height,
}) extends _ImageRead;

final class const _RejectedImage({required final AgentPageImageRejected result}) extends _ImageRead;

/// A page as the agent composed it. Image paths point at the agent's files.
final class const AgentPageDraft({
  required final String title,
  required final String? intro,
  required final List<AgentPageSectionDraft> sections,
});

final class const AgentPageSectionDraft({
  required final String? heading,
  required final String? body,
  required final List<AgentPageImageDraft> images,
  required final List<AgentPageQuestionDraft> questions,
});

final class const AgentPageImageDraft({required final String path, required final String? caption});

final class const AgentPageQuestionDraft({
  required final String id,
  required final String title,
  required final String? body,
  required final List<AgentPageImageDraft> images,
  required final AgentPageQuestionKindDraft kind,
  required final bool isRequired,
});

sealed class const AgentPageQuestionKindDraft();

final class const AgentPageSingleChoiceDraft({required final List<AgentPageOptionDraft> options})
    extends AgentPageQuestionKindDraft;

final class const AgentPageMultipleChoiceDraft({required final List<AgentPageOptionDraft> options})
    extends AgentPageQuestionKindDraft;

final class const AgentPageTextDraft() extends AgentPageQuestionKindDraft;

final class const AgentPageOptionDraft({
  required final String id,
  required final String label,
  required final String? description,
  required final AgentPageImageDraft? image,
  required final bool recommended,
});

sealed class const AgentPageSendResult();

final class const AgentPageSent({required final PendingPage page}) extends AgentPageSendResult;

/// The calling session is no longer known.
final class const AgentPageCallerGone() extends AgentPageSendResult;

final class const AgentPageOverLimit({required final AgentPageLimit limit}) extends AgentPageSendResult;

final class const AgentPageTooManyOptions({required final String questionId}) extends AgentPageSendResult;

/// Question ids are unique within a page.
final class const AgentPageDuplicateQuestionId({required final String questionId}) extends AgentPageSendResult;

/// Option ids are unique within their question.
final class const AgentPageDuplicateOptionId({required final String questionId, required final String optionId})
    extends AgentPageSendResult;

final class const AgentPageImageRejected({required final String path, required final AgentPageImageProblem problem})
    extends AgentPageSendResult;

/// The page-wide limits [AgentPageService] enforces.
enum AgentPageLimit() {
  titleLength,
  images,
  questions,

  /// All images together.
  imageBytes,
}

enum AgentPageImageProblem() {
  notAbsolute,
  missing,
  denied,
  tooLarge,

  /// Not a png, jpg, gif or webp image, by extension or by content.
  notImage,
}

/// What a question route's reply or reject did with its request id.
sealed class const AgentPageInterception();

/// A plugin's question; the plugin answers it.
final class const NotAgentPage() extends AgentPageInterception;

final class const AgentPageReplyDismissed() extends AgentPageInterception;

/// Answered or dismissed already, on this or another surface.
final class const AgentPageAlreadySettled() extends AgentPageInterception;
