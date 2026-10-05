import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../models/song.dart';

/// Full player screen
class PlayerScreen extends ConsumerStatefulWidget {
  final Song? song;
  
  const PlayerScreen({super.key, this.song});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  @override
  void initState() {
    super.initState();
    
    // If a song is provided, play it
    if (widget.song != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(playerProvider.notifier).playSong(widget.song!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.queue_music),
            onPressed: () {
              // Show queue
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show menu
            },
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          // Spacer for app bar
          const SizedBox(height: kToolbarHeight),
          
          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Album art
                  SizedBox(
                    width: size.width * 0.8,
                    height: size.width * 0.8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: playerState.currentSong?.albumArtUrl != null
                          ? Image.network(
                              playerState.currentSong!.albumArtUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF333333),
                                child: const Icon(
                                  Icons.music_note,
                                  size: 64,
                                  color: Colors.white54,
                                ),
                              ),
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: const Color(0xFF333333),
                                  child: const Center(child: CircularProgressIndicator()),
                                );
                              },
                            )
                          : Container(
                              color: const Color(0xFF333333),
                              child: const Icon(
                                Icons.music_note,
                                size: 64,
                                color: Colors.white54,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Song info
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          playerState.currentSong?.title ?? 'Sconosciuto',
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          playerState.currentSong?.artist ?? 'Sconosciuto',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: theme.colorScheme.primary,
                            inactiveTrackColor: const Color(0xFF333333),
                            thumbColor: theme.colorScheme.primary,
                          ),
                          child: Slider(
                            value: playerState.duration.inMilliseconds > 0
                                ? playerState.position.inMilliseconds.toDouble()
                                : 0.0,
                            min: 0.0,
                            max: playerState.duration.inMilliseconds > 0
                                ? playerState.duration.inMilliseconds.toDouble()
                                : 1000.0,
                            onChanged: (value) {
                              ref.read(playerProvider.notifier).seekTo(
                                Duration(milliseconds: value.toInt()),
                              );
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(playerState.position),
                              style: theme.textTheme.bodySmall,
                            ),
                            Text(
                              _formatDuration(playerState.duration),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.shuffle, size: 28),
                          onPressed: () => ref.read(playerProvider.notifier).toggleShuffle(),
                          color: playerState.isShuffled ? theme.colorScheme.primary : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, size: 32),
                          onPressed: playerState.canPrevious 
                              ? () => ref.read(playerProvider.notifier).previous()
                              : null,
                          color: playerState.canPrevious ? Colors.white : const Color(0xFFB3B3B3),
                        ),
                        IconButton(
                          icon: Icon(
                            playerState.isPlaying ? Icons.pause_circle : Icons.play_circle,
                            size: 56,
                          ),
                          onPressed: playerState.isPlaying 
                              ? () => ref.read(playerProvider.notifier).pause()
                              : () => ref.read(playerProvider.notifier).play(),
                          color: theme.colorScheme.primary,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, size: 32),
                          onPressed: playerState.canNext 
                              ? () => ref.read(playerProvider.notifier).next()
                              : null,
                          color: playerState.canNext ? Colors.white : const Color(0xFFB3B3B3),
                        ),
                        IconButton(
                          icon: Icon(
                            _getRepeatIcon(playerState.repeatMode),
                            size: 28,
                          ),
                          onPressed: () {
                            final nextMode = _getNextRepeatMode(playerState.repeatMode);
                            ref.read(playerProvider.notifier).setRepeatMode(nextMode);
                          },
                          color: playerState.repeatMode != RepeatMode.none 
                              ? theme.colorScheme.primary 
                              : null,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Additional controls
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.volume_up),
                          onPressed: () {
                            // Show volume slider
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.timer),
                          onPressed: () {
                            // Show sleep timer
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.favorite_border),
                          onPressed: () {
                            // Toggle favorite
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get repeat icon based on mode
  IconData _getRepeatIcon(RepeatMode mode) {
    switch (mode) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat;
    }
  }

  /// Get next repeat mode
  RepeatMode _getNextRepeatMode(RepeatMode current) {
    switch (current) {
      case RepeatMode.none:
        return RepeatMode.all;
      case RepeatMode.all:
        return RepeatMode.one;
      case RepeatMode.one:
        return RepeatMode.none;
    }
  }
}
