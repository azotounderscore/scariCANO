import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../services/audio_service.dart';

/// Player state provider
final playerProvider = StateNotifierProvider<PlayerNotifier, PlayerState>((ref) {
  return PlayerNotifier();
});

/// Player state
@immutable
class PlayerState {
  final Song? currentSong;
  final List<QueueItem> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final double volume;
  final double playbackSpeed;
  final Duration position;
  final Duration duration;

  const PlayerState({
    this.currentSong,
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.none,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  PlayerState copyWith({
    Song? currentSong,
    List<QueueItem>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? isShuffled,
    RepeatMode? repeatMode,
    double? volume,
    double? playbackSpeed,
    Duration? position,
    Duration? duration,
  }) {
    return PlayerState(
      currentSong: currentSong ?? this.currentSong,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      isShuffled: isShuffled ?? this.isShuffled,
      repeatMode: repeatMode ?? this.repeatMode,
      volume: volume ?? this.volume,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }

  bool get hasQueue => queue.isNotEmpty;
  bool get hasCurrentSong => currentSong != null;
  bool get canPlay => hasCurrentSong && !isPlaying;
  bool get canPause => hasCurrentSong && isPlaying;
  bool get canNext => hasQueue && (currentIndex < queue.length - 1 || repeatMode == RepeatMode.all);
  bool get canPrevious => hasQueue && (currentIndex > 0 || repeatMode == RepeatMode.all);
}

/// Player notifier
class PlayerNotifier extends StateNotifier<PlayerState> {
  final ScariCANOAudioService _audioService = ScariCANOAudioService.instance;
  
  PlayerNotifier() : super(const PlayerState()) {
    _initialize();
  }

  /// Initialize the notifier
  Future<void> _initialize() async {
    await _audioService.initialize();
    
    // Listen to audio service events
    _audioService.onCurrentSongChanged.listen((song) {
      state = state.copyWith(currentSong: song);
    });
    
    _audioService.onPlaybackStateChanged.listen((isPlaying) {
      state = state.copyWith(isPlaying: isPlaying);
    });
    
    _audioService.onPositionChanged.listen((position) {
      state = state.copyWith(position: position);
    });
    
    _audioService.onDurationChanged.listen((duration) {
      state = state.copyWith(duration: duration);
    });
    
    _audioService.onQueueChanged.listen((queueItem) {
      // Update queue from audio service
      _updateQueue();
    });
    
    // Initial update
    _updateQueue();
    _updatePlaybackState();
  }

  /// Update queue from audio service
  Future<void> _updateQueue() async {
    final queue = _audioService.queue;
    final currentIndex = _audioService.currentIndex;
    final currentSong = _audioService.currentSong;
    final isShuffled = _audioService.isShuffled;
    final repeatMode = _audioService.repeatMode;
    
    state = state.copyWith(
      queue: queue,
      currentIndex: currentIndex,
      currentSong: currentSong,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
    );
  }

  /// Update playback state from audio service
  Future<void> _updatePlaybackState() async {
    final isPlaying = _audioService.isPlaying;
    final volume = _audioService.volume;
    final playbackSpeed = _audioService.playbackSpeed;
    
    state = state.copyWith(
      isPlaying: isPlaying,
      volume: volume,
      playbackSpeed: playbackSpeed,
    );
  }

  /// Play a song
  Future<void> playSong(Song song) async {
    await _audioService.playSong(song);
    await _updateQueue();
    await _updatePlaybackState();
  }

  /// Play a playlist
  Future<void> playPlaylist(Playlist playlist, List<Song> songs) async {
    await _audioService.playPlaylist(playlist, songs);
    await _updateQueue();
    await _updatePlaybackState();
  }

  /// Play from queue by index
  Future<void> playFromQueue(int index) async {
    await _audioService.playFromQueue(index);
    await _updateQueue();
    await _updatePlaybackState();
  }

  /// Add song to queue
  Future<void> addToQueue(Song song) async {
    await _audioService.addToQueue(song);
    await _updateQueue();
  }

  /// Add multiple songs to queue
  Future<void> addToQueueMultiple(List<Song> songs) async {
    await _audioService.addToQueueMultiple(songs);
    await _updateQueue();
  }

  /// Remove song from queue
  Future<void> removeFromQueue(int index) async {
    await _audioService.removeFromQueue(index);
    await _updateQueue();
  }

  /// Clear queue
  Future<void> clearQueue() async {
    await _audioService.clearQueue();
    state = state.copyWith(queue: [], currentIndex: -1, currentSong: null);
  }

  /// Play
  Future<void> play() async {
    await _audioService.play();
    await _updatePlaybackState();
  }

  /// Pause
  Future<void> pause() async {
    await _audioService.pause();
    await _updatePlaybackState();
  }

  /// Stop
  Future<void> stop() async {
    await _audioService.stop();
    state = state.copyWith(
      isPlaying: false,
      currentSong: null,
      currentIndex: -1,
    );
  }

  /// Next song
  Future<void> next() async {
    await _audioService.next();
    await _updateQueue();
    await _updatePlaybackState();
  }

  /// Previous song
  Future<void> previous() async {
    await _audioService.previous();
    await _updateQueue();
    await _updatePlaybackState();
  }

  /// Seek to position
  Future<void> seekTo(Duration position) async {
    await _audioService.seekTo(position);
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    await _audioService.toggleShuffle();
    state = state.copyWith(isShuffled: !state.isShuffled);
  }

  /// Set repeat mode
  Future<void> setRepeatMode(RepeatMode mode) async {
    await _audioService.setRepeatMode(mode);
    state = state.copyWith(repeatMode: mode);
  }

  /// Set volume
  Future<void> setVolume(double volume) async {
    await _audioService.setVolume(volume);
    state = state.copyWith(volume: volume);
  }

  /// Set playback speed
  Future<void> setPlaybackSpeed(double speed) async {
    await _audioService.setPlaybackSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }
}
