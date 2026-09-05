import "package:sesori_shared/sesori_shared.dart";

/// Merges a freshly fetched transcript page with the live changes a session
/// received while that fetch was in flight.
///
/// A silent refresh used to install the fetched page wholesale, which dropped
/// every message and part event that arrived between the request and its
/// response. This is the one owner of the before/live/fetched merge policy:
/// the fetched page is the base, live changes observed since the fetch began
/// are overlaid, and removals observed live are honored. Matching is by
/// message and part ID; "changed" is value inequality against the transcript
/// as it was when the fetch started.
///
/// Pure and stateless: three immutable lists in, one immutable list out. It
/// cannot see history that happened entirely inside the fetch window and
/// left no trace in either list, and it does not try to.
class const TranscriptSnapshotCalculator() {
  /// Reconciles [fetched] with the live transcript.
  ///
  /// [before] is the transcript when the fetch started, [live] the transcript
  /// when the fetch completed, [fetched] the page the fetch returned.
  ///
  /// - Fetched messages keep their supplied order. One removed live since
  ///   [before] is omitted.
  /// - A matching message takes its live envelope only when that envelope
  ///   changed since [before]; otherwise the fetched envelope stands. Its
  ///   fetched parts stay in fetched order, live changes and additions overlay
  ///   them, and parts removed live since [before] are dropped.
  /// - A live message the page does not contain is kept when it was added or
  ///   changed since [before]; it joins at [insertionIndex]. One the page
  ///   omits without any live change is gone: the page is authoritative for
  ///   what it did not see change.
  List<MessageWithParts> reconcile({
    required List<MessageWithParts> before,
    required List<MessageWithParts> live,
    required List<MessageWithParts> fetched,
  }) {
    final beforeById = {for (final message in before) message.info.id: message};
    final liveById = {for (final message in live) message.info.id: message};

    final result = <MessageWithParts>[];
    for (final fetchedMessage in fetched) {
      final id = fetchedMessage.info.id;
      final beforeMessage = beforeById[id];
      final liveMessage = liveById[id];
      if (liveMessage == null) {
        if (beforeMessage == null) result.add(fetchedMessage);
        continue;
      }
      result.add(_reconcileMessage(before: beforeMessage, live: liveMessage, fetched: fetchedMessage));
    }

    final fetchedIds = {for (final message in fetched) message.info.id};
    for (final liveMessage in live) {
      final id = liveMessage.info.id;
      if (fetchedIds.contains(id) || liveMessage == beforeById[id]) continue;
      result.insert(insertionIndex(messages: result, message: liveMessage.info), liveMessage);
    }
    return result;
  }

  /// Where a live message joins [messages]: before the first timestamped
  /// message created after it. Existing messages without a creation time are
  /// skipped, and a message without one is appended at the end. This is the
  /// ordering live insertion has always used, moved here unchanged.
  int insertionIndex({required List<MessageWithParts> messages, required Message message}) {
    final created = message.time?.created;
    if (created == null) return messages.length;
    for (var index = 0; index < messages.length; index++) {
      final existingCreated = messages[index].info.time?.created;
      if (existingCreated != null && existingCreated > created) return index;
    }
    return messages.length;
  }

  MessageWithParts _reconcileMessage({
    required MessageWithParts? before,
    required MessageWithParts live,
    required MessageWithParts fetched,
  }) {
    final info = live.info == before?.info ? fetched.info : live.info;
    final beforeParts = {for (final part in before?.parts ?? const <MessagePart>[]) part.id: part};
    final liveParts = {for (final part in live.parts) part.id: part};

    final parts = <MessagePart>[];
    for (final fetchedPart in fetched.parts) {
      final beforePart = beforeParts[fetchedPart.id];
      final livePart = liveParts[fetchedPart.id];
      if (livePart == null) {
        if (beforePart == null) parts.add(fetchedPart);
        continue;
      }
      parts.add(livePart == beforePart ? fetchedPart : livePart);
    }
    final fetchedIds = {for (final part in fetched.parts) part.id};
    for (final livePart in live.parts) {
      if (fetchedIds.contains(livePart.id) || livePart == beforeParts[livePart.id]) continue;
      parts.add(livePart);
    }
    return MessageWithParts(info: info, parts: parts);
  }
}
