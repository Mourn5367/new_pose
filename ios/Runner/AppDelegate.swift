import UIKit
import Flutter
import ReplayKit
import Photos

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    private var screenRecorder: RPScreenRecorder?
    private var isRecording = false
    private var methodChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        methodChannel = FlutterMethodChannel(name: "screen_recording", binaryMessenger: controller.binaryMessenger)

        methodChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "checkOverlayPermission":
                result(true) // iOS는 항상 true
            case "requestOverlayPermission":
                result(true) // iOS는 항상 true
            case "startAutomaticScreenRecording":
                self?.startAutomaticScreenRecording(result: result)
            case "stopAutomaticScreenRecording":
                self?.stopAutomaticScreenRecording(result: result)
            case "openAccessibilitySettings":
                self?.openAccessibilitySettings(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        screenRecorder = RPScreenRecorder.shared()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // iOS 자동 화면 녹화 (ReplayKit 사용)
    private func startAutomaticScreenRecording(result: @escaping FlutterResult) {
        guard let screenRecorder = screenRecorder else {
            result(FlutterError(code: "NO_RECORDER", message: "Screen recorder not available", details: nil))
            return
        }

        if isRecording {
            result(true)
            return
        }

        // iOS는 사용자 허용이 필요하지만 최소화된 UI로 표시
        screenRecorder.startRecording { [weak self] (error) in
            DispatchQueue.main.async {
                if let error = error {
                    print("iOS 자동 화면 녹화 실패: \(error.localizedDescription)")
                    result(FlutterError(code: "START_FAILED", message: error.localizedDescription, details: nil))
                } else {
                    print("iOS 자동 화면 녹화 시작됨")
                    self?.isRecording = true
                    result(true)
                }
            }
        }
    }

    private func stopAutomaticScreenRecording(result: @escaping FlutterResult) {
        guard let screenRecorder = screenRecorder else {
            result(false)
            return
        }

        if !isRecording {
            result(false)
            return
        }

        screenRecorder.stopRecording { [weak self] (preview, error) in
            DispatchQueue.main.async {
                self?.isRecording = false

                if let error = error {
                    print("iOS 화면 녹화 중지 실패: \(error.localizedDescription)")
                    result(false)
                    return
                }

                guard let preview = preview else {
                    result(false)
                    return
                }

                // 자동으로 갤러리에 저장
                self?.saveToPhotoLibraryAutomatically(preview: preview) { success in
                    print("iOS 자동 화면 녹화 중지 및 저장: \(success)")
                    result(success)
                }
            }
        }
    }

    // 갤러리에 자동 저장 (UI 없이)
    private func saveToPhotoLibraryAutomatically(preview: RPPreviewViewController, completion: @escaping (Bool) -> Void) {
        // 미리보기 없이 바로 저장
        preview.previewControllerDelegate = self

        if let movieURL = preview.movieURL {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: movieURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        print("iOS 갤러리 자동 저장 성공")
                        completion(true)
                    } else {
                        print("iOS 갤러리 저장 실패: \(error?.localizedDescription ?? "Unknown error")")
                        completion(false)
                    }
                }
            }
        } else {
            completion(false)
        }
    }

    private func openAccessibilitySettings(result: @escaping FlutterResult) {
        // iOS는 접근성 설정이 아닌 설정 앱으로 이동
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl) { success in
                result(success)
            }
        } else {
            result(false)
        }
    }
}

extension AppDelegate: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
    }
}