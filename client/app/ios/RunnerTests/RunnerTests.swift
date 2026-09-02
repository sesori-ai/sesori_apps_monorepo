import AVFoundation
import CoreVideo
import Flutter
@testable import Runner
import UIKit
import XCTest

class RunnerTests: XCTestCase {
  func testMovementTimelineUsesLatestPositionAtRequestedTime() {
    let movement = CreatorRecordingMovementDocument(
      schemaVersion: 1,
      shape: "circle",
      mirrored: true,
      coordinateSpace: .init(unit: "points", origin: "topLeft", width: 390, height: 844),
      samples: [
        .init(timeMs: 0, x: 10, y: 20, width: 120, height: 120),
        .init(timeMs: 500, x: 200, y: 300, width: 120, height: 120),
      ]
    )

    XCTAssertEqual(movement.sample(at: 0.1)?.x, 10)
    XCTAssertEqual(movement.sample(at: 0.5)?.x, 200)
    XCTAssertEqual(movement.sample(at: 10)?.y, 300)
  }

  func testRecordingLibraryListsOnlyCompleteManifestBackedArtifacts() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CreatorRecordingLibraryTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: root) }

    let library = CreatorRecordingLibrary(rootURL: root)
    let paths = try library.createRecording()
    for url in [
      paths.composedURL,
      paths.screenURL,
      paths.cameraURL,
      paths.microphoneURL,
      paths.movementURL,
    ] {
      try Data([0]).write(to: url)
    }
    _ = try library.saveManifest(paths: paths, durationMs: 2_500)

    let recordings = try library.listRecordings()
    XCTAssertEqual(recordings.count, 1)
    XCTAssertEqual(recordings.first?.paths.id, paths.id)
    XCTAssertEqual(recordings.first?.durationMs, 2_500)

    try library.deleteRecording(id: paths.id.uuidString)
    XCTAssertTrue(try library.listRecordings().isEmpty)
  }

  func testCompositorCreatesFinalMovieFromIndependentVideoLayers() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("CreatorRecordingCompositorTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let screenURL = root.appendingPathComponent("screen.mov")
    let cameraURL = root.appendingPathComponent("camera.mov")
    let microphoneURL = root.appendingPathComponent("microphone.caf")
    let outputURL = root.appendingPathComponent("final.mov")
    try writeTestVideo(to: screenURL, byte: 24)
    try writeTestVideo(to: cameraURL, byte: 180)
    try writeTestAudio(to: microphoneURL)

    let movement = CreatorRecordingMovementDocument(
      schemaVersion: 1,
      shape: "circle",
      mirrored: true,
      coordinateSpace: .init(unit: "points", origin: "topLeft", width: 64, height: 128),
      samples: [.init(timeMs: 0, x: 8, y: 12, width: 32, height: 32)]
    )
    let composed = expectation(description: "final creator movie composed")
    var composeError: Error?
    CreatorRecordingCompositor.compose(
      screenURL: screenURL,
      cameraURL: cameraURL,
      microphoneURL: microphoneURL,
      movement: movement,
      outputURL: outputURL
    ) { result in
      if case .failure(let error) = result { composeError = error }
      composed.fulfill()
    }
    wait(for: [composed], timeout: 15)

    XCTAssertNil(composeError)
    XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    let output = AVURLAsset(url: outputURL)
    XCTAssertEqual(output.tracks(withMediaType: .video).count, 1)
    XCTAssertEqual(output.tracks(withMediaType: .audio).count, 1)
    XCTAssertGreaterThan(CMTimeGetSeconds(output.duration), 0)
  }

  private func writeTestAudio(to url: URL) throws {
    guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1),
          let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4_410) else {
      throw CocoaError(.coderInvalidValue)
    }
    buffer.frameLength = buffer.frameCapacity
    if let channel = buffer.floatChannelData?.pointee {
      channel.initialize(repeating: 0, count: Int(buffer.frameLength))
    }
    let file = try AVAudioFile(forWriting: url, settings: format.settings)
    try file.write(from: buffer)
  }

  private func writeTestVideo(to url: URL, byte: UInt8) throws {
    let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
    let input = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 64,
        AVVideoHeightKey: 128,
      ]
    )
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
      assetWriterInput: input,
      sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferWidthKey as String: 64,
        kCVPixelBufferHeightKey as String: 128,
      ]
    )
    XCTAssertTrue(writer.canAdd(input))
    writer.add(input)
    XCTAssertTrue(writer.startWriting())
    writer.startSession(atSourceTime: .zero)

    for frame in 0..<8 {
      var pixelBuffer: CVPixelBuffer?
      let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        64,
        128,
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
      )
      XCTAssertEqual(status, kCVReturnSuccess)
      guard let pixelBuffer else { throw CocoaError(.coderInvalidValue) }
      CVPixelBufferLockBaseAddress(pixelBuffer, [])
      if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
        memset(base, Int32(byte), CVPixelBufferGetDataSize(pixelBuffer))
      }
      CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
      while !input.isReadyForMoreMediaData { usleep(1_000) }
      XCTAssertTrue(
        adaptor.append(
          pixelBuffer,
          withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30)
        )
      )
    }

    input.markAsFinished()
    let finished = expectation(description: "test video written")
    writer.finishWriting { finished.fulfill() }
    wait(for: [finished], timeout: 5)
    XCTAssertEqual(writer.status, .completed)
  }
}
