import "package:flutter_bloc/flutter_bloc.dart";
import "package:go_router/go_router.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../../core/di/injection.dart";

/// Mobile composition for the dictation engine picker.
class const VoiceEngineSettingsScreen({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => VoiceEngineCubit(voiceModeRepository: getIt<VoiceModeRepository>()),
      child: VoiceEngineSettingsView(onBack: () => context.pop()),
    );
  }
}
