package com.scaricano

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
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
        mediaSession = MediaSession(this, "scariCANO MediaSession").apply {
            setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
            setPlaybackState(PlaybackState.Builder()
                .setState(PlaybackState.STATE_NONE, 0, 1.0f)
                .setActions(PlaybackState.ACTION_PLAY or PlaybackState.ACTION_PAUSE or 
                        PlaybackState.ACTION_SKIP_TO_NEXT or PlaybackState.ACTION_SKIP_TO_PREVIOUS)
                .build())
            
            setCallback(object : MediaSession.Callback() {
                override fun onPlay() {
                    play()
                }
                
                override fun onPause() {
                    pause()
                }
                
                override fun onSkipToNext() {
                    next()
                }
                
                override fun onSkipToPrevious() {
                    previous()
                }
                
                override fun onStop() {
                    stop()
                }
            })
        }
    }

    private fun startForeground() {
        val notification = createNotification("scariCANO", "Nessun brano in riproduzione", 0)
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun createNotification(title: String, text: String, progress: Int): Notification {
        val playPauseIcon = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        
        val playPauseIntent = Intent(this, AudioService::class.java).apply {
            action = if (isPlaying) ACTION_PAUSE else ACTION_PLAY
        }
        val playPausePendingIntent = PendingIntent.getService(
            this, 0, playPauseIntent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val nextIntent = Intent(this, AudioService::class.java).apply {
            action = ACTION_NEXT
        }
        val nextPendingIntent = PendingIntent.getService(
            this, 1, nextIntent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val prevIntent = Intent(this, AudioService::class.java).apply {
            action = ACTION_PREVIOUS
        }
        val prevPendingIntent = PendingIntent.getService(
            this, 2, prevIntent, 
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOnlyAlertOnce(true)
            .setOngoing(true)
            .setStyle(androidx.media.app.NotificationCompat.MediaStyle()
                .setMediaSession(mediaSession?.sessionToken)
                .setShowActionsInCompactView(0, 1, 2))
            .addAction(android.R.drawable.ic_media_previous, "Precedente", prevPendingIntent)
            .addAction(playPauseIcon, if (isPlaying) "Pausa" else "Play", playPausePendingIntent)
            .addAction(android.R.drawable.ic_media_next, "Successivo", nextPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    fun addListener(listener: AudioListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: AudioListener) {
        listeners.remove(listener)
    }

    fun setPlaybackList(items: List<MediaItem>) {
        playbackList.clear()
        playbackList.addAll(items)
    }

    fun playFromList(index: Int) {
        if (index >= 0 && index < playbackList.size) {
            currentIndex = index
            playItem(playbackList[index])
        }
    }

    fun playItem(mediaItem: MediaItem) {
        currentMediaItem = mediaItem
        currentIndex = playbackList.indexOf(mediaItem)
        
        exoPlayer?.setMediaItem(mediaItem)
        exoPlayer?.prepare()
        exoPlayer?.playWhenReady = true
    }

    fun play() {
        exoPlayer?.playWhenReady = true
    }

    fun pause() {
        exoPlayer?.playWhenReady = false
    }

    fun stop() {
        exoPlayer?.stop()
        exoPlayer?.clearMediaItems()
    }

    fun next() {
        if (playbackList.isNotEmpty() && currentIndex < playbackList.size - 1) {
            currentIndex++
            playItem(playbackList[currentIndex])
        }
    }

    fun previous() {
        if (playbackList.isNotEmpty() && currentIndex > 0) {
            currentIndex--
            playItem(playbackList[currentIndex])
        }
    }

    fun seekTo(position: Long) {
        exoPlayer?.seekTo(position)
    }

    fun getCurrentPosition(): Long {
        return exoPlayer?.currentPosition ?: 0L
    }

    fun getDuration(): Long {
        return exoPlayer?.duration ?: 0L
    }

    fun isPlaying(): Boolean {
        return exoPlayer?.isPlaying ?: false
    }

    fun getCurrentMediaItem(): MediaItem? {
        return currentMediaItem
    }

    fun getCurrentIndex(): Int {
        return currentIndex
    }

    fun setVolume(volume: Float) {
        exoPlayer?.volume = volume.coerceIn(0f, 1f)
    }

    fun getVolume(): Float {
        return exoPlayer?.volume ?: 1f
    }

    fun setPlaybackSpeed(speed: Float) {
        exoPlayer?.setPlaybackSpeed(speed)
    }

    override fun onPlaybackStateChanged(state: Int) {
        when (state) {
            Player.STATE_READY -> {
                isPlaying = exoPlayer?.isPlaying ?: false
                notifyPlaybackStateChanged()
                updateNotification()
            }
            Player.STATE_ENDED -> {
                // Auto-play next track
                next()
            }
            Player.STATE_IDLE -> {
                isPlaying = false
                notifyPlaybackStateChanged()
            }
        }
    }

    override fun onPositionDiscontinuity(reason: Int) {
        // Handle position jumps
    }

    override fun onIsPlayingChanged(isPlaying: Boolean) {
        this.isPlaying = isPlaying
        notifyPlaybackStateChanged()
        updateNotification()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAY -> play()
            ACTION_PAUSE -> pause()
            ACTION_NEXT -> next()
            ACTION_PREVIOUS -> previous()
            ACTION_STOP -> stop()
        }
        return START_STICKY
    }

    private fun notifyPlaybackStateChanged() {
        listeners.forEach { listener ->
            listener.onPlaybackStateChanged(isPlaying)
        }
    }

    private fun notifyTrackChanged() {
        listeners.forEach { listener ->
            listener.onTrackChanged(currentMediaItem)
        }
    }

    private fun notifyPositionChanged() {
        listeners.forEach { listener ->
            listener.onPlaybackPositionChanged(currentPosition)
        }
    }

    private fun updateNotification() {
        val title = currentMediaItem?.mediaMetadata?.title ?: "scariCANO"
        val text = currentMediaItem?.mediaMetadata?.artist ?: "Nessun brano in riproduzione"
        val notification = createNotification(title, text, 0)
        notificationManager?.notify(NOTIFICATION_ID, notification)
    }

    companion object {
        const val ACTION_PLAY = "com.scaricano.ACTION_PLAY"
        const val ACTION_PAUSE = "com.scaricano.ACTION_PAUSE"
        const val ACTION_NEXT = "com.scaricano.ACTION_NEXT"
        const val ACTION_PREVIOUS = "com.scaricano.ACTION_PREVIOUS"
        const val ACTION_STOP = "com.scaricano.ACTION_STOP"
        
        fun startAudioService(context: Context) {
            val intent = Intent(context, AudioService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun playTrack(context: Context, uri: Uri, title: String, artist: String) {
            val intent = Intent(context, AudioService::class.java).apply {
                action = ACTION_PLAY
                putExtra("uri", uri.toString())
                putExtra("title", title)
                putExtra("artist", artist)
            }
            context.startService(intent)
        }
    }
}
