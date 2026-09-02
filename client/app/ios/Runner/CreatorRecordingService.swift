import AVFoundation
import Flutter
import Foundation
import ReplayKit
import UIKit

final class CreatorRecordingService {
  static let channelName = "com.sesori.app/creator-recording"

  private let channel: FlutterMethodChannel
  private let library: CreatorRecordingLibrary
  private let capture: CreatorRecordingCapture

  init(channel: FlutterMethodChannel) {
    self.channel = channel
    let library = CreatorRecordingLibrary()
    self.library = library
    self.capture = CreatorRecordingCapture(library: library)

    capture.onOverlayStop = { [weak self] in
      self?.stopFromOverlay()
    }
    capture.onInterrupted = { [weak self] error in
      guard let self else { return }
      self.sendFailure(error)
    }
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call: call, result: result)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "preparePreview":
      capture.preparePreview { outcome in
        result(outcome.flutterValue)
      }
    case "dismissPreview":
      capture.dismissPreview { outcome in
        result(outcome.flutterValue)
      }
    case "start":
      capture.start { outcome in
        result(outcome.flutterValue)
      }
    case "stop":
      capture.stop { outcome in
        switch outcome {
        case .success(let artifact):
          result(artifact.channelValue)
        case .failure(let error):
          result(error.flutterError)
        }
      }
    case "listRecordings":
      DispatchQueue.global(qos: .userInitiated).async { [library] in
        do {
          let recordings = try library.listRecordings().map(\.channelValue)
          DispatchQueue.main.async { result(recordings) }
        } catch {
          let failure = CreatorRecordingNativeError.storageFailed(error)
          NSLog("Failed to list creator recordings: %@", String(describing: error))
          DispatchQueue.main.async { result(failure.flutterError) }
        }
      }
    case "deleteRecording":
      guard let arguments = call.arguments as? [String: Any],
            let id = arguments["id"] as? String else {
        result(CreatorRecordingNativeError.storageFailed(nil).flutterError)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async { [library] in
        do {
          try library.deleteRecording(id: id)
          DispatchQueue.main.async { result(nil) }
        } catch {
          let failure = CreatorRecordingNativeError.storageFailed(error)
          NSLog("Failed to delete creator recording %@: %@", id, String(describing: error))
          DispatchQueue.main.async { result(failure.flutterError) }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func stopFromOverlay() {
    channel.invokeMethod("recordingSaving", arguments: nil)
    capture.stop { [weak self] outcome in
      guard let self else { return }
      switch outcome {
      case .success(let artifact):
        self.channel.invokeMethod("recordingCompleted", arguments: artifact.channelValue)
      case .failure(let error):
        self.sendFailure(error)
      }
    }
  }

  private func sendFailure(_ error: CreatorRecordingNativeError) {
    channel.invokeMethod(
      "recordingFailed",
      arguments: ["code": error.code]
    )
  }
}

extension Result where Success == Void, Failure == CreatorRecordingNativeError {
  var flutterValue: Any? {
    switch self {
    case .success:
      return nil
    case .failure(let error):
      return error.flutterError
    }
  }
}

enum CreatorRecordingNativeError: Error {
  case unsupported
  case cameraPermissionDenied
  case microphonePermissionDenied
  case portraitRequired
  case screenCaptureUnavailable(Error?)
  case recordingAlreadyInProgress
  case recordingNotInProgress
  case storageFailed(Error?)
  case captureFailed(Error?)
  case exportFailed(Error?)

  var code: String {
    switch self {
    case .unsupported: return "unsupported"
    case .cameraPermissionDenied: return "camera_permission_denied"
    case .microphonePermissionDenied: return "microphone_permission_denied"
    case .portraitRequired: return "portrait_required"
    case .screenCaptureUnavailable: return "screen_capture_unavailable"
    case .recordingAlreadyInProgress: return "recording_already_in_progress"
    case .recordingNotInProgress: return "recording_not_in_progress"
    case .storageFailed: return "storage_failed"
    case .captureFailed: return "capture_failed"
    case .exportFailed: return "export_failed"
    }
  }

  private var underlyingError: Error? {
    switch self {
    case .screenCaptureUnavailable(let error),
         .storageFailed(let error),
         .captureFailed(let error),
         .exportFailed(let error):
      return error
    case .unsupported,
         .cameraPermissionDenied,
         .microphonePermissionDenied,
         .portraitRequired,
         .recordingAlreadyInProgress,
         .recordingNotInProgress:
      return nil
    }
  }

  var flutterError: FlutterError {
    FlutterError(
      code: code,
      message: underlyingError?.localizedDescription ?? code,
      details: nil
    )
  }
}

struct CreatorRecordingPaths {
  static let screenFilename = "screen.mov"
  static let cameraFilename = "camera.mov"
  static let microphoneFilename = "microphone.m4a"
  static let movementFilename = "movement.json"
  static let composedFilename = "final.mov"
  static let manifestFilename = "manifest.json"

  let id: UUID
  let createdAt: Date
  let directory: URL

  var screenURL: URL { directory.appendingPathComponent(Self.screenFilename) }
  var cameraURL: URL { directory.appendingPathComponent(Self.cameraFilename) }
  var microphoneURL: URL { directory.appendingPathComponent(Self.microphoneFilename) }
  var movementURL: URL { directory.appendingPathComponent(Self.movementFilename) }
  var composedURL: URL { directory.appendingPathComponent(Self.composedFilename) }
  var manifestURL: URL { directory.appendingPathComponent(Self.manifestFilename) }
}

struct CreatorRecordingManifest: Codable {
  struct Files: Codable {
    let composedVideo: String
    let screenVideo: String
    let cameraVideo: String
    let microphoneAudio: String
    let movementMetadata: String
  }

  let schemaVersion: Int
  let id: String
  let createdAt: Date
  let durationMs: Int
  let files: Files
}

struct CreatorRecordingArtifactPayload {
  let paths: CreatorRecordingPaths
  let durationMs: Int

  var channelValue: [String: Any] {
    [
      "id": paths.id.uuidString,
      "createdAt": CreatorRecordingLibrary.dateFormatter.string(from: paths.createdAt),
      "durationMs": durationMs,
      "composedVideoPath": paths.composedURL.path,
      "screenVideoPath": paths.screenURL.path,
      "cameraVideoPath": paths.cameraURL.path,
      "microphoneAudioPath": paths.microphoneURL.path,
      "movementMetadataPath": paths.movementURL.path,
      "manifestPath": paths.manifestURL.path,
    ]
  }
}

final class CreatorRecordingLibrary {
  static let dateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private let fileManager: FileManager
  private let rootResult: Result<URL, Error>

  init(fileManager: FileManager = .default, rootURL: URL? = nil) {
    self.fileManager = fileManager
    do {
      let resolvedRoot: URL
      if let rootURL {
        resolvedRoot = rootURL
      } else {
        let applicationSupport = try fileManager.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        resolvedRoot = applicationSupport.appendingPathComponent(
          "SesoriCreatorRecordings",
          isDirectory: true
        )
      }
      try fileManager.createDirectory(at: resolvedRoot, withIntermediateDirectories: true)
      self.rootResult = .success(resolvedRoot)
    } catch {
      self.rootResult = .failure(error)
    }
  }

  func createRecording() throws -> CreatorRecordingPaths {
    let rootURL = try rootResult.get()
    let id = UUID()
    let paths = CreatorRecordingPaths(
      id: id,
      createdAt: Date(),
      directory: rootURL.appendingPathComponent(id.uuidString, isDirectory: true)
    )
    try fileManager.createDirectory(at: paths.directory, withIntermediateDirectories: true)
    return paths
  }

  func saveManifest(paths: CreatorRecordingPaths, durationMs: Int) throws -> CreatorRecordingArtifactPayload {
    let manifest = CreatorRecordingManifest(
      schemaVersion: 1,
      id: paths.id.uuidString,
      createdAt: paths.createdAt,
      durationMs: durationMs,
      files: CreatorRecordingManifest.Files(
        composedVideo: CreatorRecordingPaths.composedFilename,
        screenVideo: CreatorRecordingPaths.screenFilename,
        cameraVideo: CreatorRecordingPaths.cameraFilename,
        microphoneAudio: CreatorRecordingPaths.microphoneFilename,
        movementMetadata: CreatorRecordingPaths.movementFilename
      )
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    try encoder.encode(manifest).write(to: paths.manifestURL, options: .atomic)
    return CreatorRecordingArtifactPayload(paths: paths, durationMs: durationMs)
  }

  func listRecordings() throws -> [CreatorRecordingArtifactPayload] {
    let rootURL = try rootResult.get()
    let directories = try fileManager.contentsOfDirectory(
      at: rootURL,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    var recordings: [CreatorRecordingArtifactPayload] = []
    for directory in directories {
      do {
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true,
              let id = UUID(uuidString: directory.lastPathComponent) else { continue }
        let manifestURL = directory.appendingPathComponent(CreatorRecordingPaths.manifestFilename)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(
          CreatorRecordingManifest.self,
          from: Data(contentsOf: manifestURL)
        )
        guard manifest.schemaVersion == 1,
              manifest.id == id.uuidString,
              manifest.durationMs >= 0 else { continue }
        let paths = CreatorRecordingPaths(id: id, createdAt: manifest.createdAt, directory: directory)
        guard requiredFiles(for: paths).allSatisfy({ fileManager.fileExists(atPath: $0.path) }) else {
          continue
        }
        recordings.append(
          CreatorRecordingArtifactPayload(paths: paths, durationMs: manifest.durationMs)
        )
      } catch {
        NSLog(
          "Ignoring incomplete creator recording at %@: %@",
          directory.path,
          String(describing: error)
        )
      }
    }
    return recordings.sorted { $0.paths.createdAt > $1.paths.createdAt }
  }

  func deleteRecording(id: String) throws {
    guard let uuid = UUID(uuidString: id) else {
      throw CocoaError(.fileReadInvalidFileName)
    }
    let rootURL = try rootResult.get()
    let directory = rootURL.appendingPathComponent(uuid.uuidString, isDirectory: true)
    guard fileManager.fileExists(atPath: directory.path) else { return }
    try fileManager.removeItem(at: directory)
  }

  func discard(paths: CreatorRecordingPaths) {
    guard fileManager.fileExists(atPath: paths.directory.path) else { return }
    do {
      try fileManager.removeItem(at: paths.directory)
    } catch {
      NSLog(
        "Failed to discard incomplete creator recording at %@: %@",
        paths.directory.path,
        String(describing: error)
      )
    }
  }

  private func requiredFiles(for paths: CreatorRecordingPaths) -> [URL] {
    [
      paths.composedURL,
      paths.screenURL,
      paths.cameraURL,
      paths.microphoneURL,
      paths.movementURL,
      paths.manifestURL,
    ]
  }
}
