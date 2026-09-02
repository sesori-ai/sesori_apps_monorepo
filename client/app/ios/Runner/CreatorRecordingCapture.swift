import AVFoundation
import CoreMedia
import Foundation
import ReplayKit
import UIKit

final class CreatorRecordingCapture {
  private enum State {
    case idle
    case preview
    case starting(CreatorRecordingPaths)
    case recording(CreatorRecordingPaths)
    case stopping(CreatorRecordingPaths)
  }

  var onOverlayStop: (() -> Void)? {
    didSet { overlay.onStop = onOverlayStop }
  }
  var onInterrupted: ((CreatorRecordingNativeError) -> Void)?

  private let library: CreatorRecordingLibrary
  private let camera = CreatorRecordingCameraSession()
  private lazy var overlay = CreatorRecordingOverlay(cameraSession: camera.session)
  private let replayKit = RPScreenRecorder.shared()
  private let writerQueue = DispatchQueue(
    label: "com.sesori.app.creator-recording.writer",
    qos: .userInitiated
  )
  private let movementLogger = CreatorRecordingMovementLogger()

  private var state: State = .idle
  private var screenWriter: CreatorRecordingVideoWriter?
  private var cameraWriter: CreatorRecordingVideoWriter?
  private var microphoneWriter: CreatorRecordingAudioWriter?
  private var anchorPTS: CMTime?
  private var acceptingSamples = false
  private var interruptionInProgress = false

  init(library: CreatorRecordingLibrary) {
    self.library = library
  }

  func preparePreview(completion: @escaping (Result<Void, CreatorRecordingNativeError>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    switch state {
    case .preview:
      completion(.success(()))
      return
    case .idle:
      break
    case .starting, .recording, .stopping:
      completion(.failure(.recordingAlreadyInProgress))
      return
    }

    requestCameraPermission { [weak self] granted in
      guard let self else { return }
      guard granted else {
        completion(.failure(.cameraPermissionDenied))
        return
      }
      self.camera.prepare { result in
        DispatchQueue.main.async {
          switch result {
          case .success:
            self.overlay.show()
            self.state = .preview
            completion(.success(()))
          case .failure(let error):
            NSLog("Failed to prepare creator recording camera: %@", String(describing: error))
            if let nativeError = error as? CreatorRecordingNativeError {
              completion(.failure(nativeError))
            } else {
              completion(.failure(.captureFailed(error)))
            }
          }
        }
      }
    }
  }

  func dismissPreview(completion: @escaping (Result<Void, CreatorRecordingNativeError>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    switch state {
    case .idle:
      completion(.success(()))
    case .preview:
      overlay.hide()
      camera.stop()
      state = .idle
      completion(.success(()))
    case .starting, .recording, .stopping:
      completion(.failure(.recordingAlreadyInProgress))
    }
  }

  func start(completion: @escaping (Result<Void, CreatorRecordingNativeError>) -> Void) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard case .preview = state else {
      completion(.failure(.recordingAlreadyInProgress))
      return
    }
    guard currentInterfaceOrientation == .portrait else {
      completion(.failure(.portraitRequired))
      return
    }
    guard replayKit.isAvailable, !replayKit.isRecording else {
      completion(.failure(.screenCaptureUnavailable(nil)))
      return
    }

    requestMicrophonePermission { [weak self] granted in
      guard let self else { return }
      guard granted else {
        completion(.failure(.microphonePermissionDenied))
        return
      }
      self.beginCapture(completion: completion)
    }
  }

  private func beginCapture(
    completion: @escaping (Result<Void, CreatorRecordingNativeError>) -> Void
  ) {
    let paths: CreatorRecordingPaths
    do {
      paths = try library.createRecording()
    } catch {
      NSLog("Failed to create creator recording storage: %@", String(describing: error))
      completion(.failure(.storageFailed(error)))
      return
    }

    state = .starting(paths)
    interruptionInProgress = false
    movementLogger.start(
      frameProvider: { [weak self] in self?.overlay.cameraFrameInScreen },
      coordinateBounds: overlay.coordinateBounds
    )

    writerQueue.sync {
      screenWriter = CreatorRecordingVideoWriter(outputURL: paths.screenURL)
      cameraWriter = CreatorRecordingVideoWriter(outputURL: paths.cameraURL)
      microphoneWriter = CreatorRecordingAudioWriter(outputURL: paths.microphoneURL)
      anchorPTS = nil
      acceptingSamples = true
    }

    camera.sampleHandler = { [weak self] sample in
      self?.writerQueue.async {
        self?.appendCameraSample(sample)
      }
    }

    replayKit.isMicrophoneEnabled = true
    replayKit.isCameraEnabled = false
    replayKit.startCapture(
      handler: { [weak self] sample, type, error in
        guard let self else { return }
        if let error {
          DispatchQueue.main.async {
            self.interruptCapture(error: .captureFailed(error))
          }
          return
        }
        self.writerQueue.async {
          self.appendReplayKitSample(sample, type: type)
        }
      },
      completionHandler: { [weak self] error in
        DispatchQueue.main.async {
          guard let self else { return }
          if let error {
            self.abortStartingCapture(paths: paths, error: .screenCaptureUnavailable(error))
            completion(.failure(.screenCaptureUnavailable(error)))
            return
          }
          guard case .starting(let activePaths) = self.state,
                activePaths.id == paths.id else {
            completion(.failure(.captureFailed(nil)))
            return
          }
          self.state = .recording(paths)
          self.overlay.setRecording(true)
          completion(.success(()))
        }
      }
    )
  }

  func stop(
    completion: @escaping (Result<CreatorRecordingArtifactPayload, CreatorRecordingNativeError>) -> Void
  ) {
    dispatchPrecondition(condition: .onQueue(.main))
    guard case .recording(let paths) = state else {
      completion(.failure(.recordingNotInProgress))
      return
    }

    state = .stopping(paths)
    overlay.setSaving()
    replayKit.stopCapture { [weak self] error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error {
          self.failStoppingCapture(paths: paths, error: .captureFailed(error), completion: completion)
          return
        }
        self.finishCapture(paths: paths, completion: completion)
      }
    }
  }

  private func finishCapture(
    paths: CreatorRecordingPaths,
    completion: @escaping (Result<CreatorRecordingArtifactPayload, CreatorRecordingNativeError>) -> Void
  ) {
    camera.sampleHandler = nil
    let anchorSeconds = writerQueue.sync { anchorPTS.map(CMTimeGetSeconds) }
    let movement = movementLogger.stop(anchorSeconds: anchorSeconds)

    writerQueue.async { [weak self] in
      guard let self else { return }
      self.acceptingSamples = false
      self.finishWriters { result in
        switch result {
        case .failure(let error):
          DispatchQueue.main.async {
            self.failStoppingCapture(
              paths: paths,
              error: .captureFailed(error),
              completion: completion
            )
          }
        case .success(let duration):
          self.persistMovement(movement, to: paths.movementURL) { movementResult in
            switch movementResult {
            case .failure(let error):
              DispatchQueue.main.async {
                self.failStoppingCapture(
                  paths: paths,
                  error: .storageFailed(error),
                  completion: completion
                )
              }
            case .success:
              CreatorRecordingCompositor.compose(
                screenURL: paths.screenURL,
                cameraURL: paths.cameraURL,
                microphoneURL: paths.microphoneURL,
                movement: movement,
                outputURL: paths.composedURL
              ) { composeResult in
                DispatchQueue.main.async {
                  switch composeResult {
                  case .failure(let error):
                    self.failStoppingCapture(
                      paths: paths,
                      error: .exportFailed(error),
                      completion: completion
                    )
                  case .success:
                    do {
                      let durationMs = max(0, Int((duration * 1_000).rounded()))
                      let artifact = try self.library.saveManifest(
                        paths: paths,
                        durationMs: durationMs
                      )
                      self.completeCapture()
                      completion(.success(artifact))
                    } catch {
                      self.failStoppingCapture(
                        paths: paths,
                        error: .storageFailed(error),
                        completion: completion
                      )
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  private func finishWriters(completion: @escaping (Result<TimeInterval, Error>) -> Void) {
    guard let screenWriter, let cameraWriter, let microphoneWriter else {
      completion(.failure(CreatorRecordingWriterError.notStarted))
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var firstError: Error?
    let writers: [CreatorRecordingFinishing] = [
      screenWriter,
      cameraWriter,
      microphoneWriter,
    ]
    for writer in writers {
      group.enter()
      writer.finish { result in
        if case .failure(let error) = result {
          lock.lock()
          if firstError == nil { firstError = error }
          lock.unlock()
        }
        group.leave()
      }
    }
    group.notify(queue: writerQueue) {
      if let firstError {
        completion(.failure(firstError))
      } else {
        completion(.success(screenWriter.duration))
      }
    }
  }

  private func persistMovement(
    _ movement: CreatorRecordingMovementDocument,
    to url: URL,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(movement).write(to: url, options: .atomic)
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private func completeCapture() {
    overlay.showCompletion(success: true)
    camera.stop()
    state = .idle
    clearWriters()
  }

  private func failStoppingCapture(
    paths: CreatorRecordingPaths,
    error: CreatorRecordingNativeError,
    completion: @escaping (Result<CreatorRecordingArtifactPayload, CreatorRecordingNativeError>) -> Void
  ) {
    NSLog("Creator recording stop failed: %@", String(describing: error))
    writerQueue.async { [weak self] in
      self?.cancelWriters()
    }
    library.discard(paths: paths)
    overlay.showCompletion(success: false)
    camera.stop()
    state = .idle
    clearWriters()
    completion(.failure(error))
  }

  private func abortStartingCapture(
    paths: CreatorRecordingPaths,
    error: CreatorRecordingNativeError
  ) {
    camera.sampleHandler = nil
    movementLogger.cancel()
    writerQueue.async { [weak self] in self?.cancelWriters() }
    library.discard(paths: paths)
    overlay.setRecording(false)
    state = .preview
    NSLog("Creator recording start failed: %@", String(describing: error))
  }

  private func interruptCapture(error: CreatorRecordingNativeError) {
    guard !interruptionInProgress else { return }
    let paths: CreatorRecordingPaths
    switch state {
    case .starting(let activePaths), .recording(let activePaths):
      paths = activePaths
    case .idle, .preview, .stopping:
      return
    }
    interruptionInProgress = true
    camera.sampleHandler = nil
    movementLogger.cancel()

    let finishAbort = { [weak self] in
      guard let self else { return }
      self.writerQueue.async { self.cancelWriters() }
      self.library.discard(paths: paths)
      self.overlay.showCompletion(success: false)
      self.camera.stop()
      self.state = .idle
      self.clearWriters()
      NSLog("Creator recording interrupted: %@", String(describing: error))
      self.onInterrupted?(error)
    }
    if replayKit.isRecording {
      replayKit.stopCapture { _ in DispatchQueue.main.async(execute: finishAbort) }
    } else {
      finishAbort()
    }
  }

  private func appendReplayKitSample(_ sample: CMSampleBuffer, type: RPSampleBufferType) {
    guard acceptingSamples, CMSampleBufferDataIsReady(sample) else { return }
    switch type {
    case .video:
      let pts = CMSampleBufferGetPresentationTimeStamp(sample)
      if anchorPTS == nil { anchorPTS = pts }
      guard let anchorPTS else { return }
      screenWriter?.append(sample: sample, sessionStart: anchorPTS)
    case .audioMic:
      guard let anchorPTS else { return }
      microphoneWriter?.append(sample: sample, sessionStart: anchorPTS)
    case .audioApp:
      break
    @unknown default:
      break
    }
  }

  private func appendCameraSample(_ sample: CMSampleBuffer) {
    guard acceptingSamples, let anchorPTS else { return }
    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
    guard CMTimeCompare(pts, anchorPTS) >= 0 else { return }
    cameraWriter?.append(sample: sample, sessionStart: anchorPTS)
  }

  private func cancelWriters() {
    acceptingSamples = false
    screenWriter?.cancel()
    cameraWriter?.cancel()
    microphoneWriter?.cancel()
  }

  private func clearWriters() {
    writerQueue.async { [weak self] in
      self?.acceptingSamples = false
      self?.screenWriter = nil
      self?.cameraWriter = nil
      self?.microphoneWriter = nil
      self?.anchorPTS = nil
    }
  }

  private var currentInterfaceOrientation: UIInterfaceOrientation? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first(where: { $0.activationState == .foregroundActive })?
      .interfaceOrientation
  }

  private func requestCameraPermission(completion: @escaping (Bool) -> Void) {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      completion(true)
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        DispatchQueue.main.async { completion(granted) }
      }
    case .denied, .restricted:
      completion(false)
    @unknown default:
      completion(false)
    }
  }

  private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
    let session = AVAudioSession.sharedInstance()
    switch session.recordPermission {
    case .granted:
      completion(true)
    case .undetermined:
      session.requestRecordPermission { granted in
        DispatchQueue.main.async { completion(granted) }
      }
    case .denied:
      completion(false)
    @unknown default:
      completion(false)
    }
  }
}

private protocol CreatorRecordingFinishing {
  func finish(completion: @escaping (Result<Void, Error>) -> Void)
}

private enum CreatorRecordingWriterError: Error {
  case notStarted
  case cannotAddInput
  case startFailed(Error?)
  case appendFailed(Error?)
  case finishFailed(Error?)
}

private final class CreatorRecordingVideoWriter: CreatorRecordingFinishing {
  private let outputURL: URL
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var firstPTS: CMTime?
  private var lastPTS: CMTime?
  private var appendError: Error?

  init(outputURL: URL) {
    self.outputURL = outputURL
  }

  var duration: TimeInterval {
    guard let firstPTS, let lastPTS else { return 0 }
    return max(0, CMTimeGetSeconds(CMTimeSubtract(lastPTS, firstPTS)))
  }

  func append(sample: CMSampleBuffer, sessionStart: CMTime) {
    if writer == nil {
      do {
        try configure(sample: sample, sessionStart: sessionStart)
      } catch {
        appendError = error
        return
      }
    }
    guard appendError == nil,
          let writer,
          writer.status == .writing,
          let input,
          input.isReadyForMoreMediaData else { return }
    if input.append(sample) {
      let pts = CMSampleBufferGetPresentationTimeStamp(sample)
      if firstPTS == nil { firstPTS = pts }
      lastPTS = pts
    } else {
      appendError = CreatorRecordingWriterError.appendFailed(writer.error)
    }
  }

  private func configure(sample: CMSampleBuffer, sessionStart: CMTime) throws {
    guard let format = CMSampleBufferGetFormatDescription(sample) else {
      throw CreatorRecordingWriterError.notStarted
    }
    let dimensions = CMVideoFormatDescriptionGetDimensions(format)
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mov)
    let pixels = max(1, Int(dimensions.width) * Int(dimensions.height))
    let settings: [String: Any] = [
      AVVideoCodecKey: AVVideoCodecType.h264,
      AVVideoWidthKey: Int(dimensions.width),
      AVVideoHeightKey: Int(dimensions.height),
      AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: min(16_000_000, max(4_000_000, pixels * 6)),
        AVVideoExpectedSourceFrameRateKey: 30,
        AVVideoMaxKeyFrameIntervalKey: 60,
      ],
    ]
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: settings,
      sourceFormatHint: format
    )
    input.expectsMediaDataInRealTime = true
    guard writer.canAdd(input) else { throw CreatorRecordingWriterError.cannotAddInput }
    writer.add(input)
    guard writer.startWriting() else {
      throw CreatorRecordingWriterError.startFailed(writer.error)
    }
    writer.startSession(atSourceTime: sessionStart)
    self.writer = writer
    self.input = input
  }

  func finish(completion: @escaping (Result<Void, Error>) -> Void) {
    if let appendError {
      completion(.failure(appendError))
      return
    }
    guard let writer, let input, firstPTS != nil else {
      completion(.failure(CreatorRecordingWriterError.notStarted))
      return
    }
    input.markAsFinished()
    writer.finishWriting {
      if writer.status == .completed {
        completion(.success(()))
      } else {
        completion(.failure(CreatorRecordingWriterError.finishFailed(writer.error)))
      }
    }
  }

  func cancel() {
    writer?.cancelWriting()
  }
}

private final class CreatorRecordingAudioWriter: CreatorRecordingFinishing {
  private let outputURL: URL
  private var writer: AVAssetWriter?
  private var input: AVAssetWriterInput?
  private var receivedSample = false
  private var appendError: Error?

  init(outputURL: URL) {
    self.outputURL = outputURL
  }

  func append(sample: CMSampleBuffer, sessionStart: CMTime) {
    if writer == nil {
      do {
        try configure(sample: sample, sessionStart: sessionStart)
      } catch {
        appendError = error
        return
      }
    }
    guard appendError == nil,
          let writer,
          writer.status == .writing,
          let input,
          input.isReadyForMoreMediaData else { return }
    if input.append(sample) {
      receivedSample = true
    } else {
      appendError = CreatorRecordingWriterError.appendFailed(writer.error)
    }
  }

  private func configure(sample: CMSampleBuffer, sessionStart: CMTime) throws {
    guard let format = CMSampleBufferGetFormatDescription(sample),
          let stream = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
      throw CreatorRecordingWriterError.notStarted
    }
    let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
    let settings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVNumberOfChannelsKey: max(1, min(2, Int(stream.mChannelsPerFrame))),
      AVSampleRateKey: max(8_000, stream.mSampleRate),
      AVEncoderBitRateKey: 128_000,
    ]
    let input = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: settings,
      sourceFormatHint: format
    )
    input.expectsMediaDataInRealTime = true
    guard writer.canAdd(input) else { throw CreatorRecordingWriterError.cannotAddInput }
    writer.add(input)
    guard writer.startWriting() else {
      throw CreatorRecordingWriterError.startFailed(writer.error)
    }
    writer.startSession(atSourceTime: sessionStart)
    self.writer = writer
    self.input = input
  }

  func finish(completion: @escaping (Result<Void, Error>) -> Void) {
    if let appendError {
      completion(.failure(appendError))
      return
    }
    guard let writer, let input, receivedSample else {
      completion(.failure(CreatorRecordingWriterError.notStarted))
      return
    }
    input.markAsFinished()
    writer.finishWriting {
      if writer.status == .completed {
        completion(.success(()))
      } else {
        completion(.failure(CreatorRecordingWriterError.finishFailed(writer.error)))
      }
    }
  }

  func cancel() {
    writer?.cancelWriting()
  }
}

final class CreatorRecordingCameraSession: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
  let session = AVCaptureSession()

  var sampleHandler: ((CMSampleBuffer) -> Void)? {
    get {
      handlerLock.lock()
      defer { handlerLock.unlock() }
      return _sampleHandler
    }
    set {
      handlerLock.lock()
      _sampleHandler = newValue
      handlerLock.unlock()
    }
  }

  private let sessionQueue = DispatchQueue(
    label: "com.sesori.app.creator-recording.camera-session",
    qos: .userInitiated
  )
  private let outputQueue = DispatchQueue(
    label: "com.sesori.app.creator-recording.camera-output",
    qos: .userInitiated
  )
  private let videoOutput = AVCaptureVideoDataOutput()
  private let handlerLock = NSLock()
  private var _sampleHandler: ((CMSampleBuffer) -> Void)?
  private var configured = false

  func prepare(completion: @escaping (Result<Void, Error>) -> Void) {
    sessionQueue.async { [weak self] in
      guard let self else { return }
      do {
        if !self.configured { try self.configure() }
        if !self.session.isRunning { self.session.startRunning() }
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func stop() {
    sampleHandler = nil
    sessionQueue.async { [weak self] in
      guard let self, self.session.isRunning else { return }
      self.session.stopRunning()
    }
  }

  private func configure() throws {
    session.beginConfiguration()
    defer { session.commitConfiguration() }
    session.sessionPreset = .hd1280x720

    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera, .builtInTrueDepthCamera],
      mediaType: .video,
      position: .front
    )
    guard let device = discovery.devices.first else {
      throw CreatorRecordingNativeError.unsupported
    }
    let input = try AVCaptureDeviceInput(device: device)
    guard session.canAddInput(input) else {
      throw CreatorRecordingWriterError.cannotAddInput
    }
    session.addInput(input)

    do {
      try device.lockForConfiguration()
      let frameDuration = CMTime(value: 1, timescale: 30)
      let supportsThirty = device.activeFormat.videoSupportedFrameRateRanges.contains {
        $0.minFrameRate <= 30 && $0.maxFrameRate >= 30
      }
      if supportsThirty {
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
      }
      device.unlockForConfiguration()
    } catch {
      NSLog("Unable to lock creator camera to 30 fps: %@", String(describing: error))
    }

    videoOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    ]
    videoOutput.alwaysDiscardsLateVideoFrames = true
    guard session.canAddOutput(videoOutput) else {
      throw CreatorRecordingWriterError.cannotAddInput
    }
    session.addOutput(videoOutput)
    videoOutput.setSampleBufferDelegate(self, queue: outputQueue)

    if let connection = videoOutput.connection(with: .video) {
      if connection.isVideoOrientationSupported { connection.videoOrientation = .portrait }
      if connection.isVideoMirroringSupported { connection.isVideoMirrored = false }
    }
    configured = true
  }

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    sampleHandler?(sampleBuffer)
  }
}

final class CreatorRecordingOverlay {
  var onStop: (() -> Void)? {
    didSet { bubble?.onStop = onStop }
  }

  private let cameraSession: AVCaptureSession
  private var window: CreatorRecordingPassthroughWindow?
  private var bubble: CreatorRecordingBubbleView?

  init(cameraSession: AVCaptureSession) {
    self.cameraSession = cameraSession
  }

  var cameraFrameInScreen: CGRect? {
    guard let bubble else { return nil }
    return bubble.cameraFrameInScreen
  }

  var coordinateBounds: CGRect {
    window?.rootViewController?.view.bounds ?? UIScreen.main.bounds
  }

  func show() {
    guard window == nil else {
      window?.isHidden = false
      return
    }
    guard let scene = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .first(where: { $0.activationState == .foregroundActive }) else { return }

    let window = CreatorRecordingPassthroughWindow(windowScene: scene)
    window.windowLevel = .alert + 1
    window.backgroundColor = .clear
    let root = UIViewController()
    root.view.backgroundColor = .clear
    window.rootViewController = root

    let bubble = CreatorRecordingBubbleView(cameraSession: cameraSession)
    bubble.onStop = onStop
    root.view.addSubview(bubble)
    bubble.restorePosition(in: root.view.bounds)

    window.isHidden = false
    self.window = window
    self.bubble = bubble
  }

  func hide() {
    bubble?.removeFromSuperview()
    bubble = nil
    window?.isHidden = true
    window = nil
  }

  func setRecording(_ recording: Bool) {
    bubble?.setRecording(recording)
  }

  func setSaving() {
    bubble?.setSaving()
  }

  func showCompletion(success: Bool) {
    bubble?.showCompletion(success: success)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
      self?.hide()
    }
  }
}

final class CreatorRecordingPassthroughWindow: UIWindow {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    let hit = super.hitTest(point, with: event)
    if hit === rootViewController?.view { return nil }
    return hit
  }
}

final class CreatorRecordingBubbleView: UIView {
  private static let cameraSide: CGFloat = 132
  private static let containerSide: CGFloat = 154
  private static let positionXKey = "SesoriCreatorRecording.bubbleX"
  private static let positionYKey = "SesoriCreatorRecording.bubbleY"

  var onStop: (() -> Void)?

  private let cameraView = UIView()
  private let previewLayer: AVCaptureVideoPreviewLayer
  private let stopButton = UIButton(type: .system)
  private let activityIndicator = UIActivityIndicatorView(style: .medium)
  private var panOrigin = CGPoint.zero

  init(cameraSession: AVCaptureSession) {
    previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
    super.init(
      frame: CGRect(
        origin: .zero,
        size: CGSize(width: Self.containerSide, height: Self.containerSide)
      )
    )
    accessibilityLabel = "Front camera recording preview"
    setupCameraView()
    setupStopButton()
    addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:))))
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }

  var cameraFrameInScreen: CGRect {
    guard let superview else { return cameraView.frame }
    return cameraView.convert(cameraView.bounds, to: superview)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    cameraView.frame = CGRect(x: 0, y: 0, width: Self.cameraSide, height: Self.cameraSide)
    previewLayer.frame = cameraView.bounds
    stopButton.frame = CGRect(x: Self.cameraSide - 28, y: Self.cameraSide - 28, width: 44, height: 44)
    activityIndicator.center = CGPoint(x: stopButton.bounds.midX, y: stopButton.bounds.midY)
  }

  func restorePosition(in bounds: CGRect) {
    let defaults = UserDefaults.standard
    let defaultOrigin = CGPoint(x: bounds.maxX - Self.containerSide - 12, y: 72)
    let x = defaults.object(forKey: Self.positionXKey) as? Double ?? defaultOrigin.x
    let y = defaults.object(forKey: Self.positionYKey) as? Double ?? defaultOrigin.y
    frame.origin = clampedOrigin(CGPoint(x: x, y: y), in: bounds)
  }

  func setRecording(_ recording: Bool) {
    stopButton.isHidden = !recording
    stopButton.isEnabled = recording
    cameraView.layer.borderColor = recording ? UIColor.systemRed.cgColor : UIColor.white.cgColor
    cameraView.layer.borderWidth = recording ? 3 : 2
    activityIndicator.stopAnimating()
  }

  func setSaving() {
    stopButton.isHidden = false
    stopButton.isEnabled = false
    stopButton.setImage(nil, for: .normal)
    activityIndicator.startAnimating()
  }

  func showCompletion(success: Bool) {
    activityIndicator.stopAnimating()
    stopButton.isHidden = false
    stopButton.isEnabled = false
    let symbol = success ? "checkmark" : "exclamationmark"
    stopButton.setImage(UIImage(systemName: symbol), for: .normal)
    stopButton.tintColor = .white
    stopButton.backgroundColor = success ? .systemGreen : .systemRed
  }

  private func setupCameraView() {
    cameraView.clipsToBounds = true
    cameraView.layer.cornerRadius = Self.cameraSide / 2
    cameraView.layer.borderWidth = 2
    cameraView.layer.borderColor = UIColor.white.cgColor
    cameraView.backgroundColor = .black
    cameraView.layer.shadowColor = UIColor.black.cgColor
    cameraView.layer.shadowOpacity = 0.28
    cameraView.layer.shadowRadius = 8
    cameraView.layer.shadowOffset = CGSize(width: 0, height: 4)
    addSubview(cameraView)

    previewLayer.videoGravity = .resizeAspectFill
    cameraView.layer.addSublayer(previewLayer)
    if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
      connection.automaticallyAdjustsVideoMirroring = false
      connection.isVideoMirrored = true
    }
  }

  private func setupStopButton() {
    var configuration = UIButton.Configuration.filled()
    configuration.baseBackgroundColor = .systemRed
    configuration.baseForegroundColor = .white
    configuration.cornerStyle = .capsule
    configuration.image = UIImage(systemName: "stop.fill")
    stopButton.configuration = configuration
    stopButton.accessibilityLabel = "Stop and save recording"
    stopButton.isHidden = true
    stopButton.addTarget(self, action: #selector(stopPressed), for: .touchUpInside)
    addSubview(stopButton)
    activityIndicator.color = .white
    activityIndicator.hidesWhenStopped = true
    stopButton.addSubview(activityIndicator)
  }

  @objc private func stopPressed() {
    guard stopButton.isEnabled else { return }
    setSaving()
    onStop?()
  }

  @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
    guard let superview else { return }
    switch recognizer.state {
    case .began:
      panOrigin = frame.origin
    case .changed:
      let translation = recognizer.translation(in: superview)
      frame.origin = clampedOrigin(
        CGPoint(x: panOrigin.x + translation.x, y: panOrigin.y + translation.y),
        in: superview.bounds
      )
    case .ended, .cancelled:
      let defaults = UserDefaults.standard
      defaults.set(Double(frame.origin.x), forKey: Self.positionXKey)
      defaults.set(Double(frame.origin.y), forKey: Self.positionYKey)
    default:
      break
    }
  }

  private func clampedOrigin(_ proposed: CGPoint, in containerBounds: CGRect) -> CGPoint {
    let safeTop = window?.safeAreaInsets.top ?? 20
    let safeBottom = window?.safeAreaInsets.bottom ?? 20
    return CGPoint(
      x: min(
        max(8, proposed.x),
        max(8, containerBounds.maxX - bounds.width - 8)
      ),
      y: min(
        max(safeTop + 8, proposed.y),
        max(safeTop + 8, containerBounds.maxY - bounds.height - safeBottom - 8)
      )
    )
  }
}

struct CreatorRecordingMovementDocument: Codable {
  struct CoordinateSpace: Codable {
    let unit: String
    let origin: String
    let width: Double
    let height: Double
  }

  struct Sample: Codable {
    let timeMs: Int
    let x: Double
    let y: Double
    let width: Double
    let height: Double
  }

  let schemaVersion: Int
  let shape: String
  let mirrored: Bool
  let coordinateSpace: CoordinateSpace
  let samples: [Sample]

  func sample(at seconds: TimeInterval) -> Sample? {
    guard !samples.isEmpty else { return nil }
    let target = Int((seconds * 1_000).rounded())
    var low = 0
    var high = samples.count - 1
    while low <= high {
      let middle = (low + high) / 2
      if samples[middle].timeMs <= target {
        low = middle + 1
      } else {
        high = middle - 1
      }
    }
    return samples[max(0, high)]
  }
}

final class CreatorRecordingMovementLogger {
  private struct RawSample {
    let absoluteTime: TimeInterval
    let frame: CGRect
  }

  private var frameProvider: (() -> CGRect?)?
  private var coordinateBounds = CGRect.zero
  private var rawSamples: [RawSample] = []
  private var displayLink: CADisplayLink?

  func start(frameProvider: @escaping () -> CGRect?, coordinateBounds: CGRect) {
    cancel()
    self.frameProvider = frameProvider
    self.coordinateBounds = coordinateBounds
    capture()
    let displayLink = CADisplayLink(target: self, selector: #selector(tick))
    displayLink.preferredFrameRateRange = CAFrameRateRange(
      minimum: 15,
      maximum: 30,
      preferred: 30
    )
    displayLink.add(to: .main, forMode: .common)
    self.displayLink = displayLink
  }

  func stop(anchorSeconds: TimeInterval?) -> CreatorRecordingMovementDocument {
    capture()
    displayLink?.invalidate()
    displayLink = nil
    frameProvider = nil

    var converted: [CreatorRecordingMovementDocument.Sample] = []
    if let anchorSeconds {
      var atStart: RawSample?
      for raw in rawSamples {
        if raw.absoluteTime <= anchorSeconds {
          atStart = raw
          continue
        }
        if let atStart, converted.isEmpty {
          converted.append(sample(from: atStart, timeMs: 0))
        }
        converted.append(
          sample(
            from: raw,
            timeMs: max(0, Int(((raw.absoluteTime - anchorSeconds) * 1_000).rounded()))
          )
        )
      }
      if converted.isEmpty, let atStart {
        converted.append(sample(from: atStart, timeMs: 0))
      }
    }
    rawSamples.removeAll()

    return CreatorRecordingMovementDocument(
      schemaVersion: 1,
      shape: "circle",
      mirrored: true,
      coordinateSpace: CreatorRecordingMovementDocument.CoordinateSpace(
        unit: "points",
        origin: "topLeft",
        width: coordinateBounds.width,
        height: coordinateBounds.height
      ),
      samples: converted
    )
  }

  func cancel() {
    displayLink?.invalidate()
    displayLink = nil
    frameProvider = nil
    rawSamples.removeAll()
  }

  @objc private func tick() {
    capture()
  }

  private func capture() {
    guard let frame = frameProvider?() else { return }
    if let previous = rawSamples.last,
       abs(previous.frame.origin.x - frame.origin.x) < 0.25,
       abs(previous.frame.origin.y - frame.origin.y) < 0.25,
       abs(previous.frame.width - frame.width) < 0.25,
       abs(previous.frame.height - frame.height) < 0.25 {
      return
    }
    rawSamples.append(RawSample(absoluteTime: CACurrentMediaTime(), frame: frame))
  }

  private func sample(
    from raw: RawSample,
    timeMs: Int
  ) -> CreatorRecordingMovementDocument.Sample {
    CreatorRecordingMovementDocument.Sample(
      timeMs: timeMs,
      x: raw.frame.origin.x,
      y: raw.frame.origin.y,
      width: raw.frame.width,
      height: raw.frame.height
    )
  }
}
