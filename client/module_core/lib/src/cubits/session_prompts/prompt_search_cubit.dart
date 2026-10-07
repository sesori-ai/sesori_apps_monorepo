import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../logging/logging.dart";
import "../../repositories/models/session_prompt_search_result.dart";
import "../../repositories/session_repository.dart";
import "../session_detail/transcript_prompt_list.dart";
import "prompt_search_state.dart";

/// How long typing pauses before the bridge is asked.
const _kBridgeDebounce = Duration(milliseconds: 250);

/// How long the bridge searches before the screen says it is searching, so a
/// quick answer shows no such word.
const _kSlowAfter = Duration(milliseconds: 150);

/// The Prompts screen's search. The listed prompts' own text matches at once.
/// When the list holds every prompt of the session, the bridge also searches
/// each prompt's whole text, and the listed rows of the prompts it finds join
/// the matches. The latest query wins.
class PromptSearchCubit({
  required final SessionRepository _sessionRepository,
  required final String _sessionId,
  required var TranscriptPromptList _prompts,
}) extends Cubit<PromptSearchState> {
  RegExp? _pattern;

  /// The bridge's matches for [_pattern] by message id; empty until it answers.
  Map<String, SessionPromptExcerpt> _bridgeMatches = const {};

  /// Set once the bridge answers that it predates search, for the rest of the
  /// screen.
  bool _unsupported = false;

  /// Counts searches; a bridge answer lands only while its search is the latest.
  int _searches = 0;
  Timer? _debounce;
  Timer? _slow;

  this : super(const PromptSearchIdle(query: ""));

  bool get _asksBridge => _prompts.isIndexed && !_unsupported;

  /// Takes the screen's list after every relist; the matches follow it.
  void showPrompts({required TranscriptPromptList prompts}) {
    final wasIndexed = _prompts.isIndexed;
    _prompts = prompts;
    switch (state) {
      case PromptSearchIdle():
        return;
      // The prompt index arrived during a search of the loaded prompts alone.
      case PromptSearchActive(:final query, earlier: EarlierPromptSearch.listedOnly) when !wasIndexed && _asksBridge:
        _start(query: query, pattern: _pattern);
      case PromptSearchActive(:final query, :final earlier):
        _emitActive(query: query, earlier: earlier);
    }
  }

  void search({required String query}) {
    final pattern = promptSearchPattern(query: query);
    if (pattern?.pattern != _pattern?.pattern) {
      _start(query: query, pattern: pattern);
      return;
    }
    // Only the whitespace around the search changed.
    emit(switch (state) {
      PromptSearchIdle() => PromptSearchIdle(query: query),
      PromptSearchActive(:final matches, :final earlier) => PromptSearchActive(
        query: query,
        matches: matches,
        earlier: earlier,
      ),
    });
  }

  /// Asks the bridge again after its search failed.
  void retry() {
    if (state case PromptSearchActive(:final query, earlier: EarlierPromptSearch.failed)) {
      final search = ++_searches;
      _emitActive(query: query, earlier: EarlierPromptSearch.pending);
      unawaited(_askBridge(search: search, query: query));
    }
  }

  void _start({required String query, required RegExp? pattern}) {
    final search = ++_searches;
    _debounce?.cancel();
    _slow?.cancel();
    _pattern = pattern;
    _bridgeMatches = const {};
    if (pattern == null) {
      emit(PromptSearchIdle(query: query));
      return;
    }
    if (!_asksBridge) {
      _emitActive(query: query, earlier: EarlierPromptSearch.listedOnly);
      return;
    }
    _emitActive(query: query, earlier: EarlierPromptSearch.pending);
    _debounce = Timer(_kBridgeDebounce, () => unawaited(_askBridge(search: search, query: query)));
  }

  Future<void> _askBridge({required int search, required String query}) async {
    // The field's text may since differ in whitespace alone, so each emit
    // keeps the state's own query.
    _slow = Timer(_kSlowAfter, () => _emitActive(query: state.query, earlier: EarlierPromptSearch.slow));
    final result = await _sessionRepository.searchPrompts(sessionId: _sessionId, query: query);
    if (isClosed || search != _searches) return;
    _slow?.cancel();
    switch (result) {
      case SessionPromptSearchAvailable(:final matches):
        _bridgeMatches = {for (final match in matches) match.messageId: match.excerpt};
        _emitActive(query: state.query, earlier: EarlierPromptSearch.done);
      case SessionPromptSearchUnsupported():
        _unsupported = true;
        _emitActive(query: state.query, earlier: EarlierPromptSearch.listedOnly);
      case SessionPromptSearchFailure(:final error):
        logw("Failed to search the session's earlier prompts", error);
        _emitActive(query: state.query, earlier: EarlierPromptSearch.failed);
    }
  }

  /// Emits the listed prompts that match, in the list's order: by their own
  /// text, else by the bridge's search of their whole text.
  void _emitActive({required String query, required EarlierPromptSearch earlier}) {
    final pattern = _pattern;
    if (pattern == null) return;
    final matches = <String, SessionPromptExcerpt>{};
    for (final entry in _prompts.entries) {
      final text = entry.searchText;
      final match = text == null ? null : pattern.firstMatch(text);
      final excerpt = text != null && match != null
          ? promptExcerpt(text: text, match: match)
          : _bridgeMatches[entry.messageId];
      if (excerpt != null) matches[entry.messageId] = excerpt;
    }
    emit(PromptSearchActive(query: query, matches: matches, earlier: earlier));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    _slow?.cancel();
    return super.close();
  }
}
