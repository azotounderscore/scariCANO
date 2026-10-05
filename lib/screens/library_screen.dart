import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';
import '../services/saf_service.dart';

/// Library screen for browsing local music
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 0);
    
    // Load library data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(libraryProvider.notifier).scanAllFolders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Add a folder to the library
  Future<void> _addFolder() async {
    try {
      final safService = SafService.instance;
      safService.openDirectoryPicker();
      
      // Listen for folder selection
      safService.onDirectorySelected.first.then((uri) async {
        final displayName = await safService.getDisplayName(uri);
        
        // Add folder to library
        final libraryNotifier = ref.read(libraryProvider.notifier);
        await libraryNotifier.addFolder(uri, displayName);
        
        // Scan the folder
        await libraryNotifier.scanFolder(uri);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore: ${e.toString()}')),
      );
    }
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

  /// Play all songs by artist
  Future<void> _playAllByArtist(String artist) async {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final songs = libraryNotifier.getSongsByArtist(artist);
    
    if (songs.isNotEmpty) {
      final playerNotifier = ref.read(playerProvider.notifier);
      for (final song in songs) {
        await playerNotifier.addToQueue(song);
      }
      await playerNotifier.playFromQueue(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('scariCANO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addFolder,
            tooltip: 'Aggiungi cartella',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(libraryProvider.notifier).scanAllFolders(),
            tooltip: 'Aggiorna libreria',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Artisti', icon: Icon(Icons.people)),
            Tab(text: 'Album', icon: Icon(Icons.album)),
            Tab(text: 'Recenti', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildArtistsTab(libraryState),
          _buildAlbumsTab(libraryState),
          _buildRecentsTab(libraryState),
        ],
      ),
    );
  }

  /// Build artists tab
  Widget _buildArtistsTab(LibraryState state) {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final artists = libraryNotifier.allArtists;
    
    if (state.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (artists.isEmpty) {
      return _buildEmptyLibrary('Nessun artista trovato', 'Aggiungi una cartella per iniziare');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        final songs = libraryNotifier.getSongsByArtist(artist);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF333333),
              child: Icon(Icons.person, color: Colors.white54),
            ),
            title: Text(artist, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text('${songs.length} brani', style: Theme.of(context).textTheme.bodySmall),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow, color: Color(0xFFFF9800)),
              onPressed: () => _playAllByArtist(artist),
              tooltip: 'Riproduci tutto',
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ArtistSongsScreen(artist: artist),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Build albums tab
  Widget _buildAlbumsTab(LibraryState state) {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final albums = libraryNotifier.allAlbums;
    
    if (state.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (albums.isEmpty) {
      return _buildEmptyLibrary('Nessun album trovato', 'Aggiungi una cartella per iniziare');
    }
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        final songs = libraryNotifier.getSongsByAlbum(album);
        
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AlbumSongsScreen(album: album),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Album art placeholder
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: Container(
                      color: const Color(0xFF333333),
                      child: const Center(
                        child: Icon(Icons.album, size: 40, color: Colors.white54),
                      ),
                    ),
                  ),
                ),
                // Info
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${songs.length} brani',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build recents tab
  Widget _buildRecentsTab(LibraryState state) {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final recentSongs = libraryNotifier.recentlyAdded;
    
    if (state.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (recentSongs.isEmpty) {
      return _buildEmptyLibrary('Nessun brano recente', 'Aggiungi una cartella per iniziare');
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: recentSongs.length,
      itemBuilder: (context, index) {
        final song = recentSongs[index];
        return _buildSongTile(song);
      },
    );
  }

  /// Build song tile
  Widget _buildSongTile(Song song) {
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
            child: const Icon(Icons.music_note, size: 24, color: Colors.white54),
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
          ],
        ),
        onTap: () => _playSong(song),
      ),
    );
  }

  /// Build empty library message
  Widget _buildEmptyLibrary(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_music, size: 64, color: Color(0xFFB3B3B3)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Aggiungi cartella'),
            onPressed: _addFolder,
          ),
        ],
      ),
    );
  }
}

/// Artist songs screen
class ArtistSongsScreen extends ConsumerWidget {
  final String artist;
  
  const ArtistSongsScreen({super.key, required this.artist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final songs = libraryNotifier.getSongsByArtist(artist);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(artist),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final playerNotifier = ref.read(playerProvider.notifier);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(10),
            ),
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
              title: Text(song.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(song.album ?? '', style: Theme.of(context).textTheme.bodySmall),
              trailing: Text(
                '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => playerNotifier.playSong(song),
            ),
          );
        },
      ),
    );
  }
}

/// Album songs screen
class AlbumSongsScreen extends ConsumerWidget {
  final String album;
  
  const AlbumSongsScreen({super.key, required this.album});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final songs = libraryNotifier.getSongsByAlbum(album);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(album),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          final playerNotifier = ref.read(playerProvider.notifier);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              leading: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              title: Text(song.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(song.artist, style: Theme.of(context).textTheme.bodySmall),
              trailing: Text(
                '${song.duration.inMinutes}:${(song.duration.inSeconds % 60).toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () => playerNotifier.playSong(song),
            ),
          );
        },
      ),
    );
  }
}
