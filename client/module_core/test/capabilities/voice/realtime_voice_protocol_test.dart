import "dart:convert";
import "dart:io";

import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/src/capabilities/voice/realtime_voice_protocol.dart";
import "package:sesori_shared/sesori_shared.dart" show ProjectGlossaryKey;
import "package:test/test.dart";

void main() {
  final fixture =
      jsonDecode(File("test/fixtures/voice_realtime_protocol_v1.json").readAsStringSync()) as Map<String, Object?>;
  final valid = fixture["valid"]! as Map<String, Object?>;
  final invalid = fixture["invalid"]! as Map<String, Object?>;

  RealtimeVoiceServerEvent parseValid(String name) => parseRealtimeVoiceEvent(frame: jsonEncode(valid[name]));

  group("client frames", () {
    test("start matches the fixture for every sample rate and for a project key", () {
      final startCases = <String, ({VoiceRealtimeSampleRate sampleRate, ProjectGlossaryKey? projectKey})>{
        "startNullProject16000": (sampleRate: VoiceRealtimeSampleRate.hz16000, projectKey: null),
        "start24000": (sampleRate: VoiceRealtimeSampleRate.hz24000, projectKey: null),
        "start44100WithProject": (
          sampleRate: VoiceRealtimeSampleRate.hz44100,
          projectKey: ProjectGlossaryKey.parse(value: "prj_v1_AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"),
        ),
        "start48000": (sampleRate: VoiceRealtimeSampleRate.hz48000, projectKey: null),
      };
      expect(startCases.values.map((value) => value.sampleRate), unorderedEquals(VoiceRealtimeSampleRate.values));

      for (final MapEntry(key: name, :value) in startCases.entries) {
        final encoded = encodeRealtimeVoiceStart(sampleRate: value.sampleRate, projectKey: value.projectKey);
        expect(jsonDecode(encoded), valid[name], reason: name);
      }
    });

    test("finish and cancel match the fixture", () {
      expect(jsonDecode(realtimeVoiceFinishFrame), valid["finish"]);
      expect(jsonDecode(realtimeVoiceCancelFrame), valid["cancel"]);
    });

    test("the fixture's invalid project key cannot be built", () {
      final badStart = invalid["badProjectKey"]! as Map<String, Object?>;
      expect(ProjectGlossaryKey.tryParse(value: badStart["projectKey"]! as String), isNull);
    });
  });

  group("server events", () {
    test("ready", () {
      expect(
        parseValid("ready"),
        isA<RealtimeVoiceReadyEvent>()
            .having((event) => event.maxSessionSeconds, "maxSessionSeconds", 900)
            .having((event) => event.dailySecondsRemaining, "dailySecondsRemaining", 420),
      );
    });

    test("transcript with confirmed words and with tentative words", () {
      expect(
        parseValid("transcriptConfirmed"),
        isA<RealtimeVoiceTranscriptEvent>()
            .having((event) => event.confirmedDelta, "confirmedDelta", "confirmed text")
            .having((event) => event.provisional, "provisional", ""),
      );
      expect(
        parseValid("transcriptProvisional"),
        isA<RealtimeVoiceTranscriptEvent>()
            .having((event) => event.confirmedDelta, "confirmedDelta", "")
            .having((event) => event.provisional, "provisional", "draft"),
      );
    });

    test("every complete reason", () {
      final cases = {
        "completeFinished": (reason: RealtimeVoiceCompleteReason.finished, remaining: 419),
        "completeSessionLimit": (reason: RealtimeVoiceCompleteReason.sessionLimit, remaining: 0),
        "completeQuotaLimit": (reason: RealtimeVoiceCompleteReason.quotaLimit, remaining: 0),
      };
      expect(cases.values.map((value) => value.reason), unorderedEquals(RealtimeVoiceCompleteReason.values));

      for (final MapEntry(key: name, :value) in cases.entries) {
        expect(
          parseValid(name),
          isA<RealtimeVoiceCompleteEvent>()
              .having((event) => event.reason, "reason", value.reason)
              .having((event) => event.dailySecondsRemaining, "dailySecondsRemaining", value.remaining),
          reason: name,
        );
      }
    });

    test("every error code in the fixture parses, and the enum has no others", () {
      final errorCases = valid.entries.where((entry) => entry.key.startsWith("error")).toList();
      final parsed = <RealtimeVoiceErrorCode>[];

      for (final MapEntry(key: name, :value) in errorCases) {
        final frame = value! as Map<String, Object?>;
        final event = parseRealtimeVoiceEvent(frame: jsonEncode(frame)) as RealtimeVoiceErrorEvent;
        parsed.add(event.code);
        expect(event.code.wireName, frame["code"], reason: name);
        expect(event.code.retryable, frame["retryable"], reason: name);
      }

      expect(parsed, unorderedEquals(RealtimeVoiceErrorCode.values));
    });

    test("each error code carries the server's close code", () {
      const policy = {"invalid_message", "unsupported_protocol", "quota_exhausted", "invalid_audio"};
      const internal = {"provider_rejected", "audio_timeout", "provider_timeout", "internal_error"};
      for (final code in RealtimeVoiceErrorCode.values) {
        final expected = policy.contains(code.wireName) ? 1008 : (internal.contains(code.wireName) ? 1011 : 1013);
        expect(code.closeCode, expected, reason: code.wireName);
      }
    });

    test("every server event the fixture calls invalid is rejected", () {
      const clientTypes = {"start", "finish", "cancel", "pause"};
      final serverCases = invalid.entries.where(
        (entry) => !clientTypes.contains((entry.value! as Map<String, Object?>)["type"]),
      );
      expect(serverCases.length, greaterThanOrEqualTo(12));

      for (final MapEntry(key: name, :value) in serverCases) {
        final frame = jsonEncode(value).replaceAll("__TEXT_32769__", "x" * 32769);
        expect(
          () => parseRealtimeVoiceEvent(frame: frame),
          throwsA(isA<RealtimeVoiceProtocolException>()),
          reason: name,
        );
      }
    });

    test("an unknown type and an unknown code are rejected and named", () {
      expect(
        () => parseRealtimeVoiceEvent(frame: '{"type":"paused"}'),
        throwsA(isA<RealtimeVoiceProtocolException>().having((error) => error.message, "message", contains("paused"))),
      );
      expect(
        () => parseRealtimeVoiceEvent(frame: '{"type":"error","code":"rate_limited","retryable":true}'),
        throwsA(
          isA<RealtimeVoiceProtocolException>().having((error) => error.message, "message", contains("rate_limited")),
        ),
      );
    });

    test("a rejected frame never carries its transcript text", () {
      const secret = "words the user said";
      final frames = [
        '{"type":"transcript","confirmedDelta":"$secret"',
        '{"type":"transcript","confirmedDelta":"$secret","provisional":7}',
        '{"type":"transcript","confirmedDelta":"$secret","provisional":"","extra":1}',
        '["$secret"]',
      ];

      for (final frame in frames) {
        expect(
          () => parseRealtimeVoiceEvent(frame: frame),
          throwsA(
            isA<RealtimeVoiceProtocolException>().having(
              (error) => error.toString(),
              "toString",
              isNot(contains(secret)),
            ),
          ),
          reason: frame,
        );
      }
    });
  });
}
