import "package:mocktail/mocktail.dart";

import "../foundation/models/voice/voice_dictation_outcome.dart";
import "../foundation/models/voice/voice_live.dart";
import "../services/voice_transcription_service.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

/// What an after-recording dictation returns, for stubbing `stopAndTranscribe`.
VoiceDictationResult afterRecordingResult({required String transcript}) => VoiceDictationResult(
  transcript: transcript,
  outcome: VoiceDictationOutcome.finished,
  mode: VoiceDictationMode.afterRecording,
);

/// [afterRecordingResult] for a test that decides when the transcript arrives.
Future<VoiceDictationResult> afterRecordingResultOf({required Future<String> transcript}) async =>
    afterRecordingResult(transcript: await transcript);

MockVoiceTranscriptionSession stubVoiceTranscriptionService({
  required MockVoiceTranscriptionService service,
  Stream<void> maxDurationStream = const Stream<void>.empty(),
  Stream<double> amplitudeStream = const Stream<double>.empty(),
  Stream<VoiceLiveEvent> liveEventStream = const Stream<VoiceLiveEvent>.empty(),
}) {
  final session = MockVoiceTranscriptionSession();
  when(
    () => service.createSession(
      projectId: any(named: "projectId"),
      allowLive: any(named: "allowLive"),
    ),
  ).thenReturn(session);
  when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationStream);
  when(() => service.amplitudeStream(session: session)).thenAnswer((_) => amplitudeStream);
  when(() => service.liveEventStream(session: session)).thenAnswer((_) => liveEventStream);
  when(() => service.isLive(session: session)).thenReturn(false);
  when(() => service.prewarm(session: session)).thenAnswer((_) async {});
  when(() => service.start(session: session)).thenAnswer((_) async {});
  when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) async => afterRecordingResult(transcript: ""));
  when(() => service.retry(session: session)).thenAnswer((_) async => "");
  when(() => service.cancel(session: session)).thenAnswer((_) async {});
  when(() => service.discard(session: session)).thenAnswer((_) async {});
  when(() => service.invalidate(session: session)).thenReturn(null);
  when(() => service.close(session: session)).thenAnswer((_) async {});
  return session;
}
