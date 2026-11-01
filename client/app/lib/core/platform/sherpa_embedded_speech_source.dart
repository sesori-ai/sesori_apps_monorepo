import "dart:async";
import "dart:io";
import "dart:isolate";

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:injectable/injectable.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sherpa_onnx/sherpa_onnx.dart" as sherpa;

/// Versions the copy on disk, so a different model never reuses this one's files.
const String _modelName = "sherpa-onnx-streaming-zipformer-en-2023-06-26-mobile";
const String _assetDirectory = "assets/speech_model";
const String _encoderFile = "encoder-epoch-99-avg-1-chunk-16-left-128.int8.onnx";
const String _decoderFile = "decoder-epoch-99-avg-1-chunk-16-left-128.onnx";
const String _joinerFile = "joiner-epoch-99-avg-1-chunk-16-left-128.int8.onnx";
const String _tokensFile = "tokens.txt";
const List<String> _modelFiles = [_encoderFile, _decoderFile, _joinerFile, _tokensFile];

const int _recognizerThreads = 2;

/// Lets the model reach the end of the last word, which it otherwise holds back.
const Duration _finishSilence = Duration(milliseconds: 800);

/// The speech model shipped in the app's assets. The native runtime needs real
/// files, so [prepare] copies the model out once. Each dictation loads it in a
/// worker isolate that exits when the dictation ends, which frees its memory.
@LazySingleton(as: EmbeddedSpeechSource)
class SherpaEmbeddedSpeechSource() implements EmbeddedSpeechSource {
  _SherpaSpeechSession? _active;
  Future<bool>? _preparing;

  /// A second hold can ask while the first copy is still running, and shares it.
  @override
  Future<bool> prepare() => _preparing ??= _prepare().whenComplete(() => _preparing = null);

  Future<bool> _prepare() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest.listAssets().toSet();
    if (!_modelFiles.every((file) => bundled.contains("$_assetDirectory/$file"))) {
      logw("This build has no embedded speech model; dictation stays on the server");
      return false;
    }

    final directory = await _modelDirectory();
    await directory.create(recursive: true);
    for (final file in _modelFiles) {
      final target = File(p.join(directory.path, file));
      if (target.existsSync()) continue;
      final asset = await rootBundle.load("$_assetDirectory/$file");
      final temporary = File("${target.path}.tmp");
      await temporary.writeAsBytes(
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes),
        flush: true,
      );
      // Renamed only when complete, so a copy cut short is never read as the model.
      await temporary.rename(target.path);
    }
    return true;
  }

  Future<Directory> _modelDirectory() async {
    // Caches stay out of iCloud backups. If the system clears them, the next prepare copies the model again.
    final cache = await getApplicationCacheDirectory();
    return Directory(p.join(cache.path, "speech_model", _modelName));
  }

  /// Returns once the model has loaded, because audio can then flow at once.
  @override
  Future<OnDeviceSpeechSession> open({required VoiceRealtimeSampleRate sampleRate}) async {
    if (_active != null) throw StateError("An embedded speech session is already open");

    final session = _SherpaSpeechSession(
      onClosed: (closed) {
        if (identical(_active, closed)) _active = null;
      },
    );
    _active = session;
    try {
      final directory = await _modelDirectory();
      await session.start(modelDirectory: directory.path, sampleRate: sampleRate.hertz);
    } catch (_) {
      session.close();
      rethrow;
    }
    return session;
  }
}

final class _SherpaSpeechSession({required final void Function(_SherpaSpeechSession) _onClosed})
    implements OnDeviceSpeechSession {
  final StreamController<OnDeviceSpeechEvent> _events = StreamController<OnDeviceSpeechEvent>();
  final ReceivePort _replies = ReceivePort();
  final Completer<void> _started = Completer<void>();
  SendPort? _commands;
  bool _closed = false;

  Future<void> start({required String modelDirectory, required int sampleRate}) async {
    _replies.listen((reply) {
      if (reply is _WorkerReply) _onReply(reply: reply);
    });
    await Isolate.spawn(
      _runSherpaWorker,
      _WorkerStart(replies: _replies.sendPort, modelDirectory: modelDirectory, sampleRate: sampleRate),
      debugName: "embedded-speech",
    );
    await _started.future;
  }

  @override
  Stream<OnDeviceSpeechEvent> get events => _events.stream;

  @override
  void sendAudio({required Uint8List frame}) => _send(command: _WorkerAudio(frame: frame));

  @override
  void finish() => _send(command: const _WorkerFinish());

  @override
  Future<void> cancel() async {
    if (_closed) return;
    _send(command: const _WorkerCancel());
    close();
  }

  void close() {
    _closed = true;
    _onClosed(this);
    _replies.close();
    // Closing waits for a listener, and a session that failed to start never has one.
    unawaited(_events.close());
  }

  void _send({required _WorkerCommand command}) {
    if (!_closed) _commands?.send(command);
  }

  void _onReply({required _WorkerReply reply}) {
    if (_closed) return;
    switch (reply) {
      case _WorkerReady(:final commands):
        _commands = commands;
        _started.complete();
      case _WorkerWords(:final confirmedDelta, :final provisional):
        _events.add(OnDeviceSpeechWords(confirmedDelta: confirmedDelta, provisional: provisional));
      case _WorkerCompleted():
        _events.add(const OnDeviceSpeechCompleted());
        close();
      case _WorkerFailed(:final description):
        if (_started.isCompleted) {
          _events.add(OnDeviceSpeechFailed(cause: description));
          close();
        } else {
          _started.completeError(StateError(description));
        }
    }
  }
}

final class const _WorkerStart({
  required final SendPort replies,
  required final String modelDirectory,
  required final int sampleRate,
});

sealed class const _WorkerCommand();

final class const _WorkerAudio({required final Uint8List frame}) extends _WorkerCommand;

final class const _WorkerFinish() extends _WorkerCommand;

final class const _WorkerCancel() extends _WorkerCommand;

sealed class const _WorkerReply();

final class const _WorkerReady({required final SendPort commands}) extends _WorkerReply;

final class const _WorkerWords({required final String confirmedDelta, required final String provisional})
    extends _WorkerReply;

final class const _WorkerCompleted() extends _WorkerReply;

final class const _WorkerFailed({required final String description}) extends _WorkerReply;

/// Runs in the worker isolate, which ends once its port closes.
void _runSherpaWorker(_WorkerStart start) {
  final _SherpaRecognition recognition;
  try {
    recognition = _loadRecognition(start: start);
  } catch (error, stackTrace) {
    start.replies.send(_WorkerFailed(description: "${error.toString()}\n${stackTrace.toString()}"));
    return;
  }

  final commands = ReceivePort();
  start.replies.send(_WorkerReady(commands: commands.sendPort));
  commands.listen((command) {
    if (command is! _WorkerCommand) return;
    try {
      switch (command) {
        case _WorkerAudio(:final frame):
          recognition.accept(frame: frame);
          return;
        case _WorkerFinish():
          recognition.finish();
          start.replies.send(const _WorkerCompleted());
        case _WorkerCancel():
          break;
      }
    } catch (error, stackTrace) {
      start.replies.send(_WorkerFailed(description: "${error.toString()}\n${stackTrace.toString()}"));
    }
    recognition.free();
    commands.close();
  });
}

_SherpaRecognition _loadRecognition({required _WorkerStart start}) {
  // Bindings belong to each isolate, so the worker loads its own.
  sherpa.initBindings();
  String model({required String file}) => p.join(start.modelDirectory, file);
  final recognizer = sherpa.OnlineRecognizer(
    sherpa.OnlineRecognizerConfig(
      model: sherpa.OnlineModelConfig(
        transducer: sherpa.OnlineTransducerModelConfig(
          encoder: model(file: _encoderFile),
          decoder: model(file: _decoderFile),
          joiner: model(file: _joinerFile),
        ),
        tokens: model(file: _tokensFile),
        numThreads: _recognizerThreads,
        debug: false,
      ),
    ),
  );
  return _SherpaRecognition(
    replies: start.replies,
    sampleRate: start.sampleRate,
    recognizer: recognizer,
    stream: recognizer.createStream(),
  );
}

/// One dictation's recognizer, which lives only inside the worker isolate.
final class _SherpaRecognition({
  required final SendPort _replies,
  required final int _sampleRate,
  required final sherpa.OnlineRecognizer _recognizer,
  required final sherpa.OnlineStream _stream,
}) {
  String _provisional = "";

  void accept({required Uint8List frame}) {
    _stream.acceptWaveform(
      samples: pcm16ToSamples(frame: frame),
      sampleRate: _sampleRate,
    );
    _decode();
    final text = _recognizer.getResult(_stream).text;
    if (_recognizer.isEndpoint(_stream)) {
      _recognizer.reset(_stream);
      _confirm(text: text);
    } else {
      _showProvisional(text: text);
    }
  }

  void finish() {
    final silence = Float32List(_sampleRate * _finishSilence.inMilliseconds ~/ Duration.millisecondsPerSecond);
    _stream
      ..acceptWaveform(samples: silence, sampleRate: _sampleRate)
      ..inputFinished();
    _decode();
    _confirm(text: _recognizer.getResult(_stream).text);
  }

  void free() {
    _stream.free();
    _recognizer.free();
  }

  void _decode() {
    while (_recognizer.isReady(_stream)) {
      _recognizer.decode(_stream);
    }
  }

  void _confirm({required String text}) {
    final segment = formatEmbeddedSpeechSegment(text: text);
    if (segment.isEmpty && _provisional.isEmpty) return;
    _provisional = "";
    _replies.send(_WorkerWords(confirmedDelta: segment, provisional: ""));
  }

  void _showProvisional({required String text}) {
    final segment = formatEmbeddedSpeechSegment(text: text);
    if (segment == _provisional) return;
    _provisional = segment;
    _replies.send(_WorkerWords(confirmedDelta: "", provisional: segment));
  }
}

/// The model answers in capitals with no punctuation, so a segment reads as one
/// lowercase sentence with its first letter capitalized.
@visibleForTesting
String formatEmbeddedSpeechSegment({required String text}) {
  final lowered = text.trim().toLowerCase();
  if (lowered.isEmpty) return lowered;
  return "${lowered[0].toUpperCase()}${lowered.substring(1)}";
}

/// PCM16 little-endian mono as the samples between -1 and 1 the model takes.
@visibleForTesting
Float32List pcm16ToSamples({required Uint8List frame}) {
  final bytes = ByteData.sublistView(frame);
  final samples = Float32List(frame.lengthInBytes ~/ 2);
  for (var index = 0; index < samples.length; index++) {
    samples[index] = bytes.getInt16(index * 2, Endian.little) / 32768;
  }
  return samples;
}
