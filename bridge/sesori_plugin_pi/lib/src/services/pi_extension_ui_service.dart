import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/pi_extension_ui_request.dart";
import "../api/pi_rpc_client.dart";
import "../models/pi_notification_type.dart";
import "../repositories/pi_session_catalog_repository.dart";
import "../trackers/pi_extension_ui_tracker.dart";

typedef PiExtensionUiResponseSender = bool Function({
  required String ownerSessionId,
  required String requestId,
  required PiExtensionUiReply reply,
});

sealed class const PiExtensionUiEvent();

final class const PiExtensionUiQuestionAsked({required final PluginPendingQuestion question})
    extends PiExtensionUiEvent;

final class const PiExtensionUiQuestionReplied({
  required final String requestId,
  required final String ownerSessionId,
  required final String displaySessionId,
}) extends PiExtensionUiEvent;

final class const PiExtensionUiQuestionRejected({
  required final String requestId,
  required final String ownerSessionId,
  required final String displaySessionId,
}) extends PiExtensionUiEvent;

final class const PiExtensionUiToast({
  required final String title,
  required final String message,
  required final PiNotificationType variant,
}) extends PiExtensionUiEvent;

final class PiExtensionUiService({
  required final PiSessionCatalogRepository catalogRepository,
  required final PiExtensionUiTracker tracker,
  required final PiExtensionUiResponseSender responseSender,
  required final Duration editorTimeout,
}) {
  static const maxTextLength = 500;
  static const defaultEditorTimeout = Duration(minutes: 30);

  final PiSessionCatalogRepository _catalogRepository = catalogRepository;
  final PiExtensionUiTracker _tracker = tracker;
  final PiExtensionUiResponseSender _responseSender = responseSender;
  final Duration _editorTimeout = editorTimeout;
  final StreamController<PiExtensionUiEvent> _events = StreamController.broadcast(sync: true);
  final Map<String, Timer> _timers = {};
  final Map<String, int> _ownerGenerations = {};
  var _disposed = false;

  Stream<PiExtensionUiEvent> get events => _events.stream;

  Future<void> handleRequest({required String ownerSessionId, required PiExtensionUiRequest request}) async {
    if (_disposed) return;
    switch (request) {
      case PiNotifyRequest(:final message, :final notifyType):
        final visible = message == null ? null : _bounded(message);
        if (visible != null && visible.isNotEmpty) {
          _events.add(
            PiExtensionUiToast(title: "Pi", message: visible, variant: notifyType ?? PiNotificationType.info),
          );
        }
        return;
      case PiExtensionDecorationRequest():
      case PiUnknownExtensionUiRequest():
        Log.d("[pi] ignored unsupported extension UI decoration");
        return;
      case final PiExtensionDialogRequest dialog:
        final generation = _ownerGenerations[ownerSessionId] ?? 0;
        final scope = await _catalogRepository.resolveDisplayScope(sessionId: ownerSessionId);
        if (_disposed) return;
        if ((_ownerGenerations[ownerSessionId] ?? 0) != generation) {
          _responseSender(
            ownerSessionId: ownerSessionId,
            requestId: dialog.id,
            reply: const PiExtensionUiCancelledReply(),
          );
          return;
        }
        if (scope == null) {
          _responseSender(
            ownerSessionId: ownerSessionId,
            requestId: dialog.id,
            reply: const PiExtensionUiCancelledReply(),
          );
          return;
        }
        final tracked = _tracked(dialog: dialog, ownerSessionId: ownerSessionId, scope: scope);
        _tracker.add(dialog: tracked);
        _scheduleTimeout(dialog: dialog, tracked: tracked);
        _events.add(PiExtensionUiQuestionAsked(question: _pending(tracked)));
    }
  }

  List<PluginPendingQuestion> getPendingQuestions({required String sessionId}) =>
      _tracker.pendingForSession(sessionId: sessionId);

  List<PluginPendingQuestion> getProjectQuestions({required String projectId}) =>
      _tracker.pendingForProject(projectId: projectId);

  void replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) {
    final dialog = _required(questionId: questionId, sessionId: sessionId);
    final reply = _replyFor(dialog: dialog, answers: answers);
    if (reply == null) {
      throw const PluginOperationException(
        "reply to Pi extension question",
        statusCode: 400,
        message: "The question response is invalid.",
      );
    }
    if (!_responseSender(ownerSessionId: dialog.ownerSessionId, requestId: dialog.requestId, reply: reply)) {
      throw const PluginOperationException.notFound(
        "reply to Pi extension question",
        message: "The Pi dialog is no longer available.",
      );
    }
    _take(questionId: questionId);
    _events.add(
      PiExtensionUiQuestionReplied(
        requestId: questionId,
        ownerSessionId: dialog.ownerSessionId,
        displaySessionId: dialog.displaySessionId,
      ),
    );
  }

  void rejectQuestion({required String questionId, required String? sessionId}) {
    final dialog = _required(questionId: questionId, sessionId: sessionId);
    if (!_responseSender(
      ownerSessionId: dialog.ownerSessionId,
      requestId: dialog.requestId,
      reply: const PiExtensionUiCancelledReply(),
    )) {
      throw const PluginOperationException.notFound(
        "reject Pi extension question",
        message: "The Pi dialog is no longer available.",
      );
    }
    _take(questionId: questionId);
    _rejected(dialog);
  }

  void cancelForOwner({required String sessionId}) {
    _ownerGenerations[sessionId] = (_ownerGenerations[sessionId] ?? 0) + 1;
    for (final dialog in _tracker.takeForOwner(sessionId: sessionId)) {
      _cancelTimer(questionId: dialog.questionId);
      _responseSender(
        ownerSessionId: dialog.ownerSessionId,
        requestId: dialog.requestId,
        reply: const PiExtensionUiCancelledReply(),
      );
      _rejected(dialog);
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final dialog in _tracker.takeAll()) {
      _cancelTimer(questionId: dialog.questionId);
      _responseSender(
        ownerSessionId: dialog.ownerSessionId,
        requestId: dialog.requestId,
        reply: const PiExtensionUiCancelledReply(),
      );
      _rejected(dialog);
    }
    _ownerGenerations.clear();
    await _events.close();
  }

  PiTrackedExtensionDialog _tracked({
    required PiExtensionDialogRequest dialog,
    required String ownerSessionId,
    required ({String displaySessionId, String projectId}) scope,
  }) {
    final questionId = _tracker.nextQuestionId();
    final shared = (
      questionId: questionId,
      requestId: dialog.id,
      ownerSessionId: ownerSessionId,
      displaySessionId: scope.displaySessionId,
      projectId: scope.projectId,
    );
    return switch (dialog) {
      PiSelectDialogRequest(:final title, :final options) => PiTrackedSelectDialog(
        questionId: shared.questionId,
        requestId: shared.requestId,
        ownerSessionId: shared.ownerSessionId,
        displaySessionId: shared.displaySessionId,
        projectId: shared.projectId,
        question: PluginQuestionInfo(
          question: "Choose one option.",
          header: _header(title, fallback: "Pi extension"),
          options: [for (final option in options) PluginQuestionOption(label: option, description: "")],
          multiple: false,
          custom: false,
        ),
        options: options.toSet(),
      ),
      PiConfirmDialogRequest(:final title, :final message) => PiTrackedConfirmDialog(
        questionId: shared.questionId,
        requestId: shared.requestId,
        ownerSessionId: shared.ownerSessionId,
        displaySessionId: shared.displaySessionId,
        projectId: shared.projectId,
        question: PluginQuestionInfo(
          question: _boundedNullable(message) ?? "Confirm this action.",
          header: _header(title, fallback: "Confirmation"),
          options: const [
            PluginQuestionOption(label: "Yes", description: ""),
            PluginQuestionOption(label: "No", description: ""),
          ],
          multiple: false,
          custom: false,
        ),
      ),
      PiInputDialogRequest(:final title, :final placeholder) => PiTrackedInputDialog(
        questionId: shared.questionId,
        requestId: shared.requestId,
        ownerSessionId: shared.ownerSessionId,
        displaySessionId: shared.displaySessionId,
        projectId: shared.projectId,
        question: PluginQuestionInfo(
          question: _boundedNullable(placeholder) ?? "Enter a value.",
          header: _header(title, fallback: "Pi extension"),
          options: const [],
          multiple: false,
          custom: true,
        ),
      ),
      PiEditorDialogRequest(:final title, :final prefill) => PiTrackedEditorDialog(
        questionId: shared.questionId,
        requestId: shared.requestId,
        ownerSessionId: shared.ownerSessionId,
        displaySessionId: shared.displaySessionId,
        projectId: shared.projectId,
        question: PluginQuestionInfo(
          question: _editorPrompt(prefill),
          header: _header(title, fallback: "Editor"),
          options: const [],
          multiple: false,
          custom: true,
        ),
      ),
    };
  }

  void _scheduleTimeout({required PiExtensionDialogRequest dialog, required PiTrackedExtensionDialog tracked}) {
    final Duration? timeout = switch (dialog) {
      PiSelectDialogRequest(:final timeoutMs) ||
      PiConfirmDialogRequest(:final timeoutMs) ||
      PiInputDialogRequest(
        :final timeoutMs,
      ) => timeoutMs != null && timeoutMs > 0 ? Duration(milliseconds: timeoutMs) : null,
      PiEditorDialogRequest() => _editorTimeout,
    };
    if (timeout == null) return;
    _timers[tracked.questionId] = Timer(timeout, () {
      final current = _tracker.find(questionId: tracked.questionId);
      if (!identical(current, tracked)) return;
      _tracker.take(questionId: tracked.questionId);
      _timers.remove(tracked.questionId);
      if (tracked is PiTrackedEditorDialog) {
        _responseSender(
          ownerSessionId: tracked.ownerSessionId,
          requestId: tracked.requestId,
          reply: const PiExtensionUiCancelledReply(),
        );
      }
      _rejected(tracked);
    });
  }

  PiTrackedExtensionDialog _required({required String questionId, required String? sessionId}) {
    final dialog = _tracker.find(questionId: questionId);
    if (dialog == null || (sessionId != null && dialog.ownerSessionId != sessionId)) {
      throw const PluginOperationException.notFound(
        "Pi extension question",
        message: "Question not found.",
      );
    }
    return dialog;
  }

  void _take({required String questionId}) {
    _tracker.take(questionId: questionId);
    _cancelTimer(questionId: questionId);
  }

  void _cancelTimer({required String questionId}) => _timers.remove(questionId)?.cancel();

  void _rejected(PiTrackedExtensionDialog dialog) {
    _events.add(
      PiExtensionUiQuestionRejected(
        requestId: dialog.questionId,
        ownerSessionId: dialog.ownerSessionId,
        displaySessionId: dialog.displaySessionId,
      ),
    );
  }
}

PiExtensionUiReply? _replyFor({
  required PiTrackedExtensionDialog dialog,
  required List<List<String>> answers,
}) {
  if (answers.length != 1 || answers.single.length != 1) return null;
  final answer = answers.single.single;
  return switch (dialog) {
    PiTrackedSelectDialog(:final options) when options.contains(answer) => PiExtensionUiValueReply(value: answer),
    PiTrackedConfirmDialog() when answer == "Yes" => const PiExtensionUiConfirmationReply(confirmed: true),
    PiTrackedConfirmDialog() when answer == "No" => const PiExtensionUiConfirmationReply(confirmed: false),
    PiTrackedInputDialog() || PiTrackedEditorDialog() => PiExtensionUiValueReply(value: answer),
    _ => null,
  };
}

PluginPendingQuestion _pending(PiTrackedExtensionDialog dialog) => PluginPendingQuestion(
  id: dialog.questionId,
  sessionID: dialog.ownerSessionId,
  displaySessionId: dialog.displaySessionId,
  questions: [dialog.question],
);

String _header(String? value, {required String fallback}) => _boundedNullable(value) ?? fallback;

String? _boundedNullable(String? value) => value == null || value.isEmpty ? null : _bounded(value);

String _bounded(String value) {
  final runes = value.runes.toList(growable: false);
  if (runes.length <= PiExtensionUiService.maxTextLength) return value;
  return "${String.fromCharCodes(runes.take(PiExtensionUiService.maxTextLength - 3))}...";
}

String _editorPrompt(String? prefill) {
  const instruction = "Reply with the complete replacement text.";
  if (prefill == null || prefill.isEmpty) return instruction;
  final runes = prefill.runes.toList(growable: false);
  final excerpt = String.fromCharCodes(runes.take(PiExtensionUiService.maxTextLength));
  final truncated = runes.length > PiExtensionUiService.maxTextLength;
  return "$instruction\n\nCurrent text excerpt:\n$excerpt${truncated ? "\n\nPrefill was truncated. Omitted text will not be retained." : ""}";
}
