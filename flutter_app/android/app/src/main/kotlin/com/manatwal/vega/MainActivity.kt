package com.manatwal.vega

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private var wifiDirectBridge: WifiDirectBridge? = null
    private var shareSink: EventChannel.EventSink? = null
    private val pendingSharedFiles = mutableListOf<Map<String, Any>>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        extractSharedIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val extracted = extractSharedIntent(intent)
        if (extracted.isNotEmpty()) {
            shareSink?.success(extracted)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = WifiDirectBridge(applicationContext)
        wifiDirectBridge = bridge

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.manatwal.vega/wifi_direct"
        ).setMethodCallHandler(bridge)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.manatwal.vega/wifi_direct_events"
        ).setStreamHandler(bridge)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.manatwal.vega/share_intent"
        ).setMethodCallHandler { call, result ->
            if (call.method == "getPendingSharedFiles") {
                val copy = pendingSharedFiles.toList()
                pendingSharedFiles.clear()
                result.success(copy)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.manatwal.vega/share_intent_events"
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                shareSink = events
            }

            override fun onCancel(arguments: Any?) {
                shareSink = null
            }
        })
    }

    private fun extractSharedIntent(intent: Intent?): List<Map<String, Any>> {
        if (intent == null) return emptyList()
        val uris = mutableListOf<Uri>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    ?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    ?.let { uris.addAll(it) }
            }
        }
        if (uris.isEmpty()) return emptyList()

        val inboxDir = File(cacheDir, "shared_inbox").apply {
            if (!exists()) mkdirs()
        }
        val mapped = mutableListOf<Map<String, Any>>()
        for (uri in uris) {
            try {
                val name = resolveDisplayName(uri)
                val dest = File(inboxDir, "${System.currentTimeMillis()}_$name")
                contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(dest).use { out ->
                        input.copyTo(out, bufferSize = 256 * 1024)
                    }
                }
                if (dest.exists() && dest.length() > 0) {
                    val item = mapOf<String, Any>(
                        "path" to dest.absolutePath,
                        "name" to name,
                        "size" to dest.length()
                    )
                    mapped.add(item)
                }
            } catch (_: Throwable) {
            }
        }
        if (mapped.isNotEmpty()) {
            pendingSharedFiles.addAll(mapped)
        }
        return mapped
    }

    private fun resolveDisplayName(uri: Uri): String {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) {
                        val value = cursor.getString(idx)
                        if (!value.isNullOrBlank()) return value
                    }
                }
            }
        return uri.lastPathSegment?.substringAfterLast('/') ?: "shared_file"
    }

    override fun onDestroy() {
        wifiDirectBridge?.dispose()
        wifiDirectBridge = null
        super.onDestroy()
    }
}
