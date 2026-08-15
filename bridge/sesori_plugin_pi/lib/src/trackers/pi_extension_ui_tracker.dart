import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

sealed class const PiTrackedExtensionDialog({
  required final String questionId,
  required final String requestId,
  required final String ownerSessionId,
  required final int processGeneration,
  required final String displaySessionId,
  required final String projectId,
  required final PluginQuestionInfo question,
});

final class const PiTrackedSelectDialog({
  required super.questionId,
  required super.requestId,
  required super.ownerSessionId,
  required super.processGeneration,
  required super.displaySessionId,
  required super.projectId,
  required super.question,
  required final Set<String> options,
}) extends PiTrackedExtensionDialog;

final class const PiTrackedConfirmDialog({
  required super.questionId,
  required super.requestId,
  required super.ownerSessionId,
  required super.processGeneration,
  required super.displaySessionId,
  required super.projectId,
  required super.question,
}) extends PiTrackedExtensionDialog;

final class const PiTrackedInputDialog({
  required super.questionId,
  required super.requestId,
  required super.ownerSessionId,
  required super.processGeneration,
  required super.displaySessionId,
  required super.projectId,
  required super.question,
}) extends PiTrackedExtensionDialog;

final class const PiTrackedEditorDialog({
  required super.questionId,
  required super.requestId,
  required super.ownerSessionId,
  required super.processGeneration,
  required super.displaySessionId,
  required super.projectId,
  required super.question,
}) extends PiTrackedExtensionDialog;

final class PiExtensionUiTracker() {
  final Map<String, PiTrackedExtensionDialog> _byQuestionId = {};
  final Map<String, Set<String>> _byOwner = {};
  final Map<String, Set<String>> _byDisplaySession = {};
  final Map<String, Set<String>> _byProject = {};
  var _nextQuestionId = 1;

  String nextQuestionId() => "pi-extension-${_nextQuestionId++}";

  void add({required PiTrackedExtensionDialog dialog}) {
    _byQuestionId[dialog.questionId] = dialog;
    _index(_byOwner, dialog.ownerSessionId, dialog.questionId);
    _index(_byDisplaySession, dialog.displaySessionId, dialog.questionId);
    _index(_byProject, dialog.projectId, dialog.questionId);
  }

  PiTrackedExtensionDialog? find({required String questionId}) => _byQuestionId[questionId];

  PluginPendingQuestion pending({required PiTrackedExtensionDialog dialog}) => _pending(dialog);

  PiTrackedExtensionDialog? take({required String questionId}) {
    final dialog = _byQuestionId.remove(questionId);
    if (dialog == null) return null;
    _unindex(_byOwner, dialog.ownerSessionId, questionId);
    _unindex(_byDisplaySession, dialog.displaySessionId, questionId);
    _unindex(_byProject, dialog.projectId, questionId);
    return dialog;
  }

  List<PluginPendingQuestion> pendingForSession({required String sessionId}) {
    final ids = {...?_byOwner[sessionId], ...?_byDisplaySession[sessionId]};
    return _forQuestionId(ids).map(_pending).toList(growable: false);
  }

  List<PluginPendingQuestion> pendingForProject({required String projectId}) =>
      _forQuestionId(_byProject[projectId] ?? const {}).map(_pending).toList(growable: false);

  List<PiTrackedExtensionDialog> takeForOwner({
    required String sessionId,
    required int? processGeneration,
  }) => _takeMany(
    processGeneration == null
        ? _byOwner[sessionId]
        : {
            for (final id in _byOwner[sessionId] ?? const <String>{})
              if (_byQuestionId[id]?.processGeneration == processGeneration) id,
          },
  );

  List<PiTrackedExtensionDialog> takeAll() => _takeMany(_byQuestionId.keys.toSet());

  Iterable<PiTrackedExtensionDialog> _forQuestionId(Iterable<String> ids) sync* {
    for (final id in ids) {
      final dialog = _byQuestionId[id];
      if (dialog != null) yield dialog;
    }
  }

  List<PiTrackedExtensionDialog> _takeMany(Set<String>? ids) {
    if (ids == null) return const [];
    final dialogs = <PiTrackedExtensionDialog>[];
    for (final id in ids.toList(growable: false)) {
      final dialog = take(questionId: id);
      if (dialog != null) dialogs.add(dialog);
    }
    return dialogs;
  }
}

PluginPendingQuestion _pending(PiTrackedExtensionDialog dialog) => PluginPendingQuestion(
  id: dialog.questionId,
  sessionID: dialog.ownerSessionId,
  displaySessionId: dialog.displaySessionId,
  questions: [dialog.question],
);

void _index(Map<String, Set<String>> index, String key, String questionId) =>
    index.putIfAbsent(key, () => {}).add(questionId);

void _unindex(Map<String, Set<String>> index, String key, String questionId) {
  final ids = index[key];
  ids?.remove(questionId);
  if (ids?.isEmpty ?? false) index.remove(key);
}
