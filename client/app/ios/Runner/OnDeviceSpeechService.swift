import AVFoundation
import Flutter
import Speech

/// The on-device speech channel. Older iOS versions answer that it can't run, so
/// their dictation stays on the server. Flutter calls the handler on the main thread.
@MainActor
final class OnDeviceSpeechService {
  static let channelName = "com.sesori.app/on-device-speech"

  private let channel: FlutterMethodChannel
  private var session: AnyObject?
  private var sessionId: Int?

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      MainActor.assumeIsolated { self?.handle(call, result: result) }
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 26, *) else {
      call.method == "prepare" ? result(false) : result(FlutterMethodNotImplemented)
      return
    }

    let arguments = call.arguments as? [String: Any]
    switch call.method {
    case "prepare":
      Task { result(await OnDeviceSpeechEngine.prepare()) }
    case "start":
      guard let sessionId = arguments?["sessionId"] as? Int,
        let sampleRate = arguments?["sampleRate"] as? Int
      else {
        result(FlutterError(code: "bad_arguments", message: nil, details: nil))
        return
      }
      start(sessionId: sessionId, sampleRate: sampleRate, result: result)
    case "sendAudio":
      guard let bytes = arguments?["bytes"] as? FlutterStandardTypedData else {
        result(FlutterError(code: "bad_arguments", message: nil, details: nil))
        return
      }
      currentEngine(arguments: arguments)?.append(bytes: bytes.data)
      result(nil)
    case "finish":
      currentEngine(arguments: arguments)?.finish()
      result(nil)
    case "cancel":
      if #available(iOS 26, *), let engine = currentEngine(arguments: arguments) {
        engine.cancel()
        session = nil
        sessionId = nil
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 26, *)
  private func start(sessionId: Int, sampleRate: Int, result: @escaping FlutterResult) {
    (session as? OnDeviceSpeechEngine)?.cancel()
    let engine = OnDeviceSpeechEngine(sampleRate: Double(sampleRate)) { [weak self] event in
      var payload = event
      payload["sessionId"] = sessionId
      self?.channel.invokeMethod("event", arguments: payload)
    }
    session = engine
    self.sessionId = sessionId
    Task {
      do {
        try await engine.start()
        result(nil)
      } catch {
        engine.cancel()
        if self.sessionId == sessionId {
          session = nil
          self.sessionId = nil
        }
        result(FlutterError(code: "start_failed", message: "\(error)", details: nil))
      }
    }
  }

  @available(iOS 26, *)
  private func currentEngine(arguments: [String: Any]?) -> OnDeviceSpeechEngine? {
    guard let id = arguments?["sessionId"] as? Int, id == sessionId else { return nil }
    return session as? OnDeviceSpeechEngine
  }
}

/// One dictation on `SpeechAnalyzer`. Everything here runs on the main actor, like
/// the channel that drives it. `onEvent` gets `words`, then one `completed` or
/// `failed`, and nothing after `cancel`.
@available(iOS 26, *)
@MainActor
final class OnDeviceSpeechEngine {
  private enum EngineError: Error {
    case localeUnavailable
    case formatUnavailable
  }

  private let inputFormat: AVAudioFormat?
  private let onEvent: ([String: Any]) -> Void
  private var analyzer: SpeechAnalyzer?
  private var converter: AVAudioConverter?
  private var outputFormat: AVAudioFormat?
  private var input: AsyncStream<AnalyzerInput>.Continuation?
  private var resultsTask: Task<Void, Never>?
  private var ended = false

  init(sampleRate: Double, onEvent: @escaping ([String: Any]) -> Void) {
    inputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: sampleRate,
      channels: 1,
      interleaved: true
    )
    self.onEvent = onEvent
  }

  /// True when this device has the model for its language. A model it can get is
  /// fetched in the background for a later dictation.
  static func prepare() async -> Bool {
    guard SpeechTranscriber.isAvailable,
      let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current)
    else { return false }

    let installed = await SpeechTranscriber.installedLocales
    if installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) { return true }

    Task.detached {
      let transcriber = makeTranscriber(locale: locale)
      do {
        let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber])
        try await request?.downloadAndInstall()
      } catch {
        NSLog("On-device speech model download failed: \(error)")
      }
    }
    return false
  }

  func start() async throws {
    guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale.current) else {
      throw EngineError.localeUnavailable
    }
    let transcriber = Self.makeTranscriber(locale: locale)
    guard let inputFormat,
      let outputFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
    else { throw EngineError.formatUnavailable }

    self.outputFormat = outputFormat
    if inputFormat != outputFormat {
      converter = AVAudioConverter(from: inputFormat, to: outputFormat)
    }

    let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
    input = continuation
    let analyzer = SpeechAnalyzer(modules: [transcriber])
    self.analyzer = analyzer

    resultsTask = Task { [weak self] in
      do {
        for try await result in transcriber.results {
          let text = String(result.text.characters)
          self?.emit([
            "type": "words",
            "confirmedDelta": result.isFinal ? text : "",
            "provisional": result.isFinal ? "" : text,
          ])
        }
        self?.endWith(["type": "completed"])
      } catch {
        self?.fail(reason: "\(error)")
      }
    }
    try await analyzer.start(inputSequence: stream)
  }

  func append(bytes: Data) {
    guard !ended, let inputFormat, let outputFormat, let input else { return }
    let frameCount = AVAudioFrameCount(bytes.count / MemoryLayout<Int16>.size)
    guard frameCount > 0,
      let source = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: frameCount),
      let samples = source.int16ChannelData
    else { return }

    source.frameLength = frameCount
    bytes.withUnsafeBytes { raw in
      if let base = raw.baseAddress {
        samples[0].update(from: base.assumingMemoryBound(to: Int16.self), count: Int(frameCount))
      }
    }

    guard let converter else {
      input.yield(AnalyzerInput(buffer: source))
      return
    }

    let ratio = outputFormat.sampleRate / inputFormat.sampleRate
    guard let converted = AVAudioPCMBuffer(
      pcmFormat: outputFormat,
      frameCapacity: AVAudioFrameCount(Double(frameCount) * ratio) + 32
    ) else { return }

    var consumed = false
    var conversionError: NSError?
    let status = converter.convert(to: converted, error: &conversionError) { _, inputStatus in
      if consumed {
        // Not the end of the stream: the converter keeps its state for the next frame.
        inputStatus.pointee = .noDataNow
        return nil
      }
      consumed = true
      inputStatus.pointee = .haveData
      return source
    }
    if status == .error {
      fail(reason: "\(String(describing: conversionError))")
      return
    }
    input.yield(AnalyzerInput(buffer: converted))
  }

  func finish() {
    guard !ended, let analyzer else { return }
    input?.finish()
    Task { [weak self] in
      do {
        try await analyzer.finalizeAndFinishThroughEndOfInput()
      } catch {
        self?.fail(reason: "\(error)")
      }
    }
  }

  func cancel() {
    ended = true
    input?.finish()
    resultsTask?.cancel()
    if let analyzer {
      Task { await analyzer.cancelAndFinishNow() }
    }
  }

  private func emit(_ event: [String: Any]) {
    if !ended { onEvent(event) }
  }

  private func endWith(_ event: [String: Any]) {
    emit(event)
    ended = true
  }

  /// A failed session gets no `cancel` from Dart, so it stops the analyzer itself.
  private func fail(reason: String) {
    endWith(["type": "failed", "reason": reason])
    cancel()
  }

  private nonisolated static func makeTranscriber(locale: Locale) -> SpeechTranscriber {
    SpeechTranscriber(
      locale: locale,
      transcriptionOptions: [],
      reportingOptions: [.volatileResults],
      attributeOptions: []
    )
  }
}
