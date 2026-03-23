import "dart:async";

import "package:bloc/bloc.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../capabilities/server_connection/connection_service.dart";
import "../../capabilities/session/session_service.dart";
import "diff_state.dart";

class DiffCubit extends Cubit<DiffState> {
  final SessionService _service;
  final ConnectionService _connectionService;
  final String sessionId;
  final String? initialMessageId;

  StreamSubscription<SesoriSessionEvent>? _sseSubscription;

  DiffCubit({
    required SessionService service,
    required ConnectionService connectionService,
    required this.sessionId,
    this.initialMessageId,
  }) : _service = service,
       _connectionService = connectionService,
       super(const DiffState.loading()) {
    _init();
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> _init() async {
    try {
      // Fetch messages first, then diffs sequentially to keep error handling
      // simple and avoid dangling parallel futures on early failure.
      final messagesResponse = await _service.getMessages(sessionId);
      if (isClosed) return;

      final List<MessageWithParts> messages;
      switch (messagesResponse) {
        case SuccessResponse(:final data):
          messages = data;
        case ErrorResponse(:final error):
          if (!isClosed) emit(DiffState.failed(error: error));
          return;
      }

      final diffsResponse = await (initialMessageId != null
          ? _service.getMessageDiffs(sessionId, initialMessageId!)
          : _service.getSessionDiffs(sessionId));
      if (isClosed) return;

      final List<FileDiff> files;
      switch (diffsResponse) {
        case SuccessResponse(:final data):
          files = data;
        case ErrorResponse(:final error):
          if (!isClosed) emit(DiffState.failed(error: error));
          return;
      }

      // Subscribe to SSE session events after all data is loaded.
      _sseSubscription = _connectionService.sessionEvents(sessionId).listen(_handleEvent);

      if (!isClosed) {
        emit(
          DiffState.loaded(
            files: files,
            messages: messages,
            hasNewChanges: false,
            selectedMessageId: initialMessageId,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) emit(DiffState.failed(error: e));
    }
  }

  // ---------------------------------------------------------------------------
  // SSE event handling
  // ---------------------------------------------------------------------------

  void _handleEvent(SesoriSessionEvent event) {
    switch (event) {
      case SesoriSessionDiff():
        _onSessionDiff();
      default:
        break;
    }
  }

  void _onSessionDiff() {
    final current = state;
    if (current is! DiffStateLoaded) return;
    if (isClosed) return;
    emit(current.copyWith(hasNewChanges: true));
  }

  // ---------------------------------------------------------------------------
  // Public actions
  // ---------------------------------------------------------------------------

  /// Re-fetches diffs for the currently selected message (or session-level if
  /// none) and clears the [DiffStateLoaded.hasNewChanges] flag.
  Future<void> refresh() async {
    final current = state;
    if (current is DiffStateFailed) {
      if (!isClosed) emit(const DiffState.loading());
      return _init();
    }

    if (current is! DiffStateLoaded) return;

    try {
      final messageId = current.selectedMessageId;
      final diffsResponse = messageId != null
          ? await _service.getMessageDiffs(sessionId, messageId)
          : await _service.getSessionDiffs(sessionId);

      if (isClosed) return;

      switch (diffsResponse) {
        case SuccessResponse(:final data):
          final loaded = state;
          if (loaded is DiffStateLoaded && !isClosed) {
            emit(loaded.copyWith(files: data, hasNewChanges: false));
          }
        case ErrorResponse(:final error):
          if (!isClosed) emit(DiffState.failed(error: error));
      }
    } catch (e) {
      if (!isClosed) emit(DiffState.failed(error: e));
    }
  }

  /// Switches to diffs scoped to [messageId] (or session-level if null).
  /// Emits [DiffState.loading] while fetching, then [DiffState.loaded].
  Future<void> selectMessage(String? messageId) async {
    final currentMessages = switch (state) {
      DiffStateLoaded(:final messages) => messages,
      _ => <MessageWithParts>[],
    };

    emit(const DiffState.loading());

    try {
      final diffsResponse = messageId != null
          ? await _service.getMessageDiffs(sessionId, messageId)
          : await _service.getSessionDiffs(sessionId);

      if (isClosed) return;

      switch (diffsResponse) {
        case SuccessResponse(:final data):
          if (!isClosed) {
            emit(
              DiffState.loaded(
                files: data,
                messages: currentMessages,
                hasNewChanges: false,
                selectedMessageId: messageId,
              ),
            );
          }
        case ErrorResponse(:final error):
          if (!isClosed) emit(DiffState.failed(error: error));
      }
    } catch (e) {
      if (!isClosed) emit(DiffState.failed(error: e));
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<void> close() {
    _sseSubscription?.cancel();
    return super.close();
  }
}
