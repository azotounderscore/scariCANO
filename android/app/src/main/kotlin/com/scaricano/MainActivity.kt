package com.scaricano

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.DocumentsContract
import androidx.annotation.NonNull
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.scaricano/saf"
    private val CHANNEL_DOWNLOAD = "com.scaricano/download"
    private val CHANNEL_AUDIO = "com.scaricano/audio"
    
    private var safHelper: SafHelper? = null
    private var downloadServiceIntent: Intent? = null
    private var audioServiceIntent: Intent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        safHelper = SafHelper(this)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // SAF Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openDirectoryPicker" -> {
                    safHelper?.openDirectoryPicker(this)
                    result.success(null)
                }
                "getAvailableSpace" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val space = if (uri != null) safHelper?.getAvailableSpace(uri) else -1L
                    result.success(space)
                }
                "isUriValid" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val isValid = if (uri != null) safHelper?.isUriValid(uri) else false
                    result.success(isValid)
                }
                "getDisplayName" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val displayName = if (uri != null) safHelper?.getDisplayName(uri) else ""
                    result.success(displayName)
                }
                "takePersistablePermission" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val success = if (uri != null) safHelper?.takePersistablePermission(uri) else false
                    result.success(success)
                }
                "listFiles" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val files = if (uri != null) safHelper?.listFiles(uri) else emptyList<Uri>()
                    val fileStrings = files.map { it.toString() }
                    result.success(fileStrings)
                }
                "isDirectory" -> {
                    val uriString = call.argument<String>("uri")
                    val uri = if (uriString != null) Uri.parse(uriString) else null
                    val isDir = if (uri != null) safHelper?.isDirectory(uri) else false
                    result.success(isDir)
                }
                else -> result.notImplemented()
            }
        }
        
        // Download Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_DOWNLOAD).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    val url = call.argument<String>("url")
                    val uriString = call.argument<String>("destinationUri")
                    val fileName = call.argument<String>("fileName")
                    
                    if (downloadId != null && url != null && uriString != null && fileName != null) {
                        val destinationUri = Uri.parse(uriString)
                        DownloadService.startDownloadService(
                            this,
                            downloadId,
                            url,
                            destinationUri,
                            fileName
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing required arguments", null)
                    }
                }
                "cancelDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId != null) {
                        DownloadService.cancelDownloadService(this, downloadId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    }
                }
                "pauseDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId != null) {
                        DownloadService.pauseDownloadService(this, downloadId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    }
                }
                "resumeDownload" -> {
                    val downloadId = call.argument<String>("downloadId")
                    if (downloadId != null) {
                        DownloadService.resumeDownloadService(this, downloadId)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing downloadId", null)
                    }
                }
                "getDownloadStatus" -> {
                    // This would require binding to the service
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Audio Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_AUDIO).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    AudioService.startAudioService(this)
                    result.success(true)
                }
                "play" -> {
                    val uriString = call.argument<String>("uri")
                    val title = call.argument<String>("title")
                    val artist = call.argument<String>("artist")
                    
                    if (uriString != null) {
                        AudioService.playTrack(this, Uri.parse(uriString), title ?: "", artist ?: "")
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "Missing uri", null)
                    }
                }
                "pause" -> {
                    // Would need to bind to service
                    result.success(null)
                }
                "next" -> {
                    // Would need to bind to service
                    result.success(null)
                }
                "previous" -> {
                    // Would need to bind to service
                    result.success(null)
                }
                "seekTo" -> {
                    val position = call.argument<Long>("position")
                    // Would need to bind to service
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == SafHelper.REQUEST_CODE_OPEN_DIRECTORY) {
            if (resultCode == RESULT_OK && data != null) {
                val uri = data.data
                uri?.let { 
                    // Take persistable permission
                    safHelper?.takePersistablePermission(it)
                    
                    // Send URI back to Flutter
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                        "onDirectorySelected",
                        mapOf("uri" to uri.toString())
                    )
                }
            }
        } else if (requestCode == SafHelper.REQUEST_CODE_CREATE_FILE) {
            if (resultCode == RESULT_OK && data != null) {
                val uri = data.data
                uri?.let { 
                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).invokeMethod(
                        "onFileCreated",
                        mapOf("uri" to uri.toString())
                    )
                }
            }
        }
    }

    override fun onDestroy() {
        safHelper = null
        super.onDestroy()
    }
}
