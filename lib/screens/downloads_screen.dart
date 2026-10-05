import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/download_provider.dart';
import '../models/download_task.dart';
import '../services/saf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Downloads screen for managing active and completed downloads
class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  String _selectedDestinationUri = '';
  
  @override
  void initState() {
    super.initState();
    _loadDefaultDestination();
  }

  /// Load default destination from preferences
  Future<void> _loadDefaultDestination() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedDestinationUri = prefs.getString('default_destination_uri') ?? '';
  }

  /// Save default destination to preferences
  Future<void> _saveDefaultDestination(String uri) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('default_destination_uri', uri);
    setState(() => _selectedDestinationUri = uri);
  }

  /// Select destination folder
  Future<void> _selectDestination() async {
    try {
      final safService = SafService.instance;
      safService.openDirectoryPicker();
      
      // Listen for folder selection
      safService.onDirectorySelected.first.then((uri) {
        _saveDefaultDestination(uri);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  /// Cancel a download
  Future<void> _cancelDownload(String downloadId) async {
    try {
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.cancelDownload(downloadId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  /// Pause a download
  Future<void> _pauseDownload(String downloadId) async {
    try {
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.pauseDownload(downloadId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  /// Resume a download
  Future<void> _resumeDownload(String downloadId) async {
    try {
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.resumeDownload(downloadId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  /// Remove a completed download
  Future<void> _removeDownload(String downloadId) async {
    try {
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.removeDownload(downloadId);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  /// Clear all completed downloads
  Future<void> _clearCompletedDownloads() async {
    try {
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.clearCompletedDownloads();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(downloadProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('scariCANO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _selectDestination,
            tooltip: 'Seleziona cartella download',
          ),
        ],
      ),
      body: Column(
        children: [
          // Selected destination
          if (_selectedDestinationUri.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.folder, size: 20, color: Color(0xFFFF9800)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedDestinationUri.split('/').last,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.change_circle, size: 20),
                    onPressed: _selectDestination,
                    tooltip: 'Cambia cartella',
                  ),
                ],
              ),
            ),
          
          // Active downloads
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'ATTIVI'),
                      Tab(text: 'COMPLETATI'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildActiveDownloads(downloadState),
                        _buildCompletedDownloads(downloadState),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build active downloads list
  Widget _buildActiveDownloads(DownloadState state) {
    final activeDownloads = state.activeDownloads;
    final queuedDownloads = state.queuedDownloads;
    
    if (activeDownloads.isEmpty && queuedDownloads.isEmpty) {
      return _buildEmptyDownloads('Nessun download attivo');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeDownloads.length + queuedDownloads.length,
      itemBuilder: (context, index) {
        final task = index < activeDownloads.length 
            ? activeDownloads[index] 
            : queuedDownloads[index - activeDownloads.length];
        
        return _buildDownloadCard(task, isQueued: index >= activeDownloads.length);
      },
    );
  }

  /// Build completed downloads list
  Widget _buildCompletedDownloads(DownloadState state) {
    final completedDownloads = state.completedDownloads;
    
    if (completedDownloads.isEmpty) {
      return _buildEmptyDownloads('Nessun download completato');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedDownloads.length,
      itemBuilder: (context, index) {
        final task = completedDownloads[index];
        return _buildCompletedDownloadCard(task);
      },
    );
  }

  /// Build download card for active/queued downloads
  Widget _buildDownloadCard(DownloadTask task, {bool isQueued = false}) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 50,
            height: 50,
            color: const Color(0xFF333333),
            child: task.thumbnailUrl != null
                ? Image.network(
                    task.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => 
                      const Icon(Icons.music_note, size: 24, color: Colors.white54),
                  )
                : const Icon(Icons.music_note, size: 24, color: Colors.white54),
          ),
        ),
        title: Text(
          task.title ?? task.fileName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.artist != null)
              Text(task.artist!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            // Progress bar
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: const Color(0xFF333333),
              valueColor: AlwaysStoppedAnimation<Color>(task.status.statusColor),
            ),
            const SizedBox(height: 4),
            Text(
              '${(task.progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isQueued)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
                onPressed: () => _resumeDownload(task.id),
                tooltip: 'Riprendi',
              ),
            if (!isQueued && task.status == DownloadStatus.running)
              IconButton(
                icon: const Icon(Icons.pause, color: Color(0xFFFF9800)),
                onPressed: () => _pauseDownload(task.id),
                tooltip: 'Pausa',
              ),
            if (!isQueued && task.status == DownloadStatus.paused)
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
                onPressed: () => _resumeDownload(task.id),
                tooltip: 'Riprendi',
              ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _cancelDownload(task.id),
              tooltip: 'Annulla',
            ),
          ],
        ),
      ),
    );
  }

  /// Build completed download card
  Widget _buildCompletedDownloadCard(DownloadTask task) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
        title: Text(
          task.title ?? task.fileName,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.artist != null)
              Text(task.artist!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              'Completato il ${task.completedAt?.toString().split(' ')[0] ?? ''}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () => _removeDownload(task.id),
          tooltip: 'Elimina',
        ),
      ),
    );
  }

  /// Build empty downloads message
  Widget _buildEmptyDownloads(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.download, size: 64, color: Color(0xFFB3B3B3)),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
