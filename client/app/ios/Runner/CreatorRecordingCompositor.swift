import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreMedia
import Foundation

/// Renders the final single-file export from the clean source layers.
enum CreatorRecordingCompositor {
  enum CompositorError: Error {
    case missingVideoTrack(URL)
    case invalidDuration
    case cannotAddTrack
    case exportSessionUnavailable
    case exportFailed(Error?)
    case renderFailed
  }

  static func compose(
    screenURL: URL,
    cameraURL: URL,
    microphoneURL: URL,
    movement: CreatorRecordingMovementDocument,
    outputURL: URL,
    completion: @escaping (Result<Void, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try composeLoaded(
          screenURL: screenURL,
          cameraURL: cameraURL,
          microphoneURL: microphoneURL,
          movement: movement,
          outputURL: outputURL,
          completion: completion
        )
      } catch {
        completion(.failure(error))
      }
    }
  }

  private static func composeLoaded(
    screenURL: URL,
    cameraURL: URL,
    microphoneURL: URL,
    movement: CreatorRecordingMovementDocument,
    outputURL: URL,
    completion: @escaping (Result<Void, Error>) -> Void
  ) throws {
    let screenAsset = AVURLAsset(url: screenURL)
    let cameraAsset = AVURLAsset(url: cameraURL)
    let microphoneAsset = AVURLAsset(url: microphoneURL)
    guard let screenSource = screenAsset.tracks(withMediaType: .video).first else {
      throw CompositorError.missingVideoTrack(screenURL)
    }
    guard let cameraSource = cameraAsset.tracks(withMediaType: .video).first else {
      throw CompositorError.missingVideoTrack(cameraURL)
    }

    let duration = CMTimeMinimum(screenAsset.duration, cameraAsset.duration)
    guard duration.isNumeric, CMTimeCompare(duration, .zero) > 0 else {
      throw CompositorError.invalidDuration
    }
    let timeRange = CMTimeRange(start: .zero, duration: duration)
    let composition = AVMutableComposition()
    guard let screenTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: 1
    ), let cameraTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: 2
    ) else {
      throw CompositorError.cannotAddTrack
    }
    try screenTrack.insertTimeRange(timeRange, of: screenSource, at: .zero)
    try cameraTrack.insertTimeRange(timeRange, of: cameraSource, at: .zero)
    screenTrack.preferredTransform = screenSource.preferredTransform
    cameraTrack.preferredTransform = cameraSource.preferredTransform

    if let microphoneSource = microphoneAsset.tracks(withMediaType: .audio).first,
       let microphoneTrack = composition.addMutableTrack(
         withMediaType: .audio,
         preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
      let audioDuration = CMTimeMinimum(duration, microphoneAsset.duration)
      try microphoneTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: audioDuration),
        of: microphoneSource,
        at: .zero
      )
    }

    let orientedScreenSize = screenSource.naturalSize.applying(screenSource.preferredTransform)
    let renderSize = CGSize(
      width: abs(orientedScreenSize.width),
      height: abs(orientedScreenSize.height)
    )
    guard renderSize.width > 0, renderSize.height > 0 else {
      throw CompositorError.renderFailed
    }

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = renderSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
    videoComposition.instructions = [
      CreatorRecordingCompositionInstruction(
        timeRange: timeRange,
        screenTrackID: screenTrack.trackID,
        cameraTrackID: cameraTrack.trackID,
        screenTransform: screenSource.preferredTransform,
        cameraTransform: cameraSource.preferredTransform,
        renderSize: renderSize,
        movement: movement
      ),
    ]
    videoComposition.customVideoCompositorClass = CreatorRecordingVideoCompositor.self

    try? FileManager.default.removeItem(at: outputURL)
    guard let exporter = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      throw CompositorError.exportSessionUnavailable
    }
    exporter.outputURL = outputURL
    exporter.outputFileType = .mov
    exporter.videoComposition = videoComposition
    exporter.shouldOptimizeForNetworkUse = true
    exporter.exportAsynchronously {
      switch exporter.status {
      case .completed:
        completion(.success(()))
      case .failed, .cancelled:
        completion(.failure(CompositorError.exportFailed(exporter.error)))
      case .unknown, .waiting, .exporting:
        completion(.failure(CompositorError.exportFailed(exporter.error)))
      @unknown default:
        completion(.failure(CompositorError.exportFailed(exporter.error)))
      }
    }
  }
}

final class CreatorRecordingCompositionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
  let timeRange: CMTimeRange
  let enablePostProcessing = false
  let containsTweening = true
  let requiredSourceTrackIDs: [NSValue]?
  let passthroughTrackID = kCMPersistentTrackID_Invalid

  let screenTrackID: CMPersistentTrackID
  let cameraTrackID: CMPersistentTrackID
  let screenTransform: CGAffineTransform
  let cameraTransform: CGAffineTransform
  let renderSize: CGSize
  let movement: CreatorRecordingMovementDocument

  init(
    timeRange: CMTimeRange,
    screenTrackID: CMPersistentTrackID,
    cameraTrackID: CMPersistentTrackID,
    screenTransform: CGAffineTransform,
    cameraTransform: CGAffineTransform,
    renderSize: CGSize,
    movement: CreatorRecordingMovementDocument
  ) {
    self.timeRange = timeRange
    self.screenTrackID = screenTrackID
    self.cameraTrackID = cameraTrackID
    self.screenTransform = screenTransform
    self.cameraTransform = cameraTransform
    self.renderSize = renderSize
    self.movement = movement
    self.requiredSourceTrackIDs = [
      NSNumber(value: screenTrackID),
      NSNumber(value: cameraTrackID),
    ]
    super.init()
  }
}

final class CreatorRecordingVideoCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
  var sourcePixelBufferAttributes: [String: any Sendable]? = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  ]
  var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  ]

  private let renderQueue = DispatchQueue(
    label: "com.sesori.app.creator-recording.compositor",
    qos: .userInitiated
  )
  private let context = CIContext(options: [.useSoftwareRenderer: false])
  private var renderContext: AVVideoCompositionRenderContext?

  func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
    renderQueue.sync {
      renderContext = newRenderContext
    }
  }

  func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
    renderQueue.async { [weak self] in
      autoreleasepool {
        self?.render(request)
      }
    }
  }

  func cancelAllPendingVideoCompositionRequests() {}

  private func render(_ request: AVAsynchronousVideoCompositionRequest) {
    guard let instruction = request.videoCompositionInstruction
      as? CreatorRecordingCompositionInstruction,
      let outputBuffer = renderContext?.newPixelBuffer() else {
      request.finish(with: CreatorRecordingCompositor.CompositorError.renderFailed)
      return
    }

    let outputBounds = CGRect(origin: .zero, size: instruction.renderSize)
    let screenImage = request.sourceFrame(byTrackID: instruction.screenTrackID)
      .map(CIImage.init(cvPixelBuffer:))
      .map { orient($0, transform: instruction.screenTransform) }
      ?? CIImage(color: .black).cropped(to: outputBounds)
    var composed = screenImage.cropped(to: outputBounds)

    if let cameraBuffer = request.sourceFrame(byTrackID: instruction.cameraTrackID),
       let sample = instruction.movement.sample(
         at: CMTimeGetSeconds(request.compositionTime)
       ),
       let bubble = bubbleImage(
         source: CIImage(cvPixelBuffer: cameraBuffer),
         transform: instruction.cameraTransform,
         sample: sample,
         coordinateSpace: instruction.movement.coordinateSpace,
         renderSize: instruction.renderSize,
         mirrored: instruction.movement.mirrored
       ) {
      composed = bubble.composited(over: composed)
    }

    context.render(composed.cropped(to: outputBounds), to: outputBuffer)
    request.finish(withComposedVideoFrame: outputBuffer)
  }

  private func orient(_ image: CIImage, transform: CGAffineTransform) -> CIImage {
    let transformed = image.transformed(by: transform)
    return transformed.transformed(
      by: CGAffineTransform(
        translationX: -transformed.extent.origin.x,
        y: -transformed.extent.origin.y
      )
    )
  }

  private func bubbleImage(
    source: CIImage,
    transform: CGAffineTransform,
    sample: CreatorRecordingMovementDocument.Sample,
    coordinateSpace: CreatorRecordingMovementDocument.CoordinateSpace,
    renderSize: CGSize,
    mirrored: Bool
  ) -> CIImage? {
    guard coordinateSpace.width > 0, coordinateSpace.height > 0,
          sample.width > 0, sample.height > 0 else { return nil }

    let scaleX = renderSize.width / coordinateSpace.width
    let scaleY = renderSize.height / coordinateSpace.height
    let target = CGRect(
      x: sample.x * scaleX,
      y: renderSize.height - (sample.y + sample.height) * scaleY,
      width: sample.width * scaleX,
      height: sample.height * scaleY
    )

    var camera = orient(source, transform: transform)
    if mirrored {
      camera = camera
        .transformed(by: CGAffineTransform(scaleX: -1, y: 1))
        .transformed(by: CGAffineTransform(translationX: camera.extent.width, y: 0))
    }
    let fillScale = max(target.width / camera.extent.width, target.height / camera.extent.height)
    camera = camera.transformed(by: CGAffineTransform(scaleX: fillScale, y: fillScale))
    camera = camera.transformed(
      by: CGAffineTransform(
        translationX: target.midX - camera.extent.midX,
        y: target.midY - camera.extent.midY
      )
    )
    camera = camera.cropped(to: target)

    let maskGenerator = CIFilter.roundedRectangleGenerator()
    maskGenerator.extent = target
    maskGenerator.radius = Float(min(target.width, target.height) / 2)
    maskGenerator.color = .white
    guard let mask = maskGenerator.outputImage else { return nil }

    let blend = CIFilter.blendWithAlphaMask()
    blend.inputImage = camera
    blend.backgroundImage = CIImage.empty()
    blend.maskImage = mask
    return blend.outputImage?.cropped(to: target)
  }
}
