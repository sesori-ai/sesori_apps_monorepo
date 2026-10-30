import "package:injectable/injectable.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";

/// Desktop does not offer the CEO call yet; the shared login cubit only needs
/// the dependency to resolve, and the founder call service is never started.
@LazySingleton(as: FounderCallConfigSource)
class NoOpFounderCallConfigSource() implements FounderCallConfigSource {
  @override
  Future<FounderCallConfigValues> fetchValues() async => (
    enabled: false,
    afterComputer: null,
    bookingUrl: null,
    title: null,
    message: null,
    buttonLabel: null,
  );
}
