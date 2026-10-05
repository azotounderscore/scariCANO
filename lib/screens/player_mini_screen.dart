import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// Mini player screen that appears at the bottom of the screen
class PlayerMiniScreen extends ConsumerWidget {
  const PlayerMiniScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final theme = Theme.of(context);
    
    // Don't show if no song is playing
    if (!playerState.hasCurrentSong) {
      return const SizedBox(height: 0);
    }
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          if (playerState.duration.inMilliseconds > 0)
            LinearProgressIndicator(
              value: playerState.position.inMilliseconds / playerState.duration.inMilliseconds,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
              minHeight: 2,
            ),
          
          // Player controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Song info
                Expanded(
                  child: Row(
                    children: [
                      // Album art placeholder
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFF333333),
                          child: const Icon(Icons.music_note, size: 20, color: Colors.white54),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Song info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              playerState.currentSong!.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              playerState.currentSong!.artist,
                              style: theme.textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous, size: 28),
                      onPressed: playerState.canPrevious 
                          ? () => ref.read(playerProvider.notifier).previous()
                          : null,
                      color: playerState.canPrevious ? Colors.white : const Color(0xFFB3B3B3),
                    ),
                    IconButton(
                      icon: Icon(
                        playerState.isPlaying ? Icons.pause : Icons.play_arrow,
                        size: 32,
                      ),
                      onPressed: playerState.isPlaying 
                          ? () => ref.read(playerProvider.notifier).pause()
                          : () => ref.read(playerProvider.notifier).play(),
                      color: theme.colorScheme.primary,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next, size: 28),
                      onPressed: playerState.canNext 
                          ? () => ref.read(playerProvider.notifier).next()
                          : null,
                      color: playerState.canNext ? Colors.white : const Color(0xFFB3B3B3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Position and duration
          if (playerState.duration.inMilliseconds > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                '${_formatDuration(playerState.position)} / ${_formatDuration(playerState.duration)}',
                style: theme.textTheme.bodySmall,
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
}
