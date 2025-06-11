import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'landmark_painter.dart';

class CameraView extends StatelessWidget {
  final CameraController controller;
  final List<Pose> poses;

  const CameraView({
    Key? key,
    required this.controller,
    required this.poses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 카메라 프리뷰
        CameraPreview(controller),

        // 랜드마크 오버레이
        CustomPaint(
          painter: LandmarkPainter(
            poses: poses,
            imageSize: _getImageSize(),
            previewSize: _getPreviewSize(context),
          ),
        ),
      ],
    );
  }

  Size _getImageSize() {
    // 카메라 이미지 크기 반환
    if (controller.value.isInitialized) {
      final size = Size(
        controller.value.previewSize!.height,
        controller.value.previewSize!.width,
      );
      print('CameraView - 이미지 크기: $size');
      return size;
    }
    print('CameraView - 카메라 초기화 안됨');
    return Size.zero;
  }

  Size _getPreviewSize(BuildContext context) {
    // 화면 프리뷰 크기 반환
    final size = MediaQuery.of(context).size;
    print('CameraView - 프리뷰 크기: $size');
    return size;
  }
}