import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/camera_view.dart';
import '../widgets/landmark_painter.dart';

class LandmarkDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const LandmarkDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _LandmarkDetectionScreenState createState() => _LandmarkDetectionScreenState();
}

class _LandmarkDetectionScreenState extends State<LandmarkDetectionScreen> {
  CameraController? _cameraController;
  bool _isDetecting = false;

  // ML Kit 감지기
  late PoseDetector _poseDetector;

  // 감지 결과
  List<Pose> _poses = [];

  // 비디오 녹화 관련
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    _initializeDetectors();
    _requestPermissions();
    _initializeCamera();
  }

  Future<void> _requestPermissions() async {
    // 필수 권한만 요청 (저장소 권한 제외)
    await [
      Permission.camera,
      Permission.microphone,
    ].request();

    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    print('카메라 권한: $cameraStatus');
    print('마이크 권한: $microphoneStatus');

    if (!cameraStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('카메라 권한이 필요합니다. 설정에서 권한을 허용해주세요.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: '설정',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    }
  }

  void _initializeDetectors() {
    // 포즈 감지기 초기화 - 빠른 모드로 변경
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream, // 스트림 모드 유지
        model: PoseDetectionModel.base, // accurate에서 base로 변경 (더 빠름)
      ),
    );
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.isEmpty) {
      print('사용 가능한 카메라가 없습니다');
      return;
    }

    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium, // 비디오 품질을 위해 medium으로 복원
      enableAudio: true, // 비디오 녹화를 위해 오디오 활성화
    );

    try {
      await _cameraController!.initialize();
      setState(() {});

      // 빠른 주기로 사진 촬영해서 포즈 감지 (비디오 녹화와 별도)
      _startPeriodicCapture();
    } catch (e) {
      print('카메라 초기화 에러: $e');
    }
  }

  void _startPeriodicCapture() {
    Stream.periodic(Duration(milliseconds: 100)).listen((_) {
      // 녹화 중이 아닐 때만 포즈 감지용 사진 촬영
      if (!_isProcessing && !_isRecording && _cameraController?.value.isInitialized == true) {
        _captureAndAnalyze();
      }
    });
  }

  Future<void> _captureAndAnalyze() async {
    if (_isProcessing) return;

    _isProcessing = true;

    try {
      final XFile image = await _cameraController!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      final poses = await _poseDetector.processImage(inputImage);
      setState(() {
        _poses = poses;
      });

      // 백그라운드에서 파일 삭제
      File(image.path).delete().catchError((_) {});

    } catch (e) {
      print('사진 촬영 분석 에러: $e');
    }

    _isProcessing = false;
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      print('비디오 녹화 시작...');
      await _cameraController!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });

      print('비디오 녹화 시작됨 (포즈 감지 계속 진행)');
    } catch (e) {
      print('비디오 녹화 시작 에러: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      print('녹화 중지 시작...');
      final XFile videoFile = await _cameraController!.stopVideoRecording();
      print('비디오 파일 생성 완료: ${videoFile.path}');

      setState(() {
        _isRecording = false;
      });

      // 임시 파일이 실제로 존재하는지 확인
      final tempFile = File(videoFile.path);
      if (!await tempFile.exists()) {
        throw Exception('임시 비디오 파일이 생성되지 않았습니다');
      }

      final fileSize = await tempFile.length();
      print('임시 파일 크기: $fileSize bytes');

      if (fileSize == 0) {
        throw Exception('비디오 파일이 비어있습니다');
      }

      // 앱 내부 저장소 경로 확인
      final appDocDir = await getApplicationDocumentsDirectory();
      print('앱 문서 디렉토리: ${appDocDir.path}');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'pose_video_$timestamp.mp4';
      final destinationPath = '${appDocDir.path}/$fileName';
      print('목적지 경로: $destinationPath');

      // 파일 복사
      print('파일 복사 시작...');
      await tempFile.copy(destinationPath);
      print('파일 복사 완료');

      // 복사된 파일 확인
      final destFile = File(destinationPath);
      if (!await destFile.exists()) {
        throw Exception('파일 복사 실패: 목적지 파일이 없습니다');
      }

      final destFileSize = await destFile.length();
      print('복사된 파일 크기: $destFileSize bytes');

      // 임시 파일 삭제
      await tempFile.delete();
      print('임시 파일 삭제 완료');

      print('비디오 저장 완료: $destinationPath');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ 포즈 감지 비디오 저장 성공!\n파일 크기: ${(destFileSize / 1024 / 1024).toStringAsFixed(2)} MB'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
          action: SnackBarAction(
            label: '경로 보기',
            textColor: Colors.white,
            onPressed: () {
              print('파일 경로: $destinationPath');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('경로: $destinationPath')),
              );
            },
          ),
        ),
      );

    } catch (e, stackTrace) {
      print('비디오 저장 에러: $e');
      print('스택 트레이스: $stackTrace');

      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ 비디오 저장 실패\n에러: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text('랜드마크 감지')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('포즈 랜드마크 감지'),
        actions: [
          IconButton(
            icon: Icon(_isRecording ? Icons.stop : Icons.videocam),
            onPressed: _isRecording ? _stopRecording : _startRecording,
            color: _isRecording ? Colors.red : Colors.white,
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraView(
            controller: _cameraController!,
            poses: _poses,
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                // 녹화 상태 표시
                if (_isRecording)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('녹화 중', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                SizedBox(height: 8),
                // 포즈 감지 정보
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '포즈 감지: ${_poses.length}개 감지됨',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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