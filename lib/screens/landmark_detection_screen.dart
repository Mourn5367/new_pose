import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../widgets/camera_view.dart';

class AutoScreenRecordingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const AutoScreenRecordingScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _AutoScreenRecordingScreenState createState() => _AutoScreenRecordingScreenState();
}

class _AutoScreenRecordingScreenState extends State<AutoScreenRecordingScreen> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;

  bool _isDetecting = false;
  bool _isProcessing = false;
  bool _isRecording = false;
  List<Pose> _poses = [];

  static const platform = MethodChannel('screen_recording');

  @override
  void initState() {
    super.initState();
    _initializeDetector();
    _requestPermissions();
    _initializeCamera();
  }

  void _initializeDetector() {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
    ].request();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      print('카메라 초기화 에러: $e');
    }
  }

  // 원클릭 자동 화면 녹화 + 포즈 감지
  Future<void> _startAutoScreenRecording() async {
    try {
      print('🚀 원클릭 자동 화면 녹화 시작...');

      // 1. 포즈 감지 먼저 시작
      await _cameraController!.startImageStream(_processPoseDetection);
      setState(() { _isDetecting = true; });
      print('✅ 포즈 감지 시작됨');

      // 2. 자동 화면 녹화 시작 시도
      final success = await _startScreenRecordingAutomatically();

      if (success) {
        setState(() { _isRecording = true; });
        _showRecordingStartedMessage();
      } else {
        _showQuickAccessInstructions();
      }

    } catch (e) {
      print('자동 시작 에러: $e');
      _showQuickAccessInstructions();
    }
  }

  // 자동 화면 녹화 시작 (플랫폼별)
  Future<bool> _startScreenRecordingAutomatically() async {
    try {
      if (Platform.isAndroid) {
        return await _startAndroidScreenRecording();
      } else if (Platform.isIOS) {
        return await _startIOSScreenRecording();
      }
      return false;
    } catch (e) {
      print('자동 화면 녹화 실패: $e');
      return false;
    }
  }

  // Android 자동 화면 녹화
  Future<bool> _startAndroidScreenRecording() async {
    try {
      // MediaProjection 권한 요청 및 녹화 시작
      final result = await platform.invokeMethod('startScreenRecording');
      return result == true;
    } catch (e) {
      print('Android 화면 녹화 에러: $e');
      return false;
    }
  }

  // iOS 자동 화면 녹화
  Future<bool> _startIOSScreenRecording() async {
    try {
      // ReplayKit 사용해서 녹화 시작
      final result = await platform.invokeMethod('startScreenRecording');
      return result == true;
    } catch (e) {
      print('iOS 화면 녹화 에러: $e');
      return false;
    }
  }

  // 녹화 시작 성공 메시지
  void _showRecordingStartedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text('🎬 자동 화면 녹화 시작됨!\n포즈 동작을 시작하세요!'),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
  }

  // 빠른 접근 안내 (자동 실패시)
  void _showQuickAccessInstructions() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.flash_on, color: Colors.orange),
            SizedBox(width: 8),
            Text('빠른 화면 녹화'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('포즈 감지가 실행 중입니다! ✅',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            SizedBox(height: 16),

            if (Platform.isAndroid) ...[
              Text('⚡ 빠른 방법:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('📱 '),
                        Expanded(child: Text('알림창 빠르게 내리기', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Row(
                      children: [
                        Text('🎬 '),
                        Expanded(child: Text('"화면 녹화" 원터치!', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text('⚡ 빠른 방법:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('📱 '),
                        Expanded(child: Text('제어 센터 빠르게 열기', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Row(
                      children: [
                        Text('🎬 '),
                        Expanded(child: Text('"화면 기록" 원터치!', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '💡 한 번만 설정하면 다음부터는 더 빨라져요!',
                style: TextStyle(fontSize: 12, color: Colors.green.shade700),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('시작하기', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 포즈 감지 처리
  void _processPoseDetection(CameraImage cameraImage) async {
    if (!_isDetecting || _isProcessing) return;
    _isProcessing = true;

    try {
      final inputImage = _cameraImageToInputImage(cameraImage);
      final poses = await _poseDetector.processImage(inputImage);

      if (mounted) {
        setState(() { _poses = poses; });
      }

    } catch (e) {
      print('포즈 감지 에러: $e');
    }

    _isProcessing = false;
  }

  InputImage _cameraImageToInputImage(CameraImage cameraImage) {
    final camera = widget.cameras.first;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation rotation = InputImageRotation.rotation0deg;
    if (Platform.isAndroid) {
      switch (sensorOrientation) {
        case 90: rotation = InputImageRotation.rotation90deg; break;
        case 180: rotation = InputImageRotation.rotation180deg; break;
        case 270: rotation = InputImageRotation.rotation270deg; break;
        default: rotation = InputImageRotation.rotation0deg;
      }
    }

    InputImageFormat format;
    Uint8List bytes;
    int bytesPerRow;

    if (Platform.isAndroid) {
      format = InputImageFormat.nv21;
      final allBytes = <int>[];
      for (final plane in cameraImage.planes) {
        allBytes.addAll(plane.bytes);
      }
      bytes = Uint8List.fromList(allBytes);
      bytesPerRow = cameraImage.planes.first.bytesPerRow;
    } else {
      format = InputImageFormat.bgra8888;
      bytes = cameraImage.planes.first.bytes;
      bytesPerRow = cameraImage.planes.first.bytesPerRow;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(cameraImage.width.toDouble(), cameraImage.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  // 모든 것 중지
  Future<void> _stopEverything() async {
    try {
      // 포즈 감지 중지
      if (_isDetecting) {
        await _cameraController!.stopImageStream();
        setState(() { _isDetecting = false; });
      }

      // 화면 녹화 중지 시도
      if (_isRecording) {
        try {
          await platform.invokeMethod('stopScreenRecording');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎬 화면 녹화가 중지되었습니다!'),
              backgroundColor: Colors.blue,
            ),
          );
        } catch (e) {
          print('화면 녹화 자동 중지 실패: $e');
        }
        setState(() { _isRecording = false; });
      }

      setState(() { _poses.clear(); });

    } catch (e) {
      print('중지 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('자동 화면 녹화')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('원클릭 자동 화면 녹화'),
        backgroundColor: _isRecording ? Colors.red.shade400 : null,
      ),
      body: Stack(
        children: [
          // 카메라 뷰 + 포즈 오버레이
          CameraView(
            controller: _cameraController!,
            poses: _poses,
          ),

          // 녹화 상태 표시
          if (_isRecording)
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      '🎬 화면 녹화 중 + 포즈 감지 중',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 컨트롤 UI
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Text(
                  '포즈 감지: ${_poses.length}명',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: (_isDetecting || _isRecording) ? _stopEverything : _startAutoScreenRecording,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (_isDetecting || _isRecording) ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        (_isDetecting || _isRecording) ? '🛑 전체 중지' : '🚀 원클릭 시작',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 15),

                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚡ 원클릭으로 포즈 감지 + 화면 녹화 자동 시작!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _poseDetector.close();
    super.dispose();
  }
}