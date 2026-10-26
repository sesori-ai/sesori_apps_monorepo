import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop_core/sesori_desktop_core.dart";
import "package:test/test.dart";

void main() {
  late _RecordingLogSink sink;

  setUp(() {
    sink = _RecordingLogSink();
    setLogSink(sink: sink);
    addTearDown(() => setLogSink(sink: const StdoutLogSink()));
  });

  test("skips Velopack for install kinds without it", () {
    final _BundleSource source = _BundleSource(os: DesktopBundleOs.linux, isAppImage: false);

    runDesktopUpdateStartupHooks(bundleSource: source);

    expect(source.libraryPathReads, 0);
    expect(sink.records, isEmpty);
  });

  test("logs a Velopack library that fails to open and continues", () {
    final _BundleSource source = _BundleSource(os: DesktopBundleOs.windows, isAppImage: false);

    runDesktopUpdateStartupHooks(bundleSource: source);

    expect(source.libraryPathReads, 1);
    expect(
      sink.records.map((record) => record.message),
      contains("Failed to run the Velopack startup hooks; updates will fail too"),
    );
  });
}

class _BundleSource({required final DesktopBundleOs _os, @override required final bool isAppImage})
    implements InstalledDesktopBundleSource {
  int libraryPathReads = 0;

  @override
  DesktopBundleIdentity get compiledIdentity => DesktopBundleIdentity(
    version: "1.8.4",
    buildNumber: 24,
    sourceSha: "source",
    os: _os,
    architecture: DesktopBundleArchitecture.x64,
  );

  @override
  DesktopReleaseChannel get channel => DesktopReleaseChannel.internal;

  @override
  String get velopackLibraryPath {
    libraryPathReads++;
    return "/nonexistent/velopack_libc.so";
  }

  @override
  DesktopBundleIdentity readInstalledIdentity() => throw UnimplementedError();
}

class _RecordingLogSink() implements LogSink {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void write({required LogRecord record}) => records.add(record);

  @override
  Future<void> flush() => Future<void>.value();
}
