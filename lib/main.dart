import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'screens/landmark_detection_screen.dart';

List<CameraDescription> cameras = [];

void main() async {
  // Flutter 위젯 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 사용 가능한 카메라 목록 획득
    cameras = await availableCameras();
  } catch (e) {
    print('카메라 초기화 에러: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '랜드마크 감지 앱',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LandmarkDetectionScreen(cameras: cameras),
      debugShowCheckedModeBanner: false,
    );
  }
}