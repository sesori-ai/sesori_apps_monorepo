import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

class MockVoiceTranscriptionService() extends Mock implements VoiceTranscriptionService;

class MockVoiceTranscriptionSession() extends Mock implements VoiceTranscriptionSession;

MockVoiceTranscriptionSession stubVoiceTranscriptionService({
  required MockVoiceTranscriptionService service,
  Stream<void> maxDurationStream = const Stream<void>.empty(),
  Stream<VoiceRealtimeTerminalCause> realtimeTerminalStream = const Stream<VoiceRealtimeTerminalCause>.empty(),
  Stream<double> amplitudeStream = const Stream<double>.empty(),
}) {
  final session = MockVoiceTranscriptionSession();
  when(
    () => service.createSession(projectId: any(named: "projectId")),
  ).thenReturn(session);
  when(() => service.maxDurationReachedStream(session: session)).thenAnswer((_) => maxDurationStream);
  when(() => service.realtimeTerminalStream(session: session)).thenAnswer((_) => realtimeTerminalStream);
  when(() => service.amplitudeStream(session: session)).thenAnswer((_) => amplitudeStream);
  when(() => service.currentPreview(session: session)).thenReturn(
    const VoiceTranscriptionPreview(confirmedText: "", provisionalText: ""),
  );
  when(() => service.previewStream(session: session)).thenAnswer((_) => const Stream.empty());
  when(() => service.prewarm(session: session)).thenAnswer((_) async {});
  when(() => service.start(session: session)).thenAnswer((_) async {});
  when(() => service.stopAndTranscribe(session: session)).thenAnswer((_) async => "");
  when(() => service.retry(session: session)).thenAnswer((_) async => "");
  when(() => service.cancel(session: session)).thenAnswer((_) async {});
  when(() => service.discard(session: session)).thenAnswer((_) async {});
  when(() => service.invalidate(session: session)).thenReturn(null);
  when(() => service.close(session: session)).thenAnswer((_) async {});
  return session;
}
