import 'package:flutter/material.dart';
import '../models/download_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';

/// Download card widget for active downloads
class DownloadCard extends ConsumerWidget {
  final DownloadTask task;
  final bool showDestination;
  
  const DownloadCard({
    super.key,
    required this.task,
    this.showDestination = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildLeadingWidget(task),
        title: Text(
          task.title ?? task.fileName,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.artist != null)
              Text(
                task.artist!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            // Progress bar
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(task.status.statusColor),
              minHeight: 4,
            ),
            const SizedBox(height: 4),
            Text(
              '${(task.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
            if (showDestination && task.destinationUri.isNotEmpty)
              Text(
                'Dest: ${task.destinationUri.split('/').last}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: _buildTrailingActions(task, downloadNotifier, context),
      ),
    );
  }

  /// Build leading widget based on status
  Widget _buildLeadingWidget(DownloadTask task) {
    if (task.thumbnailUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          task.thumbnailUrl!,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildStatusIcon(task),
        ),
      );
    }
    return _buildStatusIcon(task);
  }

  /// Build status icon
  Widget _buildStatusIcon(DownloadTask task) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: task.status.statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getStatusIcon(task.status),
        color: task.status.statusColor,
        size: 24,
      ),
    );
  }

  /// Get icon based on status
  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.hourglass_empty;
      case DownloadStatus.running:
        return Icons.download;
      case DownloadStatus.paused:
        return Icons.pause;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
      case DownloadStatus.cancelled:
        return Icons.cancel;
    }
  }

  /// Build trailing actions based on status
  Widget _buildTrailingActions(DownloadTask task, DownloadNotifier notifier, BuildContext context) {
    switch (task.status) {
      case DownloadStatus.pending:
      case DownloadStatus.queued:
        return IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () => notifier.cancelDownload(task.id),
          tooltip: 'Annulla',
        );
      case DownloadStatus.running:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause, color: Color(0xFFFF9800)),
              onPressed: () => notifier.pauseDownload(task.id),
              tooltip: 'Pausa',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => notifier.cancelDownload(task.id),
              tooltip: 'Annulla',
            ),
          ],
        );
      case DownloadStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
              onPressed: () => notifier.resumeDownload(task.id),
              tooltip: 'Riprendi',
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => notifier.cancelDownload(task.id),
              tooltip: 'Annulla',
            ),
          ],
        );
      case DownloadStatus.completed:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
              onPressed: () {
                // Play the downloaded song
              },
              tooltip: 'Riproduci',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => notifier.removeDownload(task.id),
              tooltip: 'Elimina',
            ),
          ],
        );
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => notifier.removeDownload(task.id),
          tooltip: 'Elimina',
        );
    }
  }
}

/// Completed download card
class CompletedDownloadCard extends ConsumerWidget {
  final DownloadTask task;
  
  const CompletedDownloadCard({
    super.key,
    required this.task,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final downloadNotifier = ref.read(downloadProvider.notifier);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
        title: Text(
          task.title ?? task.fileName,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.artist != null)
              Text(
                task.artist!,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Text(
              'Completato il ${task.completedAt?.toString().split(' ')[0] ?? ''}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
              onPressed: () {
                // Play the downloaded song
              },
              tooltip: 'Riproduci',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => downloadNotifier.removeDownload(task.id),
              tooltip: 'Elimina',
            ),
          ],
        ),
      ),
    );
  }
}

/// Download progress indicator
class DownloadProgressIndicator extends StatelessWidget {
  final DownloadTask task;
  final double height;
  
  const DownloadProgressIndicator({
    super.key,
    required this.task,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: task.progress,
      backgroundColor: const Color(0xFF333333),
      valueColor: AlwaysStoppedAnimation<Color>(task.status.statusColor),
      minHeight: height,
    );
  }
}
