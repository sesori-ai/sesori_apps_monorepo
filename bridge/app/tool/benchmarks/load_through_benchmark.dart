import "dart:convert";
import "dart:io";

import "package:sesori_bridge/src/repositories/chat_history_repository.dart";
import "package:sesori_bridge/src/repositories/models/history_window.dart";
import "package:sesori_shared/sesori_shared.dart";

import "synthetic_session.dart";

/// Times one load-through response that carries the whole synthetic session
/// (9,790 messages and 836 prompts): the bridge's read, encode and deflate,
/// then the app's inflate and decode, which runs on the UI isolate.
/// Run from bridge/app: dart run tool/benchmarks/load_through_benchmark.dart
Future<void> main() async {
  final session = await openSyntheticSession();
  try {
    // Every stored seq lies in this range, so one response carries the session.
    const window = HistoryWindowThrough(throughSeq: 0, before: 1 << 40);

    late MessageWithPartsResponse response;
    await timeRuns(
      label: "Bridge read",
      operation: () async {
        final page = await session.repository.getSessionMessages(
          sessionId: syntheticSessionId,
          storageScope: syntheticStorageScope,
          window: window,
          attachmentProjection: const StoredReferenceMessageAttachmentProjection(bridgeId: "benchmark"),
        );
        response = MessageWithPartsResponse(
          messages: page.messages,
          nextCursor: page.nextCursor,
          replayedPromptDefaults: null,
          awaitingHarnessSync: false,
          userMessagesBefore: page.userMessagesBefore,
          cannotContinueMessage: null,
        );
      },
    );

    late List<int> plaintext;
    await timeRuns(
      label: "Bridge encode",
      operation: () async {
        final envelope = RelayMessage.response(
          id: "benchmark",
          status: 200,
          headers: const {},
          body: jsonEncode(response.toJson()),
        );
        plaintext = utf8.encode(jsonEncode(envelope.toJson()));
      },
    );
    late List<int> deflated;
    await timeRuns(
      label: "Bridge deflate",
      operation: () async => deflated = ZLibEncoder(raw: true).convert(plaintext),
    );
    stdout.writeln(
      "Response: ${(plaintext.length / 1e6).toStringAsFixed(1)} MB, "
      "deflated ${(deflated.length / 1e6).toStringAsFixed(1)} MB.",
    );

    var decodedMessages = 0;
    await timeRuns(
      label: "App inflate and decode",
      operation: () async {
        final envelope = RelayMessage.fromJson(
          jsonDecode(utf8.decode(ZLibDecoder(raw: true).convert(deflated))) as Map<String, dynamic>,
        );
        final body = switch (envelope) {
          RelayResponse(:final String body) => body,
          _ => throw StateError("Expected a response envelope with a body"),
        };
        decodedMessages = MessageWithPartsResponse.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        ).messages.length;
      },
    );
    stdout.writeln("The app decoded $decodedMessages messages.");
  } finally {
    await session.close();
  }
}
