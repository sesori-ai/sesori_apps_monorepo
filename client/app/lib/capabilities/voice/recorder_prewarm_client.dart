import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:universal_platform/universal_platform.dart";

@lazySingleton
class RecorderPrewarmClient() {
  static const _channel = MethodChannel("com.sesori.app/recorder-prewarm");

  Future<void> prewarm({
    required int sampleRate,
    required int bitRate,
    required int numChannels,
  }) async {
    if (!UniversalPlatform.isAndroid && !UniversalPlatform.isIOS) return;

    await _channel.invokeMethod<void>("prewarm", {
      "sampleRate": sampleRate,
      "bitRate": bitRate,
      "numChannels": numChannels,
    });
  }
}
