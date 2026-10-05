package com.scaricano

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.documentfile.provider.DocumentFile
import java.io.File
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

/**
 * Foreground service for handling file downloads in the background.
 * Supports HTTP/HTTPS downloads with progress updates and SAF integration.
 */
class DownloadService : Service() {
    
    private val binder = LocalBinder()
    private var notificationManager: NotificationManager? = null
    private val CHANNEL_ID = "scariCANO_download_channel"
    private val NOTIFICATION_ID = 1001
    
    // Download tracking
    private val activeDownloads = mutableMapOf<String, DownloadTask>()
    
    inner class LocalBinder : Binder() {
        fun getService(): DownloadService = this@DownloadService
    }

    data class DownloadTask(
        val id: String,
        val url: String,
        val destinationUri: Uri,
        val fileName: String,
        var totalBytes: Long = 0,
        var downloadedBytes: Long = 0,
        var status: DownloadStatus = DownloadStatus.PENDING,
        var error: String? = null
    )

    enum class DownloadStatus {
        PENDING, RUNNING, PAUSED, COMPLETED, FAILED, CANCELLED
    }

    interface DownloadListener {
        fun onProgress(downloadId: String, bytesDownloaded: Long, totalBytes: Long)
        fun onComplete(downloadId: String, fileUri: Uri)
        fun onError(downloadId: String, error: String)
        fun onCancelled(downloadId: String)
    }

    private val listeners = mutableListOf<DownloadListener>()

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_DOWNLOAD -> {
                val url = intent.getStringExtra(EXTRA_URL)
                val uri = intent.getParcelableExtra<Uri>(EXTRA_DESTINATION)
                val fileName = intent.getStringExtra(EXTRA_FILENAME)
                val downloadId = intent.getStringExtra(EXTRA_DOWNLOAD_ID) ?: System.currentTimeMillis().toString()
                
                if (url != null && uri != null && fileName != null) {
                    startDownload(downloadId, url, uri, fileName)
                }
            }
            ACTION_CANCEL_DOWNLOAD -> {
                val downloadId = intent.getStringExtra(EXTRA_DOWNLOAD_ID)
                downloadId?.let { cancelDownload(it) }
            }
            ACTION_PAUSE_DOWNLOAD -> {
                val downloadId = intent.getStringExtra(EXTRA_DOWNLOAD_ID)
                downloadId?.let { pauseDownload(it) }
            }
            ACTION_RESUME_DOWNLOAD -> {
                val downloadId = intent.getStringExtra(EXTRA_DOWNLOAD_ID)
                downloadId?.let { resumeDownload(it) }
            }
        }
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cancel all active downloads
        activeDownloads.values.forEach { task ->
            if (task.status == DownloadStatus.RUNNING) {
                task.status = DownloadStatus.CANCELLED
            }
        }
        activeDownloads.clear()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Download",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Download in corso"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun startForeground() {
        val notification = createNotification("scariCANO", "Download service in esecuzione", 0)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotification(title: String, text: String, progress: Int): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setProgress(100, progress, progress == 0)
            .setOnlyAlertOnce(true)
            .setOngoing(progress < 100)
            .setAutoCancel(progress == 100)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun addListener(listener: DownloadListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: DownloadListener) {
        listeners.remove(listener)
    }

    fun startDownload(id: String, url: String, destinationUri: Uri, fileName: String) {
        val task = DownloadTask(id, url, destinationUri, fileName)
        activeDownloads[id] = task
        
        // Execute download in a separate thread
        Thread {
            try {
                task.status = DownloadStatus.RUNNING
                updateNotificationForDownload(task)
                
                val safHelper = SafHelper(this)
                
                // Create file in destination directory
                val documentFile = DocumentFile.fromTreeUri(this, destinationUri)
                val newFile = documentFile?.createFile("audio/*", fileName)
                
                if (newFile == null) {
                    task.status = DownloadStatus.FAILED
                    task.error = "Impossibile creare il file"
                    notifyError(task)
                    return@Thread
                }
                
                val fileUri = newFile.uri
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 30000
                connection.readTimeout = 30000
                
                // Support for resuming downloads
                if (task.downloadedBytes > 0) {
                    connection.setRequestProperty("Range", "bytes=${task.downloadedBytes}-")
                }
                
                task.totalBytes = connection.contentLengthLong
                
                val inputStream: InputStream = connection.inputStream
                val outputStream = contentResolver.openOutputStream(fileUri)
                
                if (outputStream == null) {
                    task.status = DownloadStatus.FAILED
                    task.error = "Impossibile scrivere il file"
                    notifyError(task)
                    return@Thread
                }
                
                val buffer = ByteArray(8192)
                var bytesRead: Int
                var currentBytes = task.downloadedBytes
                
                while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                    if (task.status == DownloadStatus.CANCELLED) {
                        outputStream.close()
                        inputStream.close()
                        safHelper.deleteFile(fileUri)
                        return@Thread
                    }
                    
                    if (task.status == DownloadStatus.PAUSED) {
                        task.downloadedBytes = currentBytes
                        outputStream.close()
                        inputStream.close()
                        notifyProgress(task)
                        return@Thread
                    }
                    
                    outputStream.write(buffer, 0, bytesRead)
                    currentBytes += bytesRead
                    task.downloadedBytes = currentBytes
                    notifyProgress(task)
                }
                
                outputStream.close()
                inputStream.close()
                
                if (task.status != DownloadStatus.CANCELLED) {
                    task.status = DownloadStatus.COMPLETED
                    notifyComplete(task, fileUri)
                }
                
            } catch (e: Exception) {
                e.printStackTrace()
                task.status = DownloadStatus.FAILED
                task.error = e.message ?: "Errore sconosciuto"
                notifyError(task)
            }
        }.start()
    }

    fun pauseDownload(downloadId: String) {
        activeDownloads[downloadId]?.let { task ->
            if (task.status == DownloadStatus.RUNNING) {
                task.status = DownloadStatus.PAUSED
            }
        }
    }

    fun resumeDownload(downloadId: String) {
        activeDownloads[downloadId]?.let { task ->
            if (task.status == DownloadStatus.PAUSED) {
                startDownload(task.id, task.url, task.destinationUri, task.fileName)
            }
        }
    }

    fun cancelDownload(downloadId: String) {
        activeDownloads[downloadId]?.let { task ->
            if (task.status == DownloadStatus.RUNNING || task.status == DownloadStatus.PAUSED) {
                task.status = DownloadStatus.CANCELLED
                activeDownloads.remove(downloadId)
                notifyCancelled(downloadId)
            }
        }
    }

    fun getDownloadStatus(downloadId: String): DownloadStatus? {
        return activeDownloads[downloadId]?.status
    }

    fun getDownloadProgress(downloadId: String): Pair<Long, Long>? {
        return activeDownloads[downloadId]?.let { 
            Pair(it.downloadedBytes, it.totalBytes) 
        }
    }

    private fun notifyProgress(task: DownloadTask) {
        val progress = if (task.totalBytes > 0) {
            ((task.downloadedBytes.toDouble() / task.totalBytes.toDouble()) * 100).toInt()
        } else 0
        
        updateNotificationForDownload(task)
        
        listeners.forEach { listener ->
            listener.onProgress(task.id, task.downloadedBytes, task.totalBytes)
        }
    }

    private fun notifyComplete(task: DownloadTask, fileUri: Uri) {
        activeDownloads.remove(task.id)
        updateNotificationForDownload(task, isComplete = true)
        
        listeners.forEach { listener ->
            listener.onComplete(task.id, fileUri)
        }
    }

    private fun notifyError(task: DownloadTask) {
        activeDownloads.remove(task.id)
        
        listeners.forEach { listener ->
            listener.onError(task.id, task.error ?: "Errore sconosciuto")
        }
    }

    private fun notifyCancelled(downloadId: String) {
        listeners.forEach { listener ->
            listener.onCancelled(downloadId)
        }
    }

    private fun updateNotificationForDownload(task: DownloadTask, isComplete: Boolean = false) {
        val progress = if (task.totalBytes > 0 && !isComplete) {
            ((task.downloadedBytes.toDouble() / task.totalBytes.toDouble()) * 100).toInt()
        } else if (isComplete) 100 else 0
        
        val title = if (isComplete) "Download completato" else "Download in corso"
        val text = if (isComplete) task.fileName else "${task.fileName} - ${formatBytes(task.downloadedBytes)}/${formatBytes(task.totalBytes)}"
        
        val notification = createNotification(title, text, progress)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val kb = bytes / 1024
        if (kb < 1024) return "%.2f KB".format(kb)
        val mb = kb / 1024
        if (mb < 1024) return "%.2f MB".format(mb)
        val gb = mb / 1024
        return "%.2f GB".format(gb)
    }

    companion object {
        const val ACTION_START_DOWNLOAD = "com.scaricano.ACTION_START_DOWNLOAD"
        const val ACTION_CANCEL_DOWNLOAD = "com.scaricano.ACTION_CANCEL_DOWNLOAD"
        const val ACTION_PAUSE_DOWNLOAD = "com.scaricano.ACTION_PAUSE_DOWNLOAD"
        const val ACTION_RESUME_DOWNLOAD = "com.scaricano.ACTION_RESUME_DOWNLOAD"
        
        const val EXTRA_DOWNLOAD_ID = "download_id"
        const val EXTRA_URL = "url"
        const val EXTRA_DESTINATION = "destination_uri"
        const val EXTRA_FILENAME = "file_name"

        fun startDownloadService(context: Context, downloadId: String, url: String, destinationUri: Uri, fileName: String) {
            val intent = Intent(context, DownloadService::class.java).apply {
                action = ACTION_START_DOWNLOAD
                putExtra(EXTRA_DOWNLOAD_ID, downloadId)
                putExtra(EXTRA_URL, url)
                putExtra(EXTRA_DESTINATION, destinationUri)
                putExtra(EXTRA_FILENAME, fileName)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun cancelDownloadService(context: Context, downloadId: String) {
            val intent = Intent(context, DownloadService::class.java).apply {
                action = ACTION_CANCEL_DOWNLOAD
                putExtra(EXTRA_DOWNLOAD_ID, downloadId)
            }
            context.startService(intent)
        }

        fun pauseDownloadService(context: Context, downloadId: String) {
            val intent = Intent(context, DownloadService::class.java).apply {
                action = ACTION_PAUSE_DOWNLOAD
                putExtra(EXTRA_DOWNLOAD_ID, downloadId)
            }
            context.startService(intent)
        }

        fun resumeDownloadService(context: Context, downloadId: String) {
            val intent = Intent(context, DownloadService::class.java).apply {
                action = ACTION_RESUME_DOWNLOAD
                putExtra(EXTRA_DOWNLOAD_ID, downloadId)
            }
            context.startService(intent)
        }
    }
}
