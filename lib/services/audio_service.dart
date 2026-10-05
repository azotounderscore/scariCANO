import 'dart:async';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import '../models/song.dart';
import '../models/playlist.dart';

/// Service for audio playback
/// Handles playing, pausing, seeking, and queue management
class ScariCANOAudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<QueueItem> _queue = [];
  int _currentIndex = -1;
  
  // Playback state
  bool _isPlaying = false;
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.none;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  
  // Stream controllers
  final StreamController<Song?> _currentSongController = StreamController.broadcast();
  final StreamController<bool> _playbackStateController = StreamController.broadcast();
  final StreamController<Duration> _positionController = StreamController.broadcast();
  final StreamController<Duration> _durationController = StreamController.broadcast();
  final StreamController<QueueItem> _queueChangedController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  
  /// Stream for current song changes
  Stream<Song?> get onCurrentSongChanged => _currentSongController.stream;
  
  /// Stream for playback state changes
  Stream<bool> get onPlaybackStateChanged => _playbackStateController.stream;
  
  /// Stream for position changes
  Stream<Duration> get onPositionChanged => _positionController.stream;
  
  /// Stream for duration changes
  Stream<Duration> get onDurationChanged => _durationController.stream;
  
  /// Stream for queue changes
  Stream<QueueItem> get onQueueChanged => _queueChangedController.stream;
  
  /// Stream for errors
  Stream<String> get onError => _errorController.stream;

  /// Private constructor
  ScariCANOAudioService._();
  
  /// Singleton instance
  static final ScariCANOAudioService instance = ScariCANOAudioService._();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // Configure audio session
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      
      // Set up audio player
      _audioPlayer.playbackEventStream.listen((event) {},
        onError: (e) => _errorController.add('Errore audio: ${e.toString()}'));
      
      // Set up position stream
      _audioPlayer.positionStream.listen((position) {
        _positionController.add(position);
      });
      
      // Set up duration stream
      _audioPlayer.durationStream.listen((duration) {
        _durationController.add(duration);
      });
      
      // Set up completion listener
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _handlePlaybackCompleted();
        }
      });
      
      // Set up error listener
      _audioPlayer.playerStateStream.listen((state) {
        if (state.error != null) {
          _errorController.add('Errore riproduzione: ${state.error!.message}');
        }
      });
      
      _isPlaying = false;
      _playbackStateController.add(_isPlaying);
      
    } catch (e) {
      _errorController.add('Errore nell\'inizializzazione audio: ${e.toString()}');
      rethrow;
    }
  }

  /// Get current song
  Song? get currentSong {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return null;
    return _queue[_currentIndex].song;
  }

  /// Get current queue
  List<QueueItem> get queue => _queue.toList();

  /// Get current index
  int get currentIndex => _currentIndex;

  /// Get playback state
  bool get isPlaying => _isPlaying;

  /// Get shuffle state
  bool get isShuffled => _isShuffled;

  /// Get repeat mode
  RepeatMode get repeatMode => _repeatMode;

  /// Get volume
  double get volume => _volume;

  /// Get playback speed
  double get playbackSpeed => _playbackSpeed;

  /// Get current position
  Future<Duration> getCurrentPosition() async {
    return await _audioPlayer.position;
  }

  /// Get current duration
  Future<Duration> getCurrentDuration() async {
    return await _audioPlayer.duration ?? Duration.zero;
  }

  /// Play a song
  Future<void> playSong(Song song) async {
    try {
      // Create a new queue with just this song
      _queue.clear();
      _queue.add(QueueItem.fromSong(song, index: 0));
      _currentIndex = 0;
      
      await _playCurrentSong();
    } catch (e) {
      _errorController.add('Errore nella riproduzione: ${e.toString()}');
      rethrow;
    }
  }

  /// Play a playlist
  Future<void> playPlaylist(Playlist playlist, List<Song> songs) async {
    try {
      _queue.clear();
      
      for (final songId in playlist.songIds) {
        final song = songs.firstWhere((s) => s.id == songId);
        _queue.add(QueueItem.fromSong(song, index: _queue.length));
      }
      
      _currentIndex = 0;
      await _playCurrentSong();
    } catch (e) {
      _errorController.add('Errore nella riproduzione playlist: ${e.toString()}');
      rethrow;
    }
  }

  /// Play from queue by index
  Future<void> playFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    
    _currentIndex = index;
    await _playCurrentSong();
  }

  /// Add song to queue
  Future<void> addToQueue(Song song) async {
    _queue.add(QueueItem.fromSong(song, index: _queue.length));
    _queueChangedController.add(_queue.last);
  }

  /// Add multiple songs to queue
  Future<void> addToQueueMultiple(List<Song> songs) async {
    for (final song in songs) {
      _queue.add(QueueItem.fromSong(song, index: _queue.length));
    }
    _queueChangedController.add(_queue.last);
  }

  /// Remove song from queue
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _queue.length) return;
    
    _queue.removeAt(index);
    
    // Adjust current index if needed
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    
    if (_currentIndex == index) {
      // If we removed the current song, play the next one
      if (_queue.isNotEmpty) {
        await _playCurrentSong();
      } else {
        await stop();
      }
    }
    
    _queueChangedController.add(QueueItem.fromSong(Song(id: '', title: '', artist: '', uri: '')));
  }

  /// Clear queue
  Future<void> clearQueue() async {
    _queue.clear();
    _currentIndex = -1;
    await stop();
    _queueChangedController.add(QueueItem.fromSong(Song(id: '', title: '', artist: '', uri: '')));
  }

  /// Play current song
  Future<void> _playCurrentSong() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) {
      await stop();
      return;
    }
    
    final queueItem = _queue[_currentIndex];
    final song = queueItem.song;
    
    try {
      // Convert SAF URI to file URI for playback
      // Note: This is a simplified approach. In a real implementation,
      // we would need to handle SAF URIs properly using ExoPlayer
      final uri = song.uri;
      
      // For YouTube URLs, we would need to extract the audio stream URL
      // This is handled separately in the YouTubeService
      
      // For now, we'll use the URI directly (works for local files)
      await _audioPlayer.setUrl(uri);
      await _audioPlayer.play();
      
      _isPlaying = true;
      _currentSongController.add(song);
      _playbackStateController.add(_isPlaying);
      
    } catch (e) {
      _errorController.add('Errore nella riproduzione: ${e.toString()}');
      rethrow;
    }
  }

  /// Handle playback completion
  Future<void> _handlePlaybackCompleted() async {
    if (_repeatMode == RepeatMode.one) {
      // Replay current song
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
    } else if (_repeatMode == RepeatMode.all || _queue.length > 1) {
      // Play next song
      await next();
    } else {
      // Stop playback
      await stop();
    }
  }

  /// Play
  Future<void> play() async {
    try {
      if (_currentIndex < 0 || _currentIndex >= _queue.length) {
        if (_queue.isNotEmpty) {
          _currentIndex = 0;
          await _playCurrentSong();
        }
      } else {
        await _audioPlayer.play();
      }
      
      _isPlaying = true;
      _playbackStateController.add(_isPlaying);
    } catch (e) {
      _errorController.add('Errore nel play: ${e.toString()}');
      rethrow;
    }
  }

  /// Pause
  Future<void> pause() async {
    try {
      await _audioPlayer.pause();
      _isPlaying = false;
      _playbackStateController.add(_isPlaying);
    } catch (e) {
      _errorController.add('Errore nel pause: ${e.toString()}');
      rethrow;
    }
  }

  /// Stop
  Future<void> stop() async {
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
      _playbackStateController.add(_isPlaying);
      _currentSongController.add(null);
    } catch (e) {
      _errorController.add('Errore nello stop: ${e.toString()}');
      rethrow;
    }
  }

  /// Next song
  Future<void> next() async {
    if (_queue.isEmpty) return;
    
    try {
      if (_isShuffled) {
        // Random selection
        _currentIndex = (_currentIndex + 1) % _queue.length;
      } else {
        // Sequential
        if (_currentIndex < _queue.length - 1) {
          _currentIndex++;
        } else if (_repeatMode == RepeatMode.all) {
          _currentIndex = 0;
        } else {
          // No next song, stop
          await stop();
          return;
        }
      }
      
      await _playCurrentSong();
    } catch (e) {
      _errorController.add('Errore nel next: ${e.toString()}');
      rethrow;
    }
  }

  /// Previous song
  Future<void> previous() async {
    if (_queue.isEmpty) return;
    
    try {
      if (_isShuffled) {
        // Random selection
        _currentIndex = (_currentIndex - 1 + _queue.length) % _queue.length;
      } else {
        // Sequential
        if (_currentIndex > 0) {
          _currentIndex--;
        } else if (_repeatMode == RepeatMode.all) {
          _currentIndex = _queue.length - 1;
        } else {
          // No previous song, stop
          await stop();
          return;
        }
      }
      
      await _playCurrentSong();
    } catch (e) {
      _errorController.add('Errore nel previous: ${e.toString()}');
      rethrow;
    }
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      _errorController.add('Errore nel seek: ${e.toString()}');
      rethrow;
    }
  }

  /// Seek by milliseconds
  Future<void> seekToMillis(int millis) async {
    await seekTo(Duration(milliseconds: millis));
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    _isShuffled = !_isShuffled;
    // Shuffle the queue if enabling shuffle
    if (_isShuffled) {
      _queue.shuffle();
    }
  }

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode) async {
    _repeatMode = mode;
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    _volume = volume.coerceIn(0.0, 1.0);
    await _audioPlayer.setVolume(_volume);
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed.coerceIn(0.5, 2.0);
    await _audioPlayer.setSpeed(_playbackSpeed);
  }

  /// Dispose the service
  Future<void> dispose() async {
    _currentSongController.close();
    _playbackStateController.close();
    _positionController.close();
    _durationController.close();
    _queueChangedController.close();
    _errorController.close();
    await _audioPlayer.dispose();
  }
}
