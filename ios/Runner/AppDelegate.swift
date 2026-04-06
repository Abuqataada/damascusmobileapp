import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "damascus_projects/recording_saver",
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "saveRecording":
          guard
            let args = call.arguments as? [String: Any],
            let fileName = args["fileName"] as? String,
            let bytes = args["bytes"] as? FlutterStandardTypedData
          else {
            result(
              FlutterError(
                code: "invalid_args",
                message: "Missing fileName or bytes",
                details: nil
              )
            )
            return
          }

          self.saveVideoToPhotos(fileName: fileName, data: bytes.data, result: result)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func saveVideoToPhotos(fileName: String, data: Data, result: @escaping FlutterResult) {
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

    do {
      try data.write(to: tempURL, options: .atomic)
    } catch {
      result(
        FlutterError(
          code: "write_failed",
          message: error.localizedDescription,
          details: nil
        )
      )
      return
    }

    PHPhotoLibrary.requestAuthorization { status in
      guard status == .authorized || status == .limited else {
        try? FileManager.default.removeItem(at: tempURL)
        result(
          FlutterError(
            code: "photo_permission_denied",
            message: "Photo library access was not granted",
            details: nil
          )
        )
        return
      }

      PHPhotoLibrary.shared().performChanges({
        PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
      }, completionHandler: { success, error in
        try? FileManager.default.removeItem(at: tempURL)
        if success {
          result(tempURL.absoluteString)
        } else {
          result(
            FlutterError(
              code: "save_failed",
              message: error?.localizedDescription ?? "Unable to save video",
              details: nil
            )
          )
        }
      })
    }
  }
}
