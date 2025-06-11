package com.example.new_pose

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.MediaRecorder
import android.media.projection.MediaProjection
import android.util.DisplayMetrics
import android.util.Log
import android.provider.Settings
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

class MainActivity: FlutterActivity() {
    private val CHANNEL = "screen_recording"
    private val REQUEST_CODE_SCREEN_CAPTURE = 1000
    private val REQUEST_CODE_OVERLAY = 1001

    private var mediaProjectionManager: MediaProjectionManager? = null
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var mediaRecorder: MediaRecorder? = null
    private var screenDensity = 0
    private var isRecording = false
    private var pendingResult: MethodChannel.Result? = null
    private var hasOverlayPermission = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    checkOverlayPermission(result)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission(result)
                }
                "startAutomaticScreenRecording" -> {
                    startAutomaticScreenRecording(result)
                }
                "stopAutomaticScreenRecording" -> {
                    stopAutomaticScreenRecording(result)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        initializeScreenRecording()
    }

    private fun initializeScreenRecording() {
        mediaProjectionManager = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val metrics = DisplayMetrics()
        windowManager.defaultDisplay.getMetrics(metrics)
        screenDensity = metrics.densityDpi

        // 오버레이 권한 확인
        hasOverlayPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    // 오버레이 권한 확인
    private fun checkOverlayPermission(result: MethodChannel.Result) {
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
        result.success(hasPermission)
    }

    // 오버레이 권한 요청
    private fun requestOverlayPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                pendingResult = result
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, REQUEST_CODE_OVERLAY)
            } else {
                result.success(true)
            }
        } else {
            result.success(true)
        }
    }

    // 접근성 설정 열기
    private fun openAccessibilitySettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // 자동 화면 녹화 시작 (권한 설정 완료 후)
    private fun startAutomaticScreenRecording(result: MethodChannel.Result) {
        if (!hasOverlayPermission) {
            result.error("NO_PERMISSION", "오버레이 권한이 필요합니다", null)
            return
        }

        if (isRecording) {
            result.success(true)
            return
        }

        pendingResult = result

        // MediaProjection 권한 자동 요청
        val captureIntent = mediaProjectionManager?.createScreenCaptureIntent()
        startActivityForResult(captureIntent, REQUEST_CODE_SCREEN_CAPTURE)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        when (requestCode) {
            REQUEST_CODE_SCREEN_CAPTURE -> {
                if (resultCode == Activity.RESULT_OK && data != null) {
                    try {
                        mediaProjection = mediaProjectionManager?.getMediaProjection(resultCode, data)
                        setupMediaRecorder()
                        setupVirtualDisplay()
                        mediaRecorder?.start()
                        isRecording = true

                        Log.d("AutoScreenRecording", "자동 화면 녹화 시작됨")
                        pendingResult?.success(true)
                    } catch (e: Exception) {
                        Log.e("AutoScreenRecording", "녹화 시작 실패", e)
                        pendingResult?.error("START_FAILED", "녹화 시작 실패: ${e.message}", null)
                    }
                } else {
                    Log.e("AutoScreenRecording", "화면 녹화 권한 거부됨")
                    pendingResult?.success(false)
                }
                pendingResult = null
            }

            REQUEST_CODE_OVERLAY -> {
                val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(this)
                } else {
                    true
                }
                hasOverlayPermission = hasPermission
                pendingResult?.success(hasPermission)
                pendingResult = null
            }
        }
    }

    private fun setupMediaRecorder() {
        // 외부 저장소에 저장 (갤러리에서 접근 가능)
        val moviesDir = getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES)
        if (!moviesDir?.exists()!!) {
            moviesDir.mkdirs()
        }

        val videoFile = File(moviesDir, "pose_recording_${System.currentTimeMillis()}.mp4")

        mediaRecorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }

        mediaRecorder?.apply {
            setVideoSource(MediaRecorder.VideoSource.SURFACE)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setOutputFile(videoFile.absolutePath)
            setVideoEncoder(MediaRecorder.VideoEncoder.H264)

            // 고품질 설정
            setVideoSize(1080, 1920)
            setVideoFrameRate(30)
            setVideoEncodingBitRate(12000000) // 12Mbps 고품질

            try {
                prepare()
                Log.d("AutoScreenRecording", "MediaRecorder 준비 완료: ${videoFile.absolutePath}")
            } catch (e: IOException) {
                Log.e("AutoScreenRecording", "MediaRecorder 준비 실패", e)
                throw e
            }
        }
    }

    private fun setupVirtualDisplay() {
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "AutoScreenRecording",
            1080, 1920, screenDensity,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            mediaRecorder?.surface, null, null
        )
        Log.d("AutoScreenRecording", "VirtualDisplay 생성됨")
    }

    private fun stopAutomaticScreenRecording(result: MethodChannel.Result) {
        if (!isRecording) {
            result.success(false)
            return
        }

        try {
            mediaRecorder?.stop()
            mediaRecorder?.reset()
            mediaRecorder?.release()
            mediaRecorder = null

            virtualDisplay?.release()
            virtualDisplay = null

            mediaProjection?.stop()
            mediaProjection = null

            isRecording = false

            // 갤러리 스캔 (파일을 갤러리에서 보이게 함)
            scanMediaFile()

            Log.d("AutoScreenRecording", "자동 화면 녹화 중지됨")
            result.success(true)
        } catch (e: Exception) {
            Log.e("AutoScreenRecording", "화면 녹화 중지 실패", e)
            result.success(false)
        }
    }

    private fun scanMediaFile() {
        try {
            val moviesDir = getExternalFilesDir(android.os.Environment.DIRECTORY_MOVIES)
            sendBroadcast(Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(moviesDir)))
        } catch (e: Exception) {
            Log.e("AutoScreenRecording", "미디어 스캔 실패", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (isRecording) {
            stopAutomaticScreenRecording(object : MethodChannel.Result {
                override fun success(result: Any?) {}
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                override fun notImplemented() {}
            })
        }
    }
}