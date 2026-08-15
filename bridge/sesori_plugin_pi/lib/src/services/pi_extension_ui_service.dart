import "dart:async";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "../api/models/pi_extension_ui_request.dart";
import "../api/pi_rpc_client.dart";
import "../models/pi_notification_type.dart";
import "../repositories/pi_session_catalog_repository.dart";
import "../repositories/pi_session_process_repository.dart";
import "../trackers/pi_extension_ui_tracker.dart";

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
  required final PiSessionProcessRepository processRepository,
  required final PiExtensionUiTracker tracker,
  required final Duration editorTimeout,
}) {
  static const maxTextLength = 500;
  static const defaultEditorTimeout = Duration(minutes: 30);

  final PiSessionCatalogRepository _catalogRepository = catalogRepository;
  final PiSessionProcessRepository _processRepository = processRepository;
  final PiExtensionUiTracker _tracker = tracker;
  final Duration _editorTimeout = editorTimeout;
  final StreamController<PiExtensionUiEvent> _events = StreamController.broadcast(sync: true);
  final Map<String, Timer> _timers = {};
  final Map<String, int> _ownerGenerations = {};
  final Map<String, int> _cancelledProcessGenerations = {};
  var _disposed = false;

  Stream<PiExtensionUiEvent> get events => _events.stream;

  Future<void> handleRequest({
    required String ownerSessionId,
    required int processGeneration,
    required PiExtensionUiRequest request,
  }) async {
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
        final elapsed = Stopwatch()..start();
        final generation = _ownerGenerations[ownerSessionId] ?? 0;
        final ({String displaySessionId, String projectId})? scope;
        try {
          scope = await _catalogRepository.resolveDisplayScope(sessionId: ownerSessionId);
        } on Object {
          _cancel(
            ownerSessionId: ownerSessionId,
            processGeneration: processGeneration,
            requestId: dialog.id,
          );
          rethrow;
        }
        if (_disposed) {
          _cancel(
            ownerSessionId: ownerSessionId,
            processGeneration: processGeneration,
            requestId: dialog.id,
          );
          return;
        }
        if ((_ownerGenerations[ownerSessionId] ?? 0) != generation ||
            processGeneration <= (_cancelledProcessGenerations[ownerSessionId] ?? -1)) {
          _cancel(
            ownerSessionId: ownerSessionId,
            processGeneration: processGeneration,
            requestId: dialog.id,
          );
          return;
        }
        if (scope == null) {
          _cancel(
            ownerSessionId: ownerSessionId,
            processGeneration: processGeneration,
            requestId: dialog.id,
          );
          return;
        }
        final timeout = _timeoutFor(dialog);
        final remaining = timeout == null ? null : timeout - elapsed.elapsed;
        if (remaining != null && remaining <= Duration.zero) {
          if (dialog is PiEditorDialogRequest) {
            _cancel(
              ownerSessionId: ownerSessionId,
              processGeneration: processGeneration,
              requestId: dialog.id,
            );
          }
          return;
        }
        final tracked = _tracked(
          dialog: dialog,
          ownerSessionId: ownerSessionId,
          processGeneration: processGeneration,
          scope: scope,
        );
        _tracker.add(dialog: tracked);
        _scheduleTimeout(tracked: tracked, timeout: remaining);
        _events.add(PiExtensionUiQuestionAsked(question: _tracker.pending(dialog: tracked)));
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
    if (!_processRepository.sendExtensionUiResponse(
      ownerSessionId: dialog.ownerSessionId,
      generation: dialog.processGeneration,
      requestId: dialog.requestId,
      reply: reply,
    )) {
      _retireUnavailable(dialog: dialog, operation: "reply to Pi extension question");
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
    if (!_processRepository.sendExtensionUiResponse(
      ownerSessionId: dialog.ownerSessionId,
      generation: dialog.processGeneration,
      requestId: dialog.requestId,
      reply: const PiExtensionUiCancelledReply(),
    )) {
      _retireUnavailable(dialog: dialog, operation: "reject Pi extension question");
    }
    _take(questionId: questionId);
    _rejected(dialog);
  }

  void cancelForOwner({required String sessionId, required int? processGeneration}) {
    if (processGeneration == null) {
      _ownerGenerations[sessionId] = (_ownerGenerations[sessionId] ?? 0) + 1;
    } else {
      final cancelledGeneration = _cancelledProcessGenerations[sessionId];
      if (cancelledGeneration == null || processGeneration > cancelledGeneration) {
        _cancelledProcessGenerations[sessionId] = processGeneration;
      }
    }
    for (final dialog in _tracker.takeForOwner(
      sessionId: sessionId,
      processGeneration: processGeneration,
    )) {
      _cancelTimer(questionId: dialog.questionId);
      _processRepository.sendExtensionUiResponse(
        ownerSessionId: dialog.ownerSessionId,
        generation: dialog.processGeneration,
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
      _processRepository.sendExtensionUiResponse(
        ownerSessionId: dialog.ownerSessionId,
        generation: dialog.processGeneration,
        requestId: dialog.requestId,
        reply: const PiExtensionUiCancelledReply(),
      );
      _rejected(dialog);
    }
    _ownerGenerations.clear();
    _cancelledProcessGenerations.clear();
    await _events.close();
  }

  PiTrackedExtensionDialog _tracked({
    required PiExtensionDialogRequest dialog,
    required String ownerSessionId,
    required int processGeneration,
    required ({String displaySessionId, String projectId}) scope,
  }) {
    final questionId = _tracker.nextQuestionId();
    final shared = (
      questionId: questionId,
      requestId: dialog.id,
      ownerSessionId: ownerSessionId,
      processGeneration: processGeneration,
      displaySessionId: scope.displaySessionId,
      projectId: scope.projectId,
    );
    return switch (dialog) {
      PiSelectDialogRequest(:final title, :final options) => PiTrackedSelectDialog(
        questionId: shared.questionId,
        requestId: shared.requestId,
        ownerSessionId: shared.ownerSessionId,
        processGeneration: shared.processGeneration,
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
        processGeneration: shared.processGeneration,
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
        processGeneration: shared.processGeneration,
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
        processGeneration: shared.processGeneration,
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

  Duration? _timeoutFor(PiExtensionDialogRequest dialog) => switch (dialog) {
    PiSelectDialogRequest(:final timeoutMs) ||
    PiConfirmDialogRequest(:final timeoutMs) ||
    PiInputDialogRequest(
      :final timeoutMs,
    ) => timeoutMs != null && timeoutMs > 0 ? Duration(milliseconds: timeoutMs) : null,
    PiEditorDialogRequest() => _editorTimeout,
  };

  void _scheduleTimeout({required PiTrackedExtensionDialog tracked, required Duration? timeout}) {
    if (timeout == null) return;
    _timers[tracked.questionId] = Timer(timeout, () {
      final current = _tracker.find(questionId: tracked.questionId);
      if (!identical(current, tracked)) return;
      _tracker.take(questionId: tracked.questionId);
      _timers.remove(tracked.questionId);
      if (tracked is PiTrackedEditorDialog) {
        _processRepository.sendExtensionUiResponse(
          ownerSessionId: tracked.ownerSessionId,
          generation: tracked.processGeneration,
          requestId: tracked.requestId,
          reply: const PiExtensionUiCancelledReply(),
        );
      }
      _rejected(tracked);
    });
  }

  PiTrackedExtensionDialog _required({required String questionId, required String? sessionId}) {
    final dialog = _tracker.find(questionId: questionId);
    if (dialog == null ||
        (sessionId != null && dialog.ownerSessionId != sessionId && dialog.displaySessionId != sessionId)) {
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

  void _cancel({
    required String ownerSessionId,
    required int processGeneration,
    required String requestId,
  }) {
    _processRepository.sendExtensionUiResponse(
      ownerSessionId: ownerSessionId,
      generation: processGeneration,
      requestId: requestId,
      reply: const PiExtensionUiCancelledReply(),
    );
  }

  Never _retireUnavailable({required PiTrackedExtensionDialog dialog, required String operation}) {
    _take(questionId: dialog.questionId);
    _rejected(dialog);
    throw PluginOperationException.notFound(
      operation,
      message: "The Pi dialog is no longer available.",
    );
  }

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

String _header(String? value, {required String fallback}) => _boundedNullable(value) ?? fallback;

String? _boundedNullable(String? value) => value == null || value.isEmpty ? null : _bounded(value);

String _bounded(String value) {
  final bounded = _runePrefix(value, maxRunes: PiExtensionUiService.maxTextLength);
  if (!bounded.truncated) return value;
  final visible = _runePrefix(
    bounded.text,
    maxRunes: PiExtensionUiService.maxTextLength - 3,
  );
  return "${visible.text}...";
}

String _editorPrompt(String? prefill) {
  const instruction = "Reply with the complete replacement text.";
  if (prefill == null || prefill.isEmpty) return instruction;
  final excerpt = _runePrefix(prefill, maxRunes: PiExtensionUiService.maxTextLength);
  return "$instruction\n\nCurrent text excerpt:\n${excerpt.text}${excerpt.truncated ? "\n\nPrefill was truncated. Omitted text will not be retained." : ""}";
}

({String text, bool truncated}) _runePrefix(String value, {required int maxRunes}) {
  final iterator = value.runes.iterator;
  final prefix = <int>[];
  while (prefix.length < maxRunes && iterator.moveNext()) {
    prefix.add(iterator.current);
  }
  final truncated = iterator.moveNext();
  return (text: truncated ? String.fromCharCodes(prefix) : value, truncated: truncated);
}
