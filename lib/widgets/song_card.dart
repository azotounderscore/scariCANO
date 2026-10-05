import 'package:flutter/material.dart';
import '../models/song.dart';

/// Song card widget for displaying song information
class SongCard extends StatelessWidget {
  final Song song;
  final bool showDuration;
  final bool showArtist;
  final bool showAlbum;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  
  const SongCard({
    super.key,
    required this.song,
    this.showDuration = true,
    this.showArtist = true,
    this.showAlbum = false,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _buildAlbumArt(context),
        ),
        title: Text(
          song.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showArtist && song.artist.isNotEmpty)
              Text(
                song.artist,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (showAlbum && song.album != null && song.album!.isNotEmpty)
              Text(
                song.album!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: trailing ?? (showDuration 
            ? Text(
                _formatDuration(song.duration),
                style: theme.textTheme.bodySmall,
              )
            : null),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  /// Build album art widget
  Widget _buildAlbumArt(BuildContext context) {
    if (song.albumArtUrl != null) {
      return Image.network(
        song.albumArtUrl!,
        width: 50,
        height: 50,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  /// Build placeholder for album art
  Widget _buildPlaceholder() {
    return Container(
      width: 50,
      height: 50,
      color: const Color(0xFF333333),
      child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
    );
  }

  /// Format duration as MM:SS
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Horizontal song card for trending/featured sections
class HorizontalSongCard extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;
  final Widget? overlay;
  
  const HorizontalSongCard({
    super.key,
    required this.song,
    this.onTap,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album art
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: _buildAlbumArt(context),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Overlay (e.g., play button)
            if (overlay != null) overlay!,
          ],
        ),
      ),
    );
  }

  /// Build album art widget
  Widget _buildAlbumArt(BuildContext context) {
    if (song.albumArtUrl != null) {
      return Image.network(
        song.albumArtUrl!,
        width: 140,
        height: 100,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  /// Build placeholder for album art
  Widget _buildPlaceholder() {
    return Container(
      width: 140,
      height: 100,
      color: const Color(0xFF333333),
      child: const Icon(Icons.music_note, size: 40, color: Colors.white54),
    );
  }
}

/// Song list item with more controls
class SongListItem extends StatelessWidget {
  final Song song;
  final bool showDuration;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  
  const SongListItem({
    super.key,
    required this.song,
    this.showDuration = true,
    this.onPlay,
    this.onDownload,
    this.onTap,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: const Color(0xFF333333),
            child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
          ),
        ),
        title: Text(
          song.title,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showDuration)
              Text(
                _formatDuration(song.duration),
                style: theme.textTheme.bodySmall,
              ),
            if (showDuration) const SizedBox(width: 12),
            if (onPlay != null)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
                onPressed: onPlay,
                tooltip: 'Riproduci',
              ),
            if (onDownload != null)
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFFFF9800)),
                onPressed: onDownload,
                tooltip: 'Scarica',
              ),
            if (onMore != null)
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onMore,
                tooltip: 'Altro',
              ),
          ],
        ),
        onTap: onTap,
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
