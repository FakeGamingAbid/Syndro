package com.syndro.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.RingtoneManager
import android.os.Build
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DEVICE_INFO_CHANNEL = "com.syndro.app/device_info"
    private val TRANSFER_CHANNEL = "com.syndro.app/transfer"
    private val TRANSFER_EVENTS_CHANNEL = "com.syndro.app/transfer_events"
    private val SHARE_INTENT_CHANNEL = "com.syndro.app/share_intent"
    private val SOUND_CHANNEL = "com.syndro.app/sound"

    private var eventSink: EventChannel.EventSink? = null
    private var transferEventReceiver: BroadcastReceiver? = null
    private var pendingShareIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Handle share intent if app was launched from share
        handleShareIntent(intent)

        // Device Info Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
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

        // Transfer Events Channel (for receiving events from notification actions)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSFER_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerTransferEventReceiver()
                }

                override fun onCancel(arguments: Any?) {
                    unregisterTransferEventReceiver()
                    eventSink = null
                }
            })

        // Transfer Channel - Connected to TransferService
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRANSFER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startBackgroundTransfer" -> {
                        val title = call.argument<String>("title") ?: "Transferring files..."
                        val fileName = call.argument<String>("fileName") ?: ""

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_START
                            putExtra(TransferService.EXTRA_TITLE, title)
                            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }

                    "updateTransferProgress" -> {
                        val title = call.argument<String>("title") ?: "Transferring files..."
                        val fileName = call.argument<String>("fileName") ?: ""
                        val progress = call.argument<Int>("progress") ?: 0
                        val speed = call.argument<String>("speed")
                        val timeRemaining = call.argument<String>("timeRemaining")
                        val bytesTransferred = call.argument<Number>("bytesTransferred")?.toLong() ?: 0L
                        val totalBytes = call.argument<Number>("totalBytes")?.toLong() ?: 0L

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_UPDATE
                            putExtra(TransferService.EXTRA_TITLE, title)
                            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
                            putExtra(TransferService.EXTRA_PROGRESS, progress)
                            putExtra(TransferService.EXTRA_SPEED, speed)
                            putExtra(TransferService.EXTRA_TIME_REMAINING, timeRemaining)
                            putExtra(TransferService.EXTRA_BYTES_TRANSFERRED, bytesTransferred)
                            putExtra(TransferService.EXTRA_TOTAL_BYTES, totalBytes)
                        }
                        startService(intent)
                        result.success(null)
                    }

                    "stopBackgroundTransfer" -> {
                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(null)
                    }

                    "showTransferRequest" -> {
                        val senderName = call.argument<String>("senderName") ?: "Unknown"
                        val fileCount = call.argument<Int>("fileCount") ?: 1
                        val totalSize = call.argument<Number>("totalSize")?.toLong() ?: 0L
                        val requestId = call.argument<String>("requestId") ?: ""

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_SHOW_REQUEST
                            putExtra(TransferService.EXTRA_SENDER_NAME, senderName)
                            putExtra(TransferService.EXTRA_FILE_COUNT, fileCount)
                            putExtra(TransferService.EXTRA_TOTAL_SIZE, totalSize)
                            putExtra(TransferService.EXTRA_REQUEST_ID, requestId)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }

                    "showTransferComplete" -> {
                        val fileName = call.argument<String>("fileName") ?: ""
                        val filePath = call.argument<String>("filePath") ?: ""
                        val fileCount = call.argument<Int>("fileCount") ?: 1
                        val totalSize = call.argument<Number>("totalSize")?.toLong() ?: 0L

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_SHOW_COMPLETE
                            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
                            putExtra(TransferService.EXTRA_FILE_PATH, filePath)
                            putExtra(TransferService.EXTRA_FILE_COUNT, fileCount)
                            putExtra(TransferService.EXTRA_TOTAL_SIZE, totalSize)
                        }
                        startService(intent)
                        result.success(null)
                    }

                    "dismissTransferRequest" -> {
                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_DISMISS_REQUEST
                        }
                        startService(intent)
                        result.success(null)
                    }

                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Share Intent Channel - Get shared files from other apps
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_INTENT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedFiles" -> {
                        val sharedFiles = getSharedFiles()
                        result.success(sharedFiles)
                    }
                    "clearSharedFiles" -> {
                        pendingShareIntent = null
                        result.success(null)
                    }
                    "copyContentUri" -> {
                        val uri = call.argument<String>("uri")
                        val tempDir = call.argument<String>("tempDir")
                        val fileName = call.argument<String>("fileName")
                        if (uri != null && tempDir != null) {
                            val copiedPath = copyContentUriToFile(uri, tempDir, fileName)
                            result.success(copiedPath)
                        } else {
                            result.error("INVALID_ARGUMENTS", "uri and tempDir are required", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // Sound Channel - Play notification sounds
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOUND_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "playNotificationSound" -> {
                        playNotificationSound()
                        result.success(null)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    private fun registerTransferEventReceiver() {
        transferEventReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    "com.syndro.app.TRANSFER_CANCELLED" -> {
                        eventSink?.success(mapOf("event" to "cancelled"))
                    }
                    "com.syndro.app.TRANSFER_ACCEPTED" -> {
                        val requestId = intent.getStringExtra(TransferService.EXTRA_REQUEST_ID)
                        eventSink?.success(mapOf("event" to "accepted", "requestId" to requestId))
                    }
                    "com.syndro.app.TRANSFER_REJECTED" -> {
                        val requestId = intent.getStringExtra(TransferService.EXTRA_REQUEST_ID)
                        eventSink?.success(mapOf("event" to "rejected", "requestId" to requestId))
                    }
                }
            }
        }

        val filter = IntentFilter().apply {
            addAction("com.syndro.app.TRANSFER_CANCELLED")
            addAction("com.syndro.app.TRANSFER_ACCEPTED")
            addAction("com.syndro.app.TRANSFER_REJECTED")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(transferEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(transferEventReceiver, filter)
        }
    }

    private fun unregisterTransferEventReceiver() {
        transferEventReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (e: Exception) {
                // Receiver not registered
            }
        }
        transferEventReceiver = null
    }

    override fun onDestroy() {
        unregisterTransferEventReceiver()
        super.onDestroy()
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
                word.replaceFirstChar { if (it.isLowerCase()) it.titlecase() else it.toString() }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShareIntent(intent)
    }

    private fun handleShareIntent(intent: Intent?) {
        if (intent == null) return

        when (intent.action) {
            Intent.ACTION_SEND -> {
                if (intent.type != null) {
                    pendingShareIntent = intent
                    // Notify Flutter about the share intent
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SHARE_INTENT_CHANNEL)
                            .invokeMethod("onShareIntentReceived", null)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (intent.type != null) {
                    pendingShareIntent = intent
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SHARE_INTENT_CHANNEL)
                            .invokeMethod("onShareIntentReceived", null)
                    }
                }
            }
        }
    }

    private fun getSharedFiles(): List<Map<String, Any?>>? {
        val intent = pendingShareIntent ?: intent
        if (intent == null) return null

        val files = mutableListOf<Map<String, Any?>>()

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                uri?.let {
                    files.add(mapOf(
                        "uri" to it.toString(),
                        "mimeType" to intent.type,
                        "name" to getFileName(it)
                    ))
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<android.net.Uri>(Intent.EXTRA_STREAM)
                uris?.forEach { uri ->
                    files.add(mapOf(
                        "uri" to uri.toString(),
                        "mimeType" to intent.type,
                        "name" to getFileName(uri)
                    ))
                }
            }
        }

        return if (files.isNotEmpty()) files else null
    }

    private fun getFileName(uri: android.net.Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && nameIndex >= 0) {
                    cursor.getString(nameIndex)
                } else {
                    uri.lastPathSegment
                }
            }
        } catch (e: Exception) {
            uri.lastPathSegment
        }
    }

    private fun copyContentUriToFile(contentUri: String, tempDir: String, fileName: String?): String? {
        return try {
            val uri = android.net.Uri.parse(contentUri)
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            
            val name = fileName ?: getFileName(uri) ?: "shared_file"
            val outputFile = java.io.File(tempDir, name)
            
            inputStream.use { input ->
                outputFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            
            outputFile.absolutePath
        } catch (e: Exception) {
            debugPrint("Error copying content URI: $e")
            null
        }
    }

    private fun playNotificationSound() {
        try {
            val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, notification)
            ringtone?.play()
        } catch (e: Exception) {
            debugPrint("Error playing notification sound: $e")
        }
    }
}
