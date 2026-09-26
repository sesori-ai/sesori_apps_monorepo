import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../capabilities/server_connection/connection_service.dart";
import "../capabilities/server_connection/models/sse_event.dart";
import "../foundation/models/feedback/feedback_prompt_config.dart";
import "../foundation/models/feedback/feedback_prompt_state.dart";
import "../logging/logging.dart";
import "../repositories/feedback_prompt_repository.dart";

/// Decides when the rating sheet opens by itself.
///
/// Every big successful interaction adds a point; any meaningful error resets
/// the count to zero. Once the count reaches the configured threshold and the
/// cooldown since the last automatic showing has passed, the service resets
/// the count, records the showing and emits on [prompts]. Answering **Yes**
/// retires the automatic sheet for good.
///
/// Only the mobile shell calls [start]. Until then every record call is a
/// no-op, so the desktop shell, which shares the recording cubits but never
/// shows the sheet, stores nothing.
@lazySingleton
class FeedbackPromptService({
  required final ConnectionService _connectionService,
  required final FeedbackPromptRepository _repository,
}) {
  final StreamController<void> _prompts = StreamController<void>.broadcast();

  /// Fetched once per launch, on first use.
  late final Future<FeedbackPromptConfig> _config = _repository.readConfig();

  StreamSubscription<SseEvent>? _eventsSubscription;

  /// Serializes the read-modify-write updates of the stored progress.
  Future<void> _lastUpdate = Future<void>.value();

  /// Emits once for each automatic showing, right after it is recorded.
  Stream<void> get prompts => _prompts.stream;

  /// Starts recording and resets the count on AI errors from any session.
  void start() {
    _eventsSubscription ??= _connectionService.events.listen(_onEvent);
    unawaited(_config);
  }

  /// Sending a message, creating a session with one, or answering a question
  /// or permission request succeeded.
  Future<void> recordPositiveInteraction() => _update(() async {
    final state = await _repository.readState();
    if (state is! FeedbackPromptCounting) return;
    final positiveCount = state.positiveCount + 1;
    final config = await _config;
    final now = DateTime.now().toUtc();
    final lastShownAt = state.lastShownAt;
    final isDue =
        positiveCount >= config.interactionThreshold &&
        (lastShownAt == null || now.difference(lastShownAt) >= config.cooldown);
    if (!isDue) {
      await _repository.writeState(
        state: FeedbackPromptCounting(positiveCount: positiveCount, lastShownAt: lastShownAt),
      );
      return;
    }
    // Claiming the showing in the same write that resets the count means the
    // next one needs a fresh run of good interactions and the full cooldown.
    await _repository.writeState(state: FeedbackPromptCounting(positiveCount: 0, lastShownAt: now));
    logi("Showing the automatic rating sheet after $positiveCount good interactions");
    if (!_prompts.isClosed) _prompts.add(null);
  });

  /// A meaningful error: an AI error, a failed send or reply, or a crash.
  Future<void> recordFailure() => _update(() async {
    final state = await _repository.readState();
    if (state case FeedbackPromptCounting(:final positiveCount, :final lastShownAt) when positiveCount > 0) {
      await _repository.writeState(state: FeedbackPromptCounting(positiveCount: 0, lastShownAt: lastShownAt));
    }
  });

  /// The user answered **Yes** from either entry.
  Future<void> recordYes() => _update(() => _repository.writeState(state: const FeedbackPromptRetired()));

  void _onEvent(SseEvent event) {
    if (event.data
        case SesoriMessageUpdated(info: MessageError()) ||
            SesoriSessionStatus(status: SessionStatusRetry()) ||
            SesoriSessionError()) {
      unawaited(recordFailure());
    }
  }

  Future<void> _update(Future<void> Function() update) {
    if (_eventsSubscription == null) return Future<void>.value();
    return _lastUpdate = _lastUpdate.then((_) => update()).catchError((Object error, StackTrace stackTrace) {
      logw("Failed to update the automatic rating sheet progress", error, stackTrace);
    });
  }

  @disposeMethod
  Future<void> dispose() async {
    await _eventsSubscription?.cancel();
    _eventsSubscription = null;
    await _prompts.close();
  }
}
