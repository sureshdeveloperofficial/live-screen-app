package com.vizilink.securitylab.vizilink_security_lab

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.vizilink.securitylab/screen_capture"
    private var methodChannel: MethodChannel? = null

    private val captureStoppedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            methodChannel?.invokeMethod("onScreenCaptureStopped", null)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    try {
                        ScreenCaptureService.startService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        ScreenCaptureService.stopService(this)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", e.message, null)
                    }
                }
                "isServiceRunning" -> {
                    result.success(ScreenCaptureService.isRunning)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(ScreenCaptureService.BROADCAST_STOPPED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(captureStoppedReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(captureStoppedReceiver, filter)
        }
    }

    override fun onStop() {
        super.onStop()
        try {
            unregisterReceiver(captureStoppedReceiver)
        } catch (e: IllegalArgumentException) {
            // Receiver not registered
        }
    }
}
