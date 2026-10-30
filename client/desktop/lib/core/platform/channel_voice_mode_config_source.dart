import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

/// Desktop has no remote config, so the release channel fixes the voice mode in
/// the build. Source builds default to stable, so testing live locally needs
/// the release channel define set to internal.
@LazySingleton(as: VoiceModeConfigSource)
class ChannelVoiceModeConfigSource({
  required final InstalledDesktopBundleSource _bundleSource,
}) implements VoiceModeConfigSource {
  @override
  Future<VoiceModeConfigValues> fetchValues() async => (
    liveEnabled: switch (_bundleSource.channel) {
      DesktopReleaseChannel.internal => true,
      DesktopReleaseChannel.stable => false,
    },
    presentation: null,
  );
}
