package com.syndro.app

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.syndro.app/device_info"
    private val TRANSFER_CHANNEL = "com.syndro.app/transfer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceName" -> {
                    val deviceName = getDeviceName()
                    result.success(deviceName)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Transfer Channel (for background notifications)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSFER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundTransfer" -> {
                    // Handle background transfer start
                    result.success(null)
                }
                "updateTransferProgress" -> {
                    // Handle progress update
                    result.success(null)
                }
                "stopBackgroundTransfer" -> {
                    // Handle transfer stop
                    result.success(null)
                }
                "showTransferRequest" -> {
                    // Handle transfer request notification
                    result.success(null)
                }
                "showTransferComplete" -> {
                    // Handle transfer complete notification
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getDeviceName(): String {
        val manufacturer = Build.MANUFACTURER
        val model = Build.MODEL
        
        return if (model.startsWith(manufacturer, ignoreCase = true)) {
            capitalize(model)
        } else {
            "${capitalize(manufacturer)} $model"
        }
    }

    private fun capitalize(s: String): String {
        return if (s.isEmpty()) {
            s
        } else {
            s.split(" ").joinToString(" ") { word ->
                word.replaceFirstChar { 
                    if (it.isLowerCase()) it.titlecase() else it.toString() 
                }
            }
        }
    }
}
