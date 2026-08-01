import AVFoundation
import Flutter

final class RecorderPrewarmService {
  static let channelName = "com.sesori.app/recorder-prewarm"

  private let queue = DispatchQueue(
    label: "com.sesori.app.recorder-prewarm",
    qos: .userInitiated
  )
  private let channel: FlutterMethodChannel

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "prewarm" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let sampleRate = arguments["sampleRate"] as? Int,
          let bitRate = arguments["bitRate"] as? Int,
          let numChannels = arguments["numChannels"] as? Int,
          sampleRate > 0,
          bitRate > 0,
          (1...2).contains(numChannels) else {
      result(
        FlutterError(
          code: "recorder_prewarm_invalid_arguments",
          message: "Invalid recorder prewarm configuration",
          details: nil
        )
      )
      return
    }

    queue.async {
      do {
        try self.prewarm(
          sampleRate: sampleRate,
          bitRate: bitRate,
          numChannels: numChannels
        )
        DispatchQueue.main.async { result(nil) }
      } catch {
        let flutterError = FlutterError(
          code: "recorder_prewarm_failed",
          message: error.localizedDescription,
          details: nil
        )
        DispatchQueue.main.async { result(flutterError) }
      }
    }
  }

  private func prewarm(
    sampleRate: Int,
    bitRate: Int,
    numChannels: Int
  ) throws {
    let fileManager = FileManager.default
    let outputUrl = fileManager.temporaryDirectory
      .appendingPathComponent("sesori-recorder-prewarm.m4a")
    if fileManager.fileExists(atPath: outputUrl.path) {
      try fileManager.removeItem(at: outputUrl)
    }

    let session = AVAudioSession.sharedInstance()
    let previousSession = AudioSessionSnapshot(session: session)
    var recorder: AVAudioRecorder?
    defer {
      recorder = nil
      restoreAudioSession(session: session, snapshot: previousSession)
      if fileManager.fileExists(atPath: outputUrl.path) {
        do {
          try fileManager.removeItem(at: outputUrl)
        } catch {
          NSLog("Failed to remove recorder prewarm output: %@", error.localizedDescription)
        }
      }
    }

    try session.setPreferredSampleRate(min(Double(sampleRate), 48_000))
    if #available(iOS 14.5, *) {
      try session.setPrefersNoInterruptionsFromSystemAlerts(true)
    }
    try session.setCategory(
      .playAndRecord,
      options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
    )
    if #available(iOS 13.0, *) {
      try session.setAllowHapticsAndSystemSoundsDuringRecording(false)
    }

    var settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVEncoderBitRateKey: bitRate,
      AVSampleRateKey: sampleRate,
      AVNumberOfChannelsKey: numChannels,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    let inputChannelCount = session.inputNumberOfChannels > 0
      ? session.inputNumberOfChannels
      : numChannels
    guard let inputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: session.sampleRate > 0 ? session.sampleRate : Double(sampleRate),
      channels: AVAudioChannelCount(max(1, inputChannelCount)),
      interleaved: false
    ), let outputFormat = AVAudioFormat(settings: settings),
       let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
      throw prewarmError("Audio format initialization failed")
    }

    if let sampleRates = converter.availableEncodeSampleRates,
       !sampleRates.isEmpty,
       !(sampleRates.count == 1 && sampleRates[0].doubleValue == 0) {
      settings[AVSampleRateKey] = nearest(
        to: Double(sampleRate),
        values: sampleRates
      ).doubleValue
    }
    if let bitRates = converter.availableEncodeBitRates,
       !bitRates.isEmpty,
       !(bitRates.count == 1 && bitRates[0].doubleValue == 0) {
      settings[AVEncoderBitRateKey] = nearest(
        to: Double(bitRate),
        values: bitRates
      ).intValue
    }

    recorder = try AVAudioRecorder(url: outputUrl, settings: settings)
    guard recorder?.prepareToRecord() == true else {
      throw prewarmError("Audio recorder preparation failed")
    }
    recorder = nil
  }

  private func restoreAudioSession(
    session: AVAudioSession,
    snapshot: AudioSessionSnapshot
  ) {
    do {
      try session.setAllowHapticsAndSystemSoundsDuringRecording(
        snapshot.allowsHapticsAndSystemSoundsDuringRecording
      )
    } catch {
      NSLog("Failed to restore audio-session haptics preference: %@", error.localizedDescription)
    }
    do {
      try session.setPrefersNoInterruptionsFromSystemAlerts(
        snapshot.prefersNoInterruptionsFromSystemAlerts
      )
    } catch {
      NSLog("Failed to restore audio-session interruption preference: %@", error.localizedDescription)
    }
    do {
      try session.setCategory(
        snapshot.category,
        mode: snapshot.mode,
        options: snapshot.categoryOptions
      )
    } catch {
      NSLog("Failed to restore audio-session category: %@", error.localizedDescription)
    }
    do {
      try session.setPreferredSampleRate(snapshot.preferredSampleRate)
    } catch {
      NSLog("Failed to restore audio-session sample rate: %@", error.localizedDescription)
    }
  }

  private func nearest(to target: Double, values: [NSNumber]) -> NSNumber {
    values.min {
      abs($0.doubleValue - target) < abs($1.doubleValue - target)
    } ?? NSNumber(value: target)
  }

  private func prewarmError(_ message: String) -> NSError {
    NSError(
      domain: "RecorderPrewarmService",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }
}

private struct AudioSessionSnapshot {
  let category: AVAudioSession.Category
  let categoryOptions: AVAudioSession.CategoryOptions
  let mode: AVAudioSession.Mode
  let preferredSampleRate: Double
  let allowsHapticsAndSystemSoundsDuringRecording: Bool
  let prefersNoInterruptionsFromSystemAlerts: Bool

  init(session: AVAudioSession) {
    category = session.category
    categoryOptions = session.categoryOptions
    mode = session.mode
    preferredSampleRate = session.preferredSampleRate
    allowsHapticsAndSystemSoundsDuringRecording =
      session.allowHapticsAndSystemSoundsDuringRecording
    prefersNoInterruptionsFromSystemAlerts =
      session.prefersNoInterruptionsFromSystemAlerts
  }
}
