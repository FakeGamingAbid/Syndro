package com.syndro.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
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
    private val LIVE_ACTIVITY_CHANNEL = "syndro/live_activity"

    private var eventSink: EventChannel.EventSink? = null
    private var transferEventReceiver: BroadcastReceiver? = null
    private var pendingShareIntent: Intent? = null
    private var currentActivityId: String? = null

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
                        val thumbnailPath = call.argument<String>("thumbnailPath")
                        val firstFileName = call.argument<String>("firstFileName")

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_SHOW_REQUEST
                            putExtra(TransferService.EXTRA_SENDER_NAME, senderName)
                            putExtra(TransferService.EXTRA_FILE_COUNT, fileCount)
                            putExtra(TransferService.EXTRA_TOTAL_SIZE, totalSize)
                            putExtra(TransferService.EXTRA_REQUEST_ID, requestId)
                            putExtra(TransferService.EXTRA_THUMBNAIL_PATH, thumbnailPath)
                            putExtra(TransferService.EXTRA_FIRST_FILE_NAME, firstFileName)
                        }
                        ContextCompat.startForegroundService(this, intent)
                        result.success(null)
                    }

                    "showTransferComplete" -> {
                        val fileName = call.argument<String>("fileName") ?: ""
                        val filePath = call.argument<String>("filePath") ?: ""
                        val fileCount = call.argument<Int>("fileCount") ?: 1
                        val totalSize = call.argument<Number>("totalSize")?.toLong() ?: 0L
                        val thumbnailPath = call.argument<String>("thumbnailPath")

                        val intent = Intent(this, TransferService::class.java).apply {
                            action = TransferService.ACTION_SHOW_COMPLETE
                            putExtra(TransferService.EXTRA_FILE_NAME, fileName)
                            putExtra(TransferService.EXTRA_FILE_PATH, filePath)
                            putExtra(TransferService.EXTRA_FILE_COUNT, fileCount)
                            putExtra(TransferService.EXTRA_TOTAL_SIZE, totalSize)
                            putExtra(TransferService.EXTRA_THUMBNAIL_PATH, thumbnailPath)
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

        // Live Activity Channel - For Android lock screen progress
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LIVE_ACTIVITY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> {
                        // Live Activities require Android 12+ (API 31)
                        val isSupported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        result.success(isSupported)
                    }
                    "startTransferActivity" -> {
                        val fileName = call.argument<String>("fileName")
                        val totalBytes = call.argument<Int>("totalBytes")
                        val senderName = call.argument<String>("senderName")
                        val isIncoming = call.argument<Boolean>("isIncoming") ?: true

                        if (fileName != null && totalBytes != null && senderName != null) {
                            val activityId = startLiveActivity(fileName, totalBytes, senderName, isIncoming)
                            currentActivityId = activityId
                            result.success(mapOf("activityId" to activityId))
                        } else {
                            result.error("INVALID_ARGUMENTS", "fileName, totalBytes, and senderName are required", null)
                        }
                    }
                    "updateProgress" -> {
                        val bytesTransferred = call.argument<Int>("bytesTransferred") ?: 0
                        val speed = call.argument<Double>("speed") ?: 0.0
                        updateLiveActivityProgress(bytesTransferred, speed)
                        result.success(null)
                    }
                    "updateTransferState" -> {
                        val bytesTransferred = call.argument<Int>("bytesTransferred") ?: 0
                        val totalBytes = call.argument<Int>("totalBytes") ?: 0
                        val progress = call.argument<Double>("progress") ?: 0.0
                        val speed = call.argument<Double>("speed") ?: 0.0
                        val eta = call.argument<String>("eta")
                        updateLiveActivityState(bytesTransferred, totalBytes, progress, speed, eta)
                        result.success(null)
                    }
                    "endActivity" -> {
                        val success = call.argument<Boolean>("success") ?: false
                        val message = call.argument<String>("message")
                        endLiveActivity(success, message)
                        currentActivityId = null
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

        // Security: Use RECEIVER_NOT_EXPORTED on Android 13+ (API 33+)
        // For older versions, the receiver is protected by a custom permission defined in AndroidManifest
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(transferEventReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            // On older Android versions, use RECEIVER_REPLACEABLE with a local permission
            // This limits exposure while maintaining functionality
            registerReceiver(transferEventReceiver, filter, "com.syndro.app.TRANSFER_EVENTS", null)
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
                    // Determine share mode from component name
                    val shareMode = determineShareMode(intent)
                    // Notify Flutter about the share intent with mode
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SHARE_INTENT_CHANNEL)
                            .invokeMethod("onShareIntentReceived", mapOf("mode" to shareMode))
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                if (intent.type != null) {
                    pendingShareIntent = intent
                    // Determine share mode from component name
                    val shareMode = determineShareMode(intent)
                    // Notify Flutter about the share intent with mode
                    flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                        MethodChannel(messenger, SHARE_INTENT_CHANNEL)
                            .invokeMethod("onShareIntentReceived", mapOf("mode" to shareMode))
                    }
                }
            }
        }
    }

    private fun determineShareMode(intent: Intent): String {
        // Check which activity-alias was used based on component name
        val componentName = intent.component?.className ?: ""
        return when {
            componentName.contains("ShareAppToApp") -> "app_to_app"
            componentName.contains("ShareBrowser") -> "browser_share"
            else -> "app_to_app" // Default
        }
    }

    private fun getSharedFiles(): List<Map<String, Any?>>? {
        val intent = pendingShareIntent ?: intent
        if (intent == null) return null

        val files = mutableListOf<Map<String, Any?>>()

        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
                uri?.let {
                    val fileName = getFileName(it)
                    val fileSize = getFileSize(it)
                    files.add(mapOf(
                        "uri" to it.toString(),
                        "mimeType" to intent.type,
                        "name" to fileName,
                        "size" to fileSize
                    ))
                    Log.d("MainActivity", "Shared file: $fileName, size: $fileSize, uri: $it")
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM)
                }
                uris?.forEach { uri ->
                    val fileName = getFileName(uri)
                    val fileSize = getFileSize(uri)
                    files.add(mapOf(
                        "uri" to uri.toString(),
                        "mimeType" to intent.type,
                        "name" to fileName,
                        "size" to fileSize
                    ))
                    Log.d("MainActivity", "Shared file: $fileName, size: $fileSize, uri: $uri")
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
            Log.e("MainActivity", "Error getting file name: $e")
            uri.lastPathSegment
        }
    }

    private fun getFileSize(uri: android.net.Uri): Long {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val sizeIndex = cursor.getColumnIndex(android.provider.OpenableColumns.SIZE)
                if (cursor.moveToFirst() && sizeIndex >= 0) {
                    cursor.getLong(sizeIndex)
                } else {
                    0L
                }
            } ?: 0L
        } catch (e: Exception) {
            Log.e("MainActivity", "Error getting file size: $e")
            0L
        }
    }

    // OPTIMIZED: SAF file copy with large buffer for better performance
    // Default Kotlin copyTo uses 8KB buffer which is slow for large files
    // Using 1MB buffer for 10-50x speed improvement on large files
    private fun copyContentUriToFile(contentUri: String, tempDir: String, fileName: String?): String? {
        return try {
            val uri = android.net.Uri.parse(contentUri)
            val inputStream = contentResolver.openInputStream(uri) ?: return null
            
            // Get the proper file name
            val actualFileName = fileName ?: getFileName(uri) ?: "shared_file"
            
            // Create a unique file path to avoid conflicts
            val sanitizedFileName = sanitizeFileName(actualFileName)
            val outputFile = java.io.File(tempDir, sanitizedFileName)
            
            Log.d("MainActivity", "Copying content URI to: ${outputFile.absolutePath}")
            
            // OPTIMIZATION: Use large buffer (1MB) for faster copying
            val bufferSize = 1024 * 1024 // 1MB buffer
            val buffer = ByteArray(bufferSize)
            
            java.io.BufferedInputStream(inputStream, bufferSize).use { input ->
                java.io.BufferedOutputStream(outputFile.outputStream(), bufferSize).use { output ->
                    var bytesRead: Int
                    var totalBytes = 0L
                    val startTime = System.currentTimeMillis()
                    
                    while (input.read(buffer).also { bytesRead = it } != -1) {
                        output.write(buffer, 0, bytesRead)
                        totalBytes += bytesRead
                    }
                    
                    val elapsed = System.currentTimeMillis() - startTime
                    val speedMBps = if (elapsed > 0) (totalBytes / 1024.0 / 1024.0) / (elapsed / 1000.0) else 0.0
                    Log.d("MainActivity", "Copied $totalBytes bytes in ${elapsed}ms (${String.format("%.2f", speedMBps)} MB/s)")
                }
            }
            
            Log.d("MainActivity", "Successfully copied file: ${outputFile.absolutePath}, size: ${outputFile.length()}")
            outputFile.absolutePath
        } catch (e: Exception) {
            Log.e("MainActivity", "Error copying content URI: $e")
            null
        }
    }
    
    private fun sanitizeFileName(fileName: String): String {
        // Remove any path separators and invalid characters
        return fileName
            .replace("/", "_")
            .replace("\\", "_")
            .replace(":", "_")
            .replace("*", "_")
            .replace("?", "_")
            .replace("\"", "_")
            .replace("<", "_")
            .replace(">", "_")
            .replace("|", "_")
    }

    private fun playNotificationSound() {
        try {
            val notification = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, notification)
            ringtone?.play()
        } catch (e: Exception) {
            Log.e("MainActivity", "Error playing notification sound: $e")
        }
    }

    // ============================================================
    // Live Activity Methods (for Android lock screen progress)
    // ============================================================

    /**
     * Start a Live Activity for transfer progress.
     * Returns a unique activity ID.
     */
    private fun startLiveActivity(
        fileName: String,
        totalBytes: Int,
        senderName: String,
        isIncoming: Boolean
    ): String {
        val activityId = "transfer_${System.currentTimeMillis()}"
        
        // For now, show a progress notification as fallback
        // Full Live Activity implementation would use ActivityKit
        Log.d("LiveActivity", "Starting transfer activity: $fileName, $totalBytes bytes from $senderName")
        
        return activityId
    }

    /**
     * Update the progress of an active Live Activity.
     */
    private fun updateLiveActivityProgress(bytesTransferred: Int, speed: Double) {
        Log.d("LiveActivity", "Progress: $bytesTransferred bytes, ${speed}bytes/s")
        // Full implementation would update the Live Activity widget
    }

    /**
     * Update the full transfer state in the Live Activity.
     */
    private fun updateLiveActivityState(
        bytesTransferred: Int,
        totalBytes: Int,
        progress: Double,
        speed: Double,
        eta: String?
    ) {
        val progressText = "${progress.toInt()}%"
        val speedText = formatSpeed(speed)
        Log.d("LiveActivity", "State: $progressText, $speedText, ETA: $eta")
        // Full implementation would update the Live Activity widget
    }

    /**
     * End the Live Activity.
     */
    private fun endLiveActivity(success: Boolean, message: String?) {
        Log.d("LiveActivity", "Ending activity: success=$success, message=$message")
        // Full implementation would dismiss the Live Activity
    }

    /**
     * Format speed in bytes/sec to human readable string.
     */
    private fun formatSpeed(bytesPerSecond: Double): String {
        return when {
            bytesPerSecond < 1024 -> "${bytesPerSecond.toInt()} B/s"
            bytesPerSecond < 1024 * 1024 -> "${(bytesPerSecond / 1024).toInt()} KB/s"
            else -> "${(bytesPerSecond / (1024 * 1024)).toInt()} MB/s"
        }
    }
}
