import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/youtube_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
import '../models/song.dart';
import '../models/download_task.dart';
import '../services/saf_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Search screen for finding and downloading music
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedDestinationUri = '';
  
  @override
  void initState() {
    super.initState();
    _loadDefaultDestination();
    
    // Focus on search field when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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

  /// Download a song
  Future<void> _downloadSong(Song song) async {
    if (_selectedDestinationUri.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona prima una cartella di destinazione')),
      );
      return;
    }
    
    try {
      // Get audio stream URL
      final youtubeState = ref.read(youtubeProvider);
      final youtubeNotifier = ref.read(youtubeProvider.notifier);
      
      // Extract video ID from URL
      String? videoId;
      if (song.uri.contains('youtube.com')) {
        final uri = Uri.parse(song.uri);
        videoId = uri.queryParameters['v'] ?? song.id;
      } else if (song.uri.contains('youtu.be')) {
        videoId = song.uri.split('/').last;
      } else {
        videoId = song.id;
      }
      
      final audioUrl = await youtubeNotifier.getAudioStreamUrl(videoId);
      if (audioUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossibile ottenere URL audio')),
        );
        return;
      }
      
      // Show format selection dialog
      final selectedFormat = await _showFormatDialog();
      if (selectedFormat == null) return;
      
      // Start download
      final downloadNotifier = ref.read(downloadProvider.notifier);
      await downloadNotifier.startYouTubeDownload(
        videoId: videoId,
        url: audioUrl,
        destinationUri: _selectedDestinationUri,
        fileName: '${song.title} - ${song.artist}',
        title: song.title,
        artist: song.artist,
        thumbnailUrl: song.albumArtUrl,
        format: selectedFormat,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download avviato: ${song.title} (${selectedFormat.displayName})')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore download: ${e.toString()}')),
      );
    }
  }

  /// Show format selection dialog
  Future<AudioFormat?> _showFormatDialog() async {
    final downloadState = ref.read(downloadProvider);
    final defaultFormat = downloadState.defaultFormat;
    
    return showDialog<AudioFormat>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona formato'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Scegli il formato per il download:'),
            const SizedBox(height: 16),
            ...AudioFormat.values.map((format) => ListTile(
              title: Text(format.displayName),
              subtitle: Text(format.fileExtension),
              trailing: defaultFormat == format ? const Icon(Icons.check, color: Color(0xFFFF9800)) : null,
              onTap: () => Navigator.pop(context, format),
            )).toList(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ANNULLA'),
          ),
        ],
      ),
    );
  }

  /// Play a song
  Future<void> _playSong(Song song) async {
    try {
      final playerNotifier = ref.read(playerProvider.notifier);
      await playerNotifier.playSong(song);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore riproduzione: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final youtubeState = ref.watch(youtubeProvider);
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
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Cerca brani, artisti, album...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(youtubeProvider.notifier).clearSearchResults();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.cardTheme.color,
              ),
              onChanged: (query) {
                if (query.isEmpty) {
                  ref.read(youtubeProvider.notifier).clearSearchResults();
                }
              },
              onSubmitted: (query) {
                if (query.isNotEmpty) {
                  ref.read(youtubeProvider.notifier).search(query);
                }
              },
            ),
          ),
          
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
          
          // Trending section
          if (!youtubeState.isSearching && youtubeState.trending.isNotEmpty)
            _buildTrendingSection(youtubeState.trending),
          
          // Search results
          if (youtubeState.isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          
          if (!youtubeState.isSearching && youtubeState.hasSearchResults)
            _buildSearchResults(youtubeState.searchResults),
          
          // Empty state
          if (!youtubeState.isSearching && 
              !youtubeState.hasSearchResults && 
              !youtubeState.hasTrending)
            _buildEmptyState(),
        ],
      ),
    );
  }

  /// Build trending section
  Widget _buildTrendingSection(List<Song> trending) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '🎵 TRENDING',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final song = trending[index];
              return _buildSongCard(song, isTrending: true);
            },
          ),
        ),
      ],
    );
  }

  /// Build search results
  Widget _buildSearchResults(List<Song> results) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: results.length,
        itemBuilder: (context, index) {
          final song = results[index];
          return _buildSongCard(song, isTrending: false);
        },
      ),
    );
  }

  /// Build song card
  Widget _buildSongCard(Song song, {bool isTrending = false}) {
    final theme = Theme.of(context);
    
    if (isTrending) {
      return GestureDetector(
        onTap: () => _playSong(song),
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: Image.network(
                  song.albumArtUrl ?? 'https://via.placeholder.com/140x140?text=No+Cover',
                  width: 140,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 140,
                    height: 100,
                    color: const Color(0xFF333333),
                    child: const Icon(Icons.music_note, size: 40, color: Colors.white54),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 140,
                      height: 100,
                      color: const Color(0xFF333333),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Play button overlay
              Positioned.fill(
                child: Align(
                  alignment: Alignment.center,
                  child: IconButton(
                    icon: const Icon(Icons.play_circle_fill, size: 40),
                    color: Colors.white.withOpacity(0.8),
                    onPressed: () => _playSong(song),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              song.albumArtUrl ?? 'https://via.placeholder.com/50x50?text=No+Cover',
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 50,
                height: 50,
                color: const Color(0xFF333333),
                child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
              ),
            ),
          ),
          title: Text(song.title, style: theme.textTheme.titleMedium),
          subtitle: Text(song.artist, style: theme.textTheme.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
                onPressed: () => _playSong(song),
                tooltip: 'Riproduci',
              ),
              IconButton(
                icon: const Icon(Icons.download, color: Color(0xFFFF9800)),
                onPressed: () => _downloadSong(song),
                tooltip: 'Scarica',
              ),
            ],
          ),
          onTap: () => _playSong(song),
        ),
      );
    }
  }

  /// Build empty state
  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Color(0xFFB3B3B3)),
            const SizedBox(height: 16),
            Text(
              'Cerca brani su YouTube',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Inserisci un artista, un brano o un album',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
