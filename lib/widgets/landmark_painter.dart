import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class LandmarkPainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final Size previewSize;

  LandmarkPainter({
    required this.poses,
    required this.imageSize,
    required this.previewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 디버깅 로그
    print('LandmarkPainter - 포즈 개수: ${poses.length}');
    print('LandmarkPainter - 이미지 크기: $imageSize');
    print('LandmarkPainter - 프리뷰 크기: $previewSize');
    print('LandmarkPainter - 캔버스 크기: $size');

    // // 테스트용 고정 원 그리기
    // final testPaint = Paint()
    //   ..color = Colors.red
    //   ..strokeWidth = 4.0
    //   ..style = PaintingStyle.fill;
    // canvas.drawCircle(Offset(100, 100), 20, testPaint);
    // canvas.drawCircle(Offset(200, 200), 20, testPaint);

    // 포즈 랜드마크 그리기
    for (final pose in poses) {
      _drawPose(canvas, pose);
    }
  }

  void _drawPose(Canvas canvas, Pose pose) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4.0
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    print('포즈 랜드마크 개수: ${pose.landmarks.length}');

    // 주요 포즈 랜드마크 포인트들 그리기
    pose.landmarks.forEach((type, landmark) {
      if (landmark != null) {
        final point = _translatePoint(landmark.x.toDouble(), landmark.y.toDouble());
        print('랜드마크 $type: 원본(${landmark.x}, ${landmark.y}) -> 변환($point)');
        canvas.drawCircle(point, 8, paint);
      }
    });

    // 스켈레톤 연결선 그리기
    _drawPoseConnections(canvas, pose, linePaint);
  }

  void _drawPoseConnections(Canvas canvas, Pose pose, Paint paint) {
    // 신체 주요 연결선들
    final connections = [
      // 얼굴
      [PoseLandmarkType.leftEar, PoseLandmarkType.leftEye],
      [PoseLandmarkType.leftEye, PoseLandmarkType.nose],
      [PoseLandmarkType.nose, PoseLandmarkType.rightEye],
      [PoseLandmarkType.rightEye, PoseLandmarkType.rightEar],

      // 상체
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder],
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow],
      [PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow],
      [PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist],

      // 몸통
      [PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip],
      [PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip],
      [PoseLandmarkType.leftHip, PoseLandmarkType.rightHip],

      // 하체
      [PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee],
      [PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle],
      [PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee],
      [PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle],
    ];

    for (final connection in connections) {
      final startLandmark = pose.landmarks[connection[0]];
      final endLandmark = pose.landmarks[connection[1]];

      if (startLandmark != null && endLandmark != null) {
        final startPoint = _translatePoint(startLandmark.x.toDouble(), startLandmark.y.toDouble());
        final endPoint = _translatePoint(endLandmark.x.toDouble(), endLandmark.y.toDouble());
        canvas.drawLine(startPoint, endPoint, paint);
      }
    }
  }

  Offset _translatePoint(double x, double y) {
    // 이미지 좌표를 화면 프리뷰 좌표로 변환
    if (imageSize.isEmpty || previewSize.isEmpty) {
      return Offset(x, y);
    }

    final scaleX = previewSize.width / imageSize.width;
    final scaleY = previewSize.height / imageSize.height;

    return Offset(x * scaleX, y * scaleY);
  }

  @override
  bool shouldRepaint(LandmarkPainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}