import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_mobile/core/widgets/feedback_voice_input_scope.dart";

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets("the feedback sheet keeps recording first, whatever the voice mode says (D31)", (tester) async {
    final service = MockVoiceTranscriptionService();
    stubVoiceTranscriptionService(service: service);
    GetIt.instance.registerSingleton<VoiceTranscriptionService>(service);

    await tester.pumpWidget(
      FeedbackVoiceInputScope(
        child: Builder(
          builder: (context) {
            context.read<VoiceInputCubit>();
            return const SizedBox();
          },
        ),
      ),
    );

    verify(() => service.createSession(projectId: null, allowLive: false)).called(1);
  });
}
