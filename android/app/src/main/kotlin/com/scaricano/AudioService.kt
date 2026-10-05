package com.scaricano

import android.app.Notification
import android.app.NotificationChannel
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.net.Uri
import android.os.Binder
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.google.android.exoplayer2.ExoPlayer
import com.google.android.exoplayer2.MediaItem
import com.google.android.exoplayer2.Player
import java.io.IOException

/**
 * Foreground service for audio playback with notification controls.
 * Uses ExoPlayer for reliable audio playback and MediaSession for notification controls.
 */
class AudioService : Service(), Player.Listener {
    
    private val binder = LocalBinder()
    private var notificationManager: NotificationManager? = null
    private val CHANNEL_ID = "scariCANO_audio_channel"
    private val NOTIFICATION_ID = 1002
    
    // ExoPlayer for audio playback
    private var exoPlayer: ExoPlayer? = null
    private var mediaSession: MediaSession? = null
    private var currentMediaItem: MediaItem? = null
    private var playbackState: PlaybackState? = null
    
    // Playback state
    private var isPlaying = false
    private var currentPosition = 0L
    private var playbackList = mutableListOf<MediaItem>()
    private var currentIndex = -1
    
    inner class LocalBinder : Binder() {
        fun getService(): AudioService = this@AudioService
    }

    interface AudioListener {
        fun onPlaybackStateChanged(isPlaying: Boolean)
        fun onTrackChanged(mediaItem: MediaItem?)
        fun onPlaybackPositionChanged(position: Long)
        fun onError(error: String)
    }

    private val listeners = mutableListOf<AudioListener>()

    override fun onBind(intent: Intent?): IBinder {
        return binder
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        initializePlayer()
        initializeMediaSession()
        startForeground()
    }

    override fun onDestroy() {
        super.onDestroy()
        exoPlayer?.removeListener(this)
        exoPlayer?.release()
        exoPlayer = null
        mediaSession?.release()
        mediaSession = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Riproduzione audio",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Controlli riproduzione audio"
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun initializePlayer() {
        exoPlayer = ExoPlayer.Builder(this).build().apply {
            addListener(this@AudioService)
            volume = 1.0f
        }
    }

    private fun initializeMediaSession() {
        mediaSession = MediaSession(this, "scariCANO").apply {
            setPlaybackState(
                PlaybackState.Builder()
                    .setState(PlaybackState.STATE_NONE, 0, 1.0f)
                    .setActions(
                        PlaybackState.ACTION_PLAY or
                        PlaybackState.ACTION_PAUSE or
                        PlaybackState.ACTION_SKIP_TO_NEXT or
                        PlaybackState.ACTION_SKIP_TO_PREVIOUS or
                        PlaybackState.ACTION_STOP
                    )
                    .build()
            )
            isActive = true
        }
    }

    private fun startForeground() {
        val notification = createNotification("scariCANO", "Player in esecuzione", false)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotification(title: String, text: String, isPlaying: Boolean): Notification {
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val playPauseText = if (isPlaying) "Pausa" else "Play"
        
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(
                android.R.drawable.ic_media_previous,
                "Precedente",
                createPendingIntent(ACTION_PREVIOUS)
            )
            .addAction(
                playPauseIcon,
                playPauseText,
                createPendingIntent(if (isPlaying) ACTION_PAUSE else ACTION_PLAY)
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "Successivo",
                createPendingIntent(ACTION_NEXT)
            )
            .addAction(
                android.R.drawable.ic_media_stop,
                "Stop",
                createPendingIntent(ACTION_STOP)
            )
            .build()
    }

    private fun createPendingIntent(action: String): PendingIntent {
        val intent = Intent(this, AudioService::class.java).apply {
            this.action = action
        }
        return PendingIntent.getService(
            this, 
            action.hashCode(), 
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> {
                val uriString = intent.getStringExtra(EXTRA_URI)
                val title = intent.getStringExtra(EXTRA_TITLE) ?: ""
                val artist = intent.getStringExtra(EXTRA_ARTIST) ?: ""
                
                if (uriString != null) {
                    playTrack(Uri.parse(uriString), title, artist)
                }
            }
            ACTION_PAUSE -> pause()
            ACTION_STOP -> stop()
            ACTION_NEXT -> next()
            ACTION_PREVIOUS -> previous()
            ACTION_SEEK_TO -> {
                val position = intent.getLongExtra(EXTRA_POSITION, 0L)
                seekTo(position)
            }
        }
        return START_STICKY
    }

    fun playTrack(uri: Uri, title: String, artist: String) {
        try {
            currentMediaItem = MediaItem.fromUri(uri)
            exoPlayer?.setMediaItem(currentMediaItem)
            exoPlayer?.prepare()
            exoPlayer?.play()
            isPlaying = true
            
            updateNotification(title, artist, true)
            notifyPlaybackStateChanged(true)
            notifyTrackChanged(currentMediaItem)
            
        } catch (e: Exception) {
            e.printStackTrace()
            notifyError(e.message ?: "Errore riproduzione")
        }
    }

    fun play() {
        exoPlayer?.play()
        isPlaying = true
        updateNotification(
            currentMediaItem?.mediaMetadata?.title?.toString() ?: "",
            currentMediaItem?.mediaMetadata?.artist?.toString() ?: "",
            true
        )
        notifyPlaybackStateChanged(true)
    }

    fun pause() {
        exoPlayer?.pause()
        isPlaying = false
        updateNotification(
            currentMediaItem?.mediaMetadata?.title?.toString() ?: "",
            currentMediaItem?.mediaMetadata?.artist?.toString() ?: "",
            false
        )
        notifyPlaybackStateChanged(false)
    }

    fun stop() {
        exoPlayer?.stop()
        isPlaying = false
        currentIndex = -1
        updateNotification("scariCANO", "Player fermato", false)
        notifyPlaybackStateChanged(false)
    }

    fun next() {
        // Logic for next track would go here
        // For now, just notify
        notifyTrackChanged(currentMediaItem)
    }

    fun previous() {
        // Logic for previous track would go here
        notifyTrackChanged(currentMediaItem)
    }

    fun seekTo(position: Long) {
        exoPlayer?.seekTo(position)
        currentPosition = position
        notifyPlaybackPositionChanged(position)
    }

    fun getCurrentPosition(): Long {
        return exoPlayer?.currentPosition ?: 0L
    }

    fun getDuration(): Long {
        return exoPlayer?.duration ?: 0L
    }

    fun isCurrentlyPlaying(): Boolean {
        return isPlaying && exoPlayer?.isPlaying == true
    }

    private fun updateNotification(title: String, artist: String, isPlaying: Boolean) {
        val displayText = if (title.isNotEmpty() || artist.isNotEmpty()) "$title - $artist" else "scariCANO"
        val notification = createNotification("scariCANO", displayText, isPlaying)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    private fun notifyPlaybackStateChanged(isPlaying: Boolean) {
        listeners.forEach { listener ->
            listener.onPlaybackStateChanged(isPlaying)
        }
    }

    private fun notifyTrackChanged(mediaItem: MediaItem?) {
        listeners.forEach { listener ->
            listener.onTrackChanged(mediaItem)
        }
    }

    private fun notifyPlaybackPositionChanged(position: Long) {
        listeners.forEach { listener ->
            listener.onPlaybackPositionChanged(position)
        }
    }

    private fun notifyError(error: String) {
        listeners.forEach { listener ->
            listener.onError(error)
        }
    }

    fun addListener(listener: AudioListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: AudioListener) {
        listeners.remove(listener)
    }

    // Player.Listener callbacks
    override fun onPlaybackStateChanged(state: Int) {
        when (state) {
            Player.STATE_READY -> {
                isPlaying = exoPlayer?.isPlaying == true
                notifyPlaybackStateChanged(isPlaying)
            }
            Player.STATE_ENDED -> {
                isPlaying = false
                notifyPlaybackStateChanged(false)
                // Auto-play next track would go here
            }
        }
    }

    override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
        isPlaying = playWhenReady
        notifyPlaybackStateChanged(isPlaying)
    }

    override fun onPositionDiscontinuity(reason: Int) {
        currentPosition = exoPlayer?.currentPosition ?: 0L
        notifyPlaybackPositionChanged(currentPosition)
    }

    companion object {
        const val ACTION_PLAY = "com.scaricano.ACTION_PLAY"
        const val ACTION_PAUSE = "com.scaricano.ACTION_PAUSE"
        const val ACTION_STOP = "com.scaricano.ACTION_STOP"
        const val ACTION_NEXT = "com.scaricano.ACTION_NEXT"
        const val ACTION_PREVIOUS = "com.scaricano.ACTION_PREVIOUS"
        const val ACTION_SEEK_TO = "com.scaricano.ACTION_SEEK_TO"
        
        const val EXTRA_URI = "uri"
        const val EXTRA_TITLE = "title"
        const val EXTRA_ARTIST = "artist"
        const val EXTRA_POSITION = "position"

        fun startAudioService(context: Context) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_PLAY
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun playTrack(context: Context, uri: Uri, title: String, artist: String) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_PLAY
                putExtra(EXTRA_URI, uri.toString())
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_ARTIST, artist)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun pause(context: Context) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_PAUSE
            }
            context.startService(intent)
        }

        fun stop(context: Context) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        fun next(context: Context) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_NEXT
            }
            context.startService(intent)
        }

        fun previous(context: Context) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_PREVIOUS
            }
            context.startService(intent)
        }

        fun seekTo(context: Context, position: Long) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_SEEK_TO
                putExtra(EXTRA_POSITION, position)
            }
            context.startService(intent)
        }
    }
}
