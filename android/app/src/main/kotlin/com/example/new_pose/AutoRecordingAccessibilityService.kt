package com.example.new_pose

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AutoRecordingAccessibilityService : AccessibilityService() {

    override fun onServiceConnected() {
        super.onServiceConnected()

        val info = AccessibilityServiceInfo().apply {
            eventTypes = AccessibilityEvent.TYPES_ALL_MASK
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            flags = AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS or
                    AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }

        serviceInfo = info
        Log.d("AccessibilityService", "자동 녹화 접근성 서비스 연결됨")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 필요한 경우 자동화 로직 구현
        // 예: 특정 앱이나 화면에서 자동으로 녹화 시작
    }

    override fun onInterrupt() {
        Log.d("AccessibilityService", "접근성 서비스 중단됨")
    }

    // 화면 녹화 자동 시작 트리거
    fun triggerAutoRecording() {
        try {
            // 메인 액티비티로 신호 전송
            val intent = Intent("com.example.new_pose.AUTO_RECORD_TRIGGER")
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e("AccessibilityService", "자동 녹화 트리거 실패", e)
        }
    }
}