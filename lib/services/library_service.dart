import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/song.dart';
import '../models/library_folder.dart';
import 'saf_service.dart';

/// Service for managing the local music library
/// Handles scanning, indexing, and querying songs from selected folders
class LibraryService {
  static const String _databaseName = 'scariCANO_library.db';
  static const int _databaseVersion = 1;
  
  Database? _database;
  final Map<String, LibraryFolder> _folders = {};
  final List<Song> _songs = [];
  
  // Stream controllers
  final StreamController<List<Song>> _songsUpdatedController = StreamController.broadcast();
  final StreamController<LibraryFolder> _folderAddedController = StreamController.broadcast();
  final StreamController<LibraryFolder> _folderRemovedController = StreamController.broadcast();
  final StreamController<ScanProgress> _scanProgressController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  
  /// Stream for songs updates
  Stream<List<Song>> get onSongsUpdated => _songsUpdatedController.stream;
  
  /// Stream for folder added
  Stream<LibraryFolder> get onFolderAdded => _folderAddedController.stream;
  
  /// Stream for folder removed
  Stream<LibraryFolder> get onFolderRemoved => _folderRemovedController.stream;
  
  /// Stream for scan progress
  Stream<ScanProgress> get onScanProgress => _scanProgressController.stream;
  
  /// Stream for errors
  Stream<String> get onError => _errorController.stream;

  /// Private constructor
  LibraryService._();
  
  /// Singleton instance
  static final LibraryService instance = LibraryService._();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _openDatabase();
      await _loadFolders();
    } catch (e) {
      _errorController.add('Errore nell\'inizializzazione della libreria: ${e.toString()}');
      rethrow;
    }
  }

  /// Open the database
  Future<void> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (Database db, int version) async {
        await _createTables(db);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        // Handle database upgrades if needed
      },
    );
  }

  /// Create database tables
  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE folders (
        uri TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT,
        is_writable INTEGER DEFAULT 0,
        last_scanned TEXT,
        song_count INTEGER DEFAULT 0
      )
    ''');
    
    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT,
        album_art_url TEXT,
        uri TEXT NOT NULL,
        duration INTEGER NOT NULL,
        track_number INTEGER,
        date_added TEXT,
        date_modified TEXT,
        file_size INTEGER,
        genre TEXT,
        year INTEGER,
        folder_uri TEXT,
        FOREIGN KEY(folder_uri) REFERENCES folders(uri)
      )
    ''');
    
    await db.execute('''
      CREATE INDEX idx_songs_title ON songs(title)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_songs_artist ON songs(artist)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_songs_album ON songs(album)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_songs_folder ON songs(folder_uri)
    ''');
  }

  /// Load folders from database
  Future<void> _loadFolders() async {
    if (_database == null) return;
    
    final folders = await _database!.query('folders');
    
    for (final folder in folders) {
      _folders[folder['uri'] as String] = LibraryFolder(
        uri: folder['uri'] as String,
        name: folder['name'] as String,
        path: folder['path'] as String?,
        isWritable: folder['is_writable'] as int == 1,
        lastScanned: folder['last_scanned'] != null 
            ? DateTime.parse(folder['last_scanned'] as String) 
            : null,
        songCount: folder['song_count'] as int,
      );
    }
  }

  /// Load songs from database
  Future<void> _loadSongs() async {
    if (_database == null) return;
    
    _songs.clear();
    
    final songs = await _database!.query('songs');
    
    for (final song in songs) {
      _songs.add(Song(
        id: song['id'] as String,
        title: song['title'] as String,
        artist: song['artist'] as String,
        album: song['album'] as String?,
        albumArtUrl: song['album_art_url'] as String?,
        uri: song['uri'] as String,
        duration: Duration(milliseconds: song['duration'] as int),
        trackNumber: song['track_number'] as int?,
        dateAdded: song['date_added'] != null 
            ? DateTime.parse(song['date_added'] as String) 
            : null,
        dateModified: song['date_modified'] != null 
            ? DateTime.parse(song['date_modified'] as String) 
            : null,
        fileSize: song['file_size'] as int?,
        genre: song['genre'] as String?,
        year: song['year'] as int?,
      ));
    }
    
    _songsUpdatedController.add(_songs.toList());
  }

  /// Get all folders
  List<LibraryFolder> get folders => _folders.values.toList();

  /// Get all songs
  List<Song> get songs => _songs.toList();

  /// Add a folder to the library
  Future<bool> addFolder(String uri, String name, {String? path, bool isWritable = false}) async {
    if (_database == null) return false;
    
    // Check if folder already exists
    if (_folders.containsKey(uri)) {
      return true;
    }
    
    try {
      await _database!.insert('folders', {
        'uri': uri,
        'name': name,
        'path': path,
        'is_writable': isWritable ? 1 : 0,
        'last_scanned': null,
        'song_count': 0,
      });
      
      _folders[uri] = LibraryFolder(
        uri: uri,
        name: name,
        path: path,
        isWritable: isWritable,
        songCount: 0,
      );
      
      _folderAddedController.add(_folders[uri]!);
      return true;
    } catch (e) {
      _errorController.add('Errore nell\'aggiunta della cartella: ${e.toString()}');
      return false;
    }
  }

  /// Remove a folder from the library
  Future<bool> removeFolder(String uri) async {
    if (_database == null) return false;
    
    try {
      await _database!.delete('folders', where: 'uri = ?', whereArgs: [uri]);
      await _database!.delete('songs', where: 'folder_uri = ?', whereArgs: [uri]);
      
      _folders.remove(uri);
      _songs.removeWhere((song) => song.uri.startsWith(uri));
      
      _folderRemovedController.add(LibraryFolder(uri: uri, name: 'Removed'));
      _songsUpdatedController.add(_songs.toList());
      return true;
    } catch (e) {
      _errorController.add('Errore nella rimozione della cartella: ${e.toString()}');
      return false;
    }
  }

  /// Scan a folder for songs
  Future<void> scanFolder(String uri) async {
    final folder = _folders[uri];
    if (folder == null) return;
    
    try {
      // Update folder status
      _folders[uri] = folder.copyWith(isScanning: true);
      _scanProgressController.add(ScanProgress(
        folderUri: uri,
        status: ScanStatus.scanning,
        filesScanned: 0,
        filesFound: 0,
      ));
      
      final safService = SafService.instance;
      
      // List files in the folder
      final fileUris = await safService.listFiles(uri);
      
      final newSongs = <Song>[];
      var filesScanned = 0;
      var filesFound = 0;
      
      for (final fileUri in fileUris) {
        filesScanned++;
        
        // Check if file is a directory
        final isDir = await safService.isDirectory(fileUri);
        if (isDir) continue;
        
        // Check if file is an audio file
        final displayName = await safService.getDisplayName(fileUri);
        final fileName = displayName.toLowerCase();
        
        if (_isAudioFile(fileName)) {
          // Get file info (simplified for now)
          // In a real implementation, we would extract metadata
          final song = Song.fromUri(
            uri: fileUri,
            title: displayName.replaceFirst(RegExp(r'\.[^.]+$'), ''), // Remove extension
            artist: 'Sconosciuto',
            duration: const Duration(seconds: 0),
            fileSize: null,
            dateAdded: DateTime.now(),
            dateModified: DateTime.now(),
          );
          
          newSongs.add(song);
          filesFound++;
        }
        
        // Update progress periodically
        if (filesScanned % 10 == 0) {
          _scanProgressController.add(ScanProgress(
            folderUri: uri,
            status: ScanStatus.scanning,
            filesScanned: filesScanned,
            filesFound: filesFound,
            currentFileName: displayName,
          ));
        }
      }
      
      // Save songs to database
      if (newSongs.isNotEmpty && _database != null) {
        for (final song in newSongs) {
          await _database!.insert('songs', {
            'id': song.id,
            'title': song.title,
            'artist': song.artist,
            'album': song.album,
            'album_art_url': song.albumArtUrl,
            'uri': song.uri,
            'duration': song.duration.inMilliseconds,
            'track_number': song.trackNumber,
            'date_added': song.dateAdded?.toIso8601String(),
            'date_modified': song.dateModified?.toIso8601String(),
            'file_size': song.fileSize,
            'genre': song.genre,
            'year': song.year,
            'folder_uri': uri,
          });
        }
        
        // Update folder song count
        await _database!.update('folders', {
          'song_count': folder.songCount + newSongs.length,
          'last_scanned': DateTime.now().toIso8601String(),
        }, where: 'uri = ?', whereArgs: [uri]);
        
        // Update local cache
        _songs.addAll(newSongs);
        _folders[uri] = folder.copyWith(
          songCount: folder.songCount + newSongs.length,
          lastScanned: DateTime.now(),
          isScanning: false,
        );
        
        _songsUpdatedController.add(_songs.toList());
      }
      
      _scanProgressController.add(ScanProgress(
        folderUri: uri,
        status: ScanStatus.completed,
        filesScanned: filesScanned,
        filesFound: filesFound,
        completedAt: DateTime.now(),
      ));
      
    } catch (e) {
      _folders[uri] = folder.copyWith(isScanning: false, error: e.toString());
      _scanProgressController.add(ScanProgress(
        folderUri: uri,
        status: ScanStatus.failed,
        error: e.toString(),
      ));
      _errorController.add('Errore nella scansione della cartella: ${e.toString()}');
    }
  }

  /// Scan all folders
  Future<void> scanAllFolders() async {
    for (final folder in _folders.values) {
      await scanFolder(folder.uri);
    }
  }

  /// Check if a file is an audio file based on extension
  bool _isAudioFile(String fileName) {
    final audioExtensions = [
      '.mp3', '.m4a', '.wav', '.flac', '.aac', '.ogg', '.opus',
      '.mp4', '.m4b', '.m4p', '.3gp', '.3g2', '.webm',
    ];
    
    return audioExtensions.any((ext) => fileName.endsWith(ext));
  }

  /// Get songs by artist
  List<Song> getSongsByArtist(String artist) {
    return _songs.where((song) => 
      song.artist.equals(artist, ignoreCase: true)
    ).toList();
  }

  /// Get songs by album
  List<Song> getSongsByAlbum(String album) {
    return _songs.where((song) => 
      song.album != null && song.album!.equals(album, ignoreCase: true)
    ).toList();
  }

  /// Get songs by genre
  List<Song> getSongsByGenre(String genre) {
    return _songs.where((song) => 
      song.genre != null && song.genre!.equals(genre, ignoreCase: true)
    ).toList();
  }

  /// Get songs by folder
  List<Song> getSongsByFolder(String folderUri) {
    return _songs.where((song) => 
      song.uri.startsWith(folderUri)
    ).toList();
  }

  /// Search songs by title or artist
  List<Song> searchSongs(String query) {
    final lowerQuery = query.toLowerCase();
    return _songs.where((song) => 
      song.title.toLowerCase().contains(lowerQuery) ||
      song.artist.toLowerCase().contains(lowerQuery) ||
      (song.album?.toLowerCase().contains(lowerQuery) ?? false)
    ).toList();
  }

  /// Get all artists
  List<String> get allArtists {
    return _songs
        .map((song) => song.artist)
        .toSet()
        .toList()
        ..sort();
  }

  /// Get all albums
  List<String> get allAlbums {
    return _songs
        .map((song) => song.album)
        .where((album) => album != null)
        .toSet()
        .toList()
        ..sort();
  }

  /// Get all genres
  List<String> get allGenres {
    return _songs
        .map((song) => song.genre)
        .where((genre) => genre != null)
        .toSet()
        .toList()
        ..sort();
  }

  /// Get recently added songs
  List<Song> get recentlyAdded {
    return _songs
        .where((song) => song.dateAdded != null)
        .toList()
        ..sort((a, b) => b.dateAdded!.compareTo(a.dateAdded!))
        .take(50)
        .toList();
  }

  /// Get recently played songs (would need play history tracking)
  List<Song> get recentlyPlayed {
    // For now, return recently added as placeholder
    return recentlyAdded;
  }

  /// Clear the library
  Future<void> clearLibrary() async {
    if (_database == null) return;
    
    try {
      await _database!.delete('songs');
      await _database!.update('folders', {'song_count': 0, 'last_scanned': null});
      
      _songs.clear();
      for (final folder in _folders.values) {
        _folders[folder.uri] = folder.copyWith(songCount: 0, lastScanned: null);
      }
      
      _songsUpdatedController.add([]);
    } catch (e) {
      _errorController.add('Errore nella pulizia della libreria: ${e.toString()}');
    }
  }

  /// Dispose the service
  void dispose() {
    _songsUpdatedController.close();
    _folderAddedController.close();
    _folderRemovedController.close();
    _scanProgressController.close();
    _errorController.close();
    _database?.close();
    _database = null;
  }
}
