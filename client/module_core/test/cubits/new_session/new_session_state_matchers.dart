import "package:sesori_dart_core/src/cubits/new_session/new_session_state.dart";
import "package:test/test.dart";

/// Matches a [NewSessionComposing] state whose phase is [P].
TypeMatcher<NewSessionComposing> composingWith<P extends NewSessionPhase>() =>
    isA<NewSessionComposing>().having((state) => state.phase, "phase", isA<P>());
