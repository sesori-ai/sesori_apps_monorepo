import "package:flutter_test/flutter_test.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_desktop/core/platform/channel_voice_mode_config_source.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";

class _MockInstalledDesktopBundleSource() extends Mock implements InstalledDesktopBundleSource;

void main() {
  late _MockInstalledDesktopBundleSource bundleSource;
  late ChannelVoiceModeConfigSource source;

  setUp(() {
    bundleSource = _MockInstalledDesktopBundleSource();
    source = ChannelVoiceModeConfigSource(bundleSource: bundleSource);
  });

  test("internal builds run live", () async {
    when(() => bundleSource.channel).thenReturn(DesktopReleaseChannel.internal);

    expect(await source.fetchLiveEnabled(), isTrue);
  });

  test("stable builds run after recording", () async {
    when(() => bundleSource.channel).thenReturn(DesktopReleaseChannel.stable);

    expect(await source.fetchLiveEnabled(), isFalse);
  });
}
