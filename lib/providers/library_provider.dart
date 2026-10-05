import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/library_folder.dart';
import '../services/library_service.dart';

/// Library state
@immutable
class LibraryState {
  final List<LibraryFolder> folders;
  final List<Song> songs;
  final bool isLoading;
  final bool isScanning;
  final String? error;
  final String? currentScanFolder;
  final int scanProgress;
  final int scanTotal;

  const LibraryState({
    this.folders = const [],
    this.songs = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.error = null,
    this.currentScanFolder = null,
    this.scanProgress = 0,
    this.scanTotal = 0,
  });

  LibraryState copyWith({
    List<LibraryFolder>? folders,
    List<Song>? songs,
    bool? isLoading,
    bool? isScanning,
    String? error,
    String? currentScanFolder,
    int? scanProgress,
    int? scanTotal,
  }) {
    return LibraryState(
      folders: folders ?? this.folders,
      songs: songs ?? this.songs,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      error: error ?? this.error,
      currentScanFolder: currentScanFolder ?? this.currentScanFolder,
      scanProgress: scanProgress ?? this.scanProgress,
      scanTotal: scanTotal ?? this.scanTotal,
    );
  }

  bool get hasFolders => folders.isNotEmpty;
  bool get hasSongs => songs.isNotEmpty;
  bool get isEmpty => !hasFolders && !hasSongs;
}

/// Library provider
final libraryProvider = StateNotifierProvider<LibraryNotifier, LibraryState>((ref) {
  return LibraryNotifier();
});

/// Library notifier
class LibraryNotifier extends StateNotifier<LibraryState> {
  final LibraryService _libraryService = LibraryService.instance;
  
  LibraryNotifier() : super(const LibraryState()) {
    _initialize();
  }

  /// Initialize the notifier
  Future<void> _initialize() async {
    await _libraryService.initialize();
    
    // Load initial data
    _updateFolders();
    _updateSongs();
    
    // Listen to library service events
    _libraryService.onSongsUpdated.listen((songs) {
      state = state.copyWith(songs: songs);
    });
    
    _libraryService.onFolderAdded.listen((folder) {
      _updateFolders();
    });
    
    _libraryService.onFolderRemoved.listen((folder) {
      _updateFolders();
    });
    
    _libraryService.onScanProgress.listen((progress) {
      state = state.copyWith(
        isScanning: progress.status == ScanStatus.scanning,
        currentScanFolder: progress.folderUri,
        scanProgress: progress.filesScanned,
        scanTotal: progress.filesScanned > 0 ? progress.filesScanned : 0,
      );
      
      if (progress.status == ScanStatus.completed || progress.status == ScanStatus.failed) {
        _updateSongs();
      }
    });
    
    _libraryService.onError.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  /// Update folders from library service
  void _updateFolders() {
    state = state.copyWith(folders: _libraryService.folders);
  }

  /// Update songs from library service
  void _updateSongs() {
    state = state.copyWith(songs: _libraryService.songs);
  }

  /// Add a folder to the library
  Future<bool> addFolder(String uri, String name, {String? path, bool isWritable = false}) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final success = await _libraryService.addFolder(uri, name, path: path, isWritable: isWritable);
      
      if (success) {
        _updateFolders();
        state = state.copyWith(isLoading: false);
        return true;
      }
      
      state = state.copyWith(isLoading: false, error: 'Impossibile aggiungere la cartella');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Remove a folder from the library
  Future<bool> removeFolder(String uri) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final success = await _libraryService.removeFolder(uri);
      
      if (success) {
        _updateFolders();
        _updateSongs();
        state = state.copyWith(isLoading: false);
        return true;
      }
      
      state = state.copyWith(isLoading: false, error: 'Impossibile rimuovere la cartella');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Scan a folder for songs
  Future<void> scanFolder(String uri) async {
    state = state.copyWith(
      isLoading: true,
      isScanning: true,
      currentScanFolder: uri,
      error: null,
    );
    
    try {
      await _libraryService.scanFolder(uri);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  /// Scan all folders
  Future<void> scanAllFolders() async {
    state = state.copyWith(
      isLoading: true,
      isScanning: true,
      error: null,
    );
    
    try {
      await _libraryService.scanAllFolders();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isScanning: false,
        error: e.toString(),
      );
    }
  }

  /// Get songs by artist
  List<Song> getSongsByArtist(String artist) {
    return _libraryService.getSongsByArtist(artist);
  }

  /// Get songs by album
  List<Song> getSongsByAlbum(String album) {
    return _libraryService.getSongsByAlbum(album);
  }

  /// Get songs by genre
  List<Song> getSongsByGenre(String genre) {
    return _libraryService.getSongsByGenre(genre);
  }

  /// Get songs by folder
  List<Song> getSongsByFolder(String folderUri) {
    return _libraryService.getSongsByFolder(folderUri);
  }

  /// Search songs
  List<Song> searchSongs(String query) {
    return _libraryService.searchSongs(query);
  }

  /// Get all artists
  List<String> get allArtists => _libraryService.allArtists;

  /// Get all albums
  List<String> get allAlbums => _libraryService.allAlbums;

  /// Get all genres
  List<String> get allGenres => _libraryService.allGenres;

  /// Get recently added songs
  List<Song> get recentlyAdded => _libraryService.recentlyAdded;

  /// Get recently played songs
  List<Song> get recentlyPlayed => _libraryService.recentlyPlayed;

  /// Clear the library
  Future<void> clearLibrary() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      await _libraryService.clearLibrary();
      state = state.copyWith(
        isLoading: false,
        songs: [],
        folders: state.folders.map((f) => f.copyWith(songCount: 0, lastScanned: null)).toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  @override
  void dispose() {
    _libraryService.dispose();
    super.dispose();
  }
}
