import "dart:async";

import "package:bloc/bloc.dart";
import "package:collection/collection.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

import "../../foundation/models/product_analytics/product_analytics_event.dart";
import "../../foundation/models/side_question_availability.dart";
import "../../logging/logging.dart";
import "../../repositories/models/analytics_delivery_result.dart";
import "../../repositories/side_chat_repository.dart";
import "../../services/product_analytics_service.dart";
import "side_chat_state.dart";

/// One session's side chats while the side sheet or panel is open. It loads
/// them once on open and never polls: another surface's new exchanges show the
/// next time the chats are opened.
///
/// Only one question is asked at a time, and the shown chat can't change
/// while it waits, so its answer always lands in the chat it was asked in.
/// Closing the cubit doesn't cancel an ask: the bridge still stores the
/// answer.
class SideChatCubit({
  required final SideChatRepository _repository,
  required final ProductAnalyticsService _productAnalyticsService,
  required final String _sessionId,
  required final String _pluginId,
  required final SideQuestionAvailability _availability,
  required final bool _isArchived,

  /// Asked in a new chat right away, as `/btw` mode hands its text over;
  /// null when the user opened the side chat to type. It shows as asked from
  /// the start, so the sheet never opens on a spinner, and it doesn't wait
  /// for the earlier chats, so neither closing the sheet nor a failed load
  /// can drop it.
  required String? initialQuestion,
}) extends Cubit<SideChatState> {
  this
    : super(switch (initialQuestion) {
        final question? when !_isArchived && _availability == SideQuestionAvailability.available => SideChatState.ready(
          earlierChats: const [],
          thread: const SideChatThread.newChat(),
          ask: SideQuestionAsk.waiting(question: question),
        ),
        _ => const SideChatState.loading(),
      }) {
    if (state case SideChatReady(ask: SideQuestionWaiting(:final question))) {
      unawaited(_send(question: question, thread: const SideChatThread.newChat()));
    }
    unawaited(_load());
  }

  /// Whether new questions can be asked. An archived session's side chats
  /// are read-only.
  bool get canAsk => !_isArchived && _availability == SideQuestionAvailability.available;

  /// Loads the chats again after a failed load.
  Future<void> reload() async {
    if (state is! SideChatLoadFailed) return;
    emit(const SideChatState.loading());
    await _load();
  }

  /// Asks [text] in the shown chat. Does nothing while another question
  /// waits, for blank text, or when [canAsk] is false.
  Future<void> ask({required String text}) async {
    final question = text.trim();
    final current = state;
    if (question.isEmpty || !canAsk || current is! SideChatReady || current.ask is SideQuestionWaiting) return;
    emit(current.copyWith(ask: SideQuestionAsk.waiting(question: question)));
    await _send(question: question, thread: current.thread);
  }

  /// Asks [question] in [thread], which the state already shows as waiting.
  Future<void> _send({required String question, required SideChatThread thread}) async {
    final sideChatId = switch (thread) {
      SideChatNewThread() => null,
      SideChatExistingThread(:final chat) => chat.id,
    };
    final response = await _repository.askSideQuestion(
      sessionId: _sessionId,
      sideChatId: sideChatId,
      question: question,
    );
    _reportOutcome(response: response);
    if (isClosed) return;

    final waiting = state;
    if (waiting is! SideChatReady) return;
    switch (response) {
      case SuccessResponse(data: AskSideQuestionAnswered(sideChatId: final answeredChatId, :final exchange)):
        final earlier = switch (waiting.thread) {
          SideChatNewThread() => const <SideChatExchange>[],
          SideChatExistingThread(:final chat) => chat.exchanges,
        };
        emit(
          waiting.copyWith(
            thread: SideChatThread.existing(
              chat: SideChat(id: answeredChatId, exchanges: [...earlier, exchange]),
            ),
            ask: const SideQuestionAsk.idle(),
          ),
        );
      case SuccessResponse(data: AskSideQuestionRefused(:final reason)):
        emit(
          waiting.copyWith(
            ask: SideQuestionAsk.refused(question: question, reason: reason),
          ),
        );
      case SuccessResponse(data: AskSideQuestionUnknown()):
        emit(
          waiting.copyWith(
            ask: SideQuestionAsk.refused(question: question, reason: SideQuestionRefusal.unknown),
          ),
        );
      case ErrorResponse(:final error):
        logw("Failed to ask a side question in session $_sessionId", error);
        emit(waiting.copyWith(ask: SideQuestionAsk.failed(question: question)));
    }
  }

  /// Asks the refused or failed question again.
  Future<void> retry() async {
    switch (state) {
      case SideChatReady(ask: SideQuestionRefused(:final question) || SideQuestionFailed(:final question)):
        await ask(text: question);
      case SideChatReady() || SideChatLoading() || SideChatLoadFailed():
        return;
    }
  }

  /// Shows the earlier chat [id], to read or continue it.
  void openChat({required String id}) {
    final current = state;
    if (current is! SideChatReady || current.ask is SideQuestionWaiting) return;
    final chat = current.earlierChats.firstWhereOrNull((chat) => chat.id == id);
    if (chat == null) return;
    emit(
      _showing(
        current: current,
        thread: SideChatThread.existing(chat: chat),
      ),
    );
  }

  /// Shows a new, empty chat.
  void startNewChat() {
    final current = state;
    if (current is! SideChatReady || current.ask is SideQuestionWaiting) return;
    if (current.thread is SideChatNewThread) return;
    emit(_showing(current: current, thread: const SideChatThread.newChat()));
  }

  Future<void> _load() async {
    final response = await _repository.listSideChats(sessionId: _sessionId);
    if (isClosed) return;
    switch (response) {
      case SuccessResponse(:final data):
        final current = state;
        final loaded = switch (data.sideChats) {
          // Nothing can be asked in an archived session, so it opens on the
          // newest chat to read instead of an empty new one.
          [final newest, ...final earlier] when _isArchived => SideChatState.ready(
            earlierChats: earlier,
            thread: SideChatThread.existing(chat: newest),
            ask: const SideQuestionAsk.idle(),
          ),
          // A handed-over question is already shown and asked; the list may
          // hold its chat once answered.
          final chats when current is SideChatReady => current.copyWith(
            earlierChats: [
              for (final chat in chats)
                if (!_shows(thread: current.thread, chatId: chat.id)) chat,
            ],
          ),
          final chats => SideChatState.ready(
            earlierChats: chats,
            thread: const SideChatThread.newChat(),
            ask: const SideQuestionAsk.idle(),
          ),
        };
        emit(loaded);
      case ErrorResponse(:final error):
        logw("Failed to load the side chats of session $_sessionId", error);
        // A handed-over question stays on screen; only its earlier chats are
        // missing.
        if (state is! SideChatReady) emit(const SideChatState.loadFailed());
    }
  }

  /// [current] showing [thread] instead, with the chat it showed back among
  /// the earlier ones.
  SideChatReady _showing({required SideChatReady current, required SideChatThread thread}) {
    final leaving = switch (current.thread) {
      SideChatNewThread() => null,
      SideChatExistingThread(:final chat) => chat,
    };
    final shownId = switch (thread) {
      SideChatNewThread() => null,
      SideChatExistingThread(:final chat) => chat.id,
    };
    final earlierChats = [
      for (final chat in [...current.earlierChats, ?leaving])
        if (chat.id != shownId) chat,
    ];
    mergeSort(
      earlierChats,
      compare: (a, b) => _lastAnsweredAt(chat: b).compareTo(_lastAnsweredAt(chat: a)),
    );
    return SideChatReady(earlierChats: earlierChats, thread: thread, ask: const SideQuestionAsk.idle());
  }

  static bool _shows({required SideChatThread thread, required String chatId}) => switch (thread) {
    SideChatNewThread() => false,
    SideChatExistingThread(:final chat) => chat.id == chatId,
  };

  static int _lastAnsweredAt({required SideChat chat}) => chat.exchanges.lastOrNull?.answeredAt ?? 0;

  void _reportOutcome({required ApiResponse<AskSideQuestionResponse> response}) {
    final outcome = switch (response) {
      SuccessResponse(data: AskSideQuestionAnswered()) => AnalyticsSideQuestionOutcome.answered,
      SuccessResponse(data: AskSideQuestionRefused(reason: SideQuestionRefusal.noAnswer)) =>
        AnalyticsSideQuestionOutcome.noAnswer,
      SuccessResponse(data: AskSideQuestionRefused()) => AnalyticsSideQuestionOutcome.unavailable,
      SuccessResponse(data: AskSideQuestionUnknown()) || ErrorResponse() => AnalyticsSideQuestionOutcome.failed,
    };
    unawaited(
      _productAnalyticsService
          .logEvent(
            event: ProductAnalyticsEvent.sideQuestionAsked(
              harness: AnalyticsHarness.fromPluginId(pluginId: _pluginId),
              outcome: outcome,
            ),
            occurredAtUtc: DateTime.now().toUtc(),
          )
          .then<void>((result) {
            if (result == AnalyticsDeliveryResult.failed && _productAnalyticsService.state.isActive) {
              logw("Failed to deliver side question analytics event");
            }
          })
          .catchError((Object error, StackTrace stackTrace) {
            logw("Failed to report side question analytics event", error, stackTrace);
          }),
    );
  }
}
