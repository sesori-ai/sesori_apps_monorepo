import "dart:async";
import "dart:typed_data";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;

import "../api/models/realtime_voice_protocol.dart";
import "../api/realtime_voice_api.dart";
import "../api/voice_capabilities_api.dart";
import "../capabilities/voice/voice_api.dart";
import "../models/voice_capabilities.dart";
import "../models/voice_realtime.dart";

@lazySingleton
class VoiceRepository({
  required final VoiceApi _api,
  required final VoiceCapabilitiesApi _capabilitiesApi,
  required final RealtimeVoiceApi _realtimeApi,
}) {
  Future<VoiceCapabilitiesDiscoveryOutcome> discoverCapabilities() async {
    final response = await _capabilitiesApi.discover();
    return switch (response) {
      SuccessResponse(:final data) when data.protocolVersions.contains(1) => VoiceCapabilitiesAvailable(
        capabilities: VoiceCapabilities(
          realtimeEnabled: data.realtimeEnabled,
          supportsProtocol1: true,
        ),
      ),
      SuccessResponse() => const VoiceCapabilitiesContractFailure(
        reason: "Realtime protocol 1 was not advertised",
      ),
      ErrorResponse(error: JsonParsingError()) => const VoiceCapabilitiesContractFailure(
        reason: "Realtime capability response could not be parsed",
      ),
      // COMPATIBILITY 2026-08-14 (v1.8.2): Auth servers before capability discovery, disabled rollout
      // deployments, and transient public endpoint failures preserve the released async transcription path.
      // Remove only after every supported auth server exposes protocol 1.
      ErrorResponse() => const VoiceCapabilitiesAsyncFallback(),
    };
  }

  Future<VoiceRealtimeOpenOutcome> openRealtime({
    required VoiceRealtimeAudioFormat audio,
    required ProjectGlossaryKey? projectKey,
  }) async {
    try {
      final session = await _realtimeApi.start(
        audio: RealtimeAudioFormat(sampleRate: audio.sampleRate),
        projectKey: projectKey,
      );
      return VoiceRealtimeOpenOutcome.opened(connection: _ApiVoiceRealtimeConnection(session: session));
    } on RealtimeVoiceOpenAuthenticationException catch (error) {
      return VoiceRealtimeOpenOutcome.notAuthenticated(cause: error);
    } on RealtimeVoiceOpenHandshakeNotFoundException catch (error) {
      return VoiceRealtimeOpenOutcome.asyncFallback(cause: error);
    } on RealtimeVoiceOpenHandshakeRateLimitedException catch (error) {
      return VoiceRealtimeOpenOutcome.asyncFallback(cause: error);
    } on RealtimeVoiceOpenTimeoutException catch (error) {
      return VoiceRealtimeOpenOutcome.asyncFallback(cause: error);
    } on RealtimeVoiceOpenTransportException catch (error) {
      return VoiceRealtimeOpenOutcome.asyncFallback(cause: error);
    } on RealtimeVoiceProtocolException catch (error) {
      return VoiceRealtimeOpenOutcome.contractFailure(reason: error.message, cause: error);
    } on Object catch (error) {
      return VoiceRealtimeOpenOutcome.unexpectedFailure(error: error);
    }
  }

  Future<VoiceTranscriptionOutcome> transcribe({
    required String audioFilePath,
    required String mimeType,
    required ProjectGlossaryKey? projectKey,
  }) async {
    final response = await _api.transcribe(
      audioFilePath: audioFilePath,
      mimeType: mimeType,
      projectKey: projectKey,
    );
    return switch (response) {
      VoiceTranscriptionApiSuccess(:final transcript) => VoiceTranscriptionOutcome.success(
        transcript: transcript,
      ),
      VoiceTranscriptionApiFailure(:final error, :final retryable) => _mapError(
        error: error,
        retryable: retryable,
      ),
    };
  }

  VoiceTranscriptionOutcome _mapError({
    required ApiError error,
    required bool? retryable,
  }) => switch (error) {
    NotAuthenticatedError() => const VoiceTranscriptionOutcome.notAuthenticated(),
    NonSuccessCodeError(:final errorCode) when retryable ?? false => VoiceTranscriptionOutcome.retryableServerFailure(
      statusCode: errorCode,
    ),
    // COMPATIBILITY 2026-08-28 (v1.8.2): Older auth servers can omit retryability.
    // Retire when every supported auth server returns a boolean for every transcribe failure.
    NonSuccessCodeError(:final errorCode) => VoiceTranscriptionOutcome.terminalServerFailure(statusCode: errorCode),
    DartHttpClientError() => const VoiceTranscriptionOutcome.networkFailure(),
    GenericError() => const VoiceTranscriptionOutcome.unexpectedFailure(),
    JsonParsingError() || EmptyResponseError() => const VoiceTranscriptionOutcome.emptyTranscript(),
  };
}

final class _ApiVoiceRealtimeConnection({required final RealtimeVoiceSession _session})
    implements VoiceRealtimeConnection {
  @override
  Stream<VoiceRealtimeConnectionEvent> get events async* {
    try {
      await for (final event in _session.events) {
        yield _mapEvent(event);
      }
    } on Object catch (error, stackTrace) {
      yield VoiceRealtimeFailed(
        failure: _mapConnectionFailure(error: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  void sendAudio(Uint8List frame) {
    try {
      _session.sendAudio(frame);
    } on Object catch (error, stackTrace) {
      throw VoiceRealtimeConnectionException(
        failure: _mapConnectionFailure(error: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<VoiceRealtimeTerminalOutcome> finish() async {
    try {
      final event = await _session.finish();
      return switch (event) {
        RealtimeVoiceCompleteEvent(:final reason) => VoiceRealtimeTerminalCompleted(
          reason: _mapCompleteReason(reason),
        ),
        RealtimeVoiceErrorEvent(:final code) => VoiceRealtimeTerminalFailed(
          failure: _mapServerFailure(code),
        ),
        RealtimeVoiceReadyEvent() || RealtimeVoiceTranscriptEvent() => const VoiceRealtimeTerminalFailed(
          failure: VoiceRealtimeContractFailure(innerError: null, innerStackTrace: null),
        ),
      };
    } on Object catch (error, stackTrace) {
      return VoiceRealtimeTerminalFailed(
        failure: _mapConnectionFailure(error: error, stackTrace: stackTrace),
      );
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _session.cancel();
    } on RealtimeVoiceTransportClosedException {
      return;
    }
  }

  @override
  Future<void> close() => _session.close();

  static VoiceRealtimeConnectionEvent _mapEvent(RealtimeVoiceEvent event) => switch (event) {
    RealtimeVoiceReadyEvent() => const VoiceRealtimeReady(),
    RealtimeVoiceTranscriptEvent(:final confirmedDelta, :final provisional) => VoiceRealtimeTranscript(
      confirmedDelta: confirmedDelta,
      provisional: provisional,
    ),
    RealtimeVoiceCompleteEvent(:final reason) => VoiceRealtimeCompleted(reason: _mapCompleteReason(reason)),
    RealtimeVoiceErrorEvent(:final code) => VoiceRealtimeFailed(failure: _mapServerFailure(code)),
  };

  static VoiceRealtimeCompletionReason _mapCompleteReason(RealtimeCompleteReason reason) => switch (reason) {
    RealtimeCompleteReason.finished => VoiceRealtimeCompletionReason.finished,
    RealtimeCompleteReason.sessionLimit => VoiceRealtimeCompletionReason.sessionLimit,
    RealtimeCompleteReason.quotaLimit => VoiceRealtimeCompletionReason.quotaLimit,
  };

  static VoiceRealtimeFailure _mapConnectionFailure({
    required Object error,
    required StackTrace stackTrace,
  }) => switch (error) {
    RealtimeVoiceProtocolException() || FormatException() => VoiceRealtimeContractFailure(
      innerError: error,
      innerStackTrace: stackTrace,
    ),
    RealtimeVoiceTransportClosedException() => VoiceRealtimeInterruptedFailure(
      innerError: error,
      innerStackTrace: stackTrace,
    ),
    _ => VoiceRealtimeInterruptedFailure(innerError: error, innerStackTrace: stackTrace),
  };

  static VoiceRealtimeFailure _mapServerFailure(RealtimeVoiceErrorCode code) => switch (code) {
    RealtimeVoiceErrorCode.quotaExhausted => const VoiceRealtimeQuotaFailure(
      innerError: null,
      innerStackTrace: null,
    ),
    RealtimeVoiceErrorCode.audioTimeout ||
    RealtimeVoiceErrorCode.providerTimeout ||
    RealtimeVoiceErrorCode.internalError ||
    RealtimeVoiceErrorCode.startTimeout ||
    RealtimeVoiceErrorCode.providerCapacity ||
    RealtimeVoiceErrorCode.providerUnavailable ||
    RealtimeVoiceErrorCode.slowClient ||
    RealtimeVoiceErrorCode.serviceRestarting => const VoiceRealtimeTemporaryUnavailableFailure(
      innerError: null,
      innerStackTrace: null,
    ),
    RealtimeVoiceErrorCode.invalidMessage ||
    RealtimeVoiceErrorCode.unsupportedProtocol ||
    RealtimeVoiceErrorCode.invalidAudio ||
    RealtimeVoiceErrorCode.providerRejected => const VoiceRealtimeContractFailure(
      innerError: null,
      innerStackTrace: null,
    ),
  };
}

sealed class const VoiceRealtimeOpenOutcome() {
  const factory opened({required VoiceRealtimeConnection connection}) = VoiceRealtimeOpened;

  const factory asyncFallback({required Exception cause}) = VoiceRealtimeOpenAsyncFallback;

  const factory notAuthenticated({required Exception cause}) = VoiceRealtimeOpenNotAuthenticated;

  const factory contractFailure({required String reason, required Exception cause}) = VoiceRealtimeOpenContractFailure;

  const factory unexpectedFailure({required Object error}) = VoiceRealtimeOpenUnexpectedFailure;
}

final class const VoiceRealtimeOpened({required final VoiceRealtimeConnection connection})
    extends VoiceRealtimeOpenOutcome;

final class const VoiceRealtimeOpenAsyncFallback({required final Exception cause}) extends VoiceRealtimeOpenOutcome;

final class const VoiceRealtimeOpenNotAuthenticated({required final Exception cause}) extends VoiceRealtimeOpenOutcome;

final class const VoiceRealtimeOpenContractFailure({required final String reason, required final Exception cause})
    extends VoiceRealtimeOpenOutcome;

final class const VoiceRealtimeOpenUnexpectedFailure({required final Object error}) extends VoiceRealtimeOpenOutcome;

sealed class const VoiceTranscriptionOutcome() {
  const factory success({required String transcript}) = VoiceTranscriptionSuccess;

  const factory notAuthenticated() = VoiceTranscriptionNotAuthenticated;

  const factory retryableServerFailure({required int statusCode}) = VoiceTranscriptionRetryableServerFailure;

  const factory terminalServerFailure({required int statusCode}) = VoiceTranscriptionTerminalServerFailure;

  const factory networkFailure() = VoiceTranscriptionNetworkFailure;

  const factory unexpectedFailure() = VoiceTranscriptionUnexpectedFailure;

  const factory emptyTranscript() = VoiceTranscriptionEmptyTranscript;
}

final class const VoiceTranscriptionSuccess({required final String transcript}) extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNotAuthenticated() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionRetryableServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionTerminalServerFailure({required final int statusCode})
    extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionNetworkFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionUnexpectedFailure() extends VoiceTranscriptionOutcome;

final class const VoiceTranscriptionEmptyTranscript() extends VoiceTranscriptionOutcome;
