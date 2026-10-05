import 'dart:async';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song.dart';

/// Service for interacting with YouTube
/// Handles searching, video info extraction, and audio stream URL retrieval
class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();
  
  // Cache for search results
  final Map<String, List<Song>> _searchCache = {};
  final Map<String, Song> _videoCache = {};
  
  // Stream controllers
  final StreamController<List<Song>> _searchResultsController = StreamController.broadcast();
  final StreamController<Song> _videoInfoController = StreamController.broadcast();
  final StreamController<String> _errorController = StreamController.broadcast();
  
  /// Stream for search results
  Stream<List<Song>> get onSearchResults => _searchResultsController.stream;
  
  /// Stream for video info
  Stream<Song> get onVideoInfo => _videoInfoController.stream;
  
  /// Stream for errors
  Stream<String> get onError => _errorController.stream;

  /// Private constructor
  YouTubeService._();
  
  /// Singleton instance
  static final YouTubeService instance = YouTubeService._();

  /// Initialize the service
  Future<void> initialize() async {
    // No initialization needed
  }

  /// Search for videos on YouTube
  Future<List<Song>> search(String query, {int limit = 20}) async {
    try {
      // Check cache
      if (_searchCache.containsKey(query)) {
        return _searchCache[query]!;
      }
      
      final search = _yt.search;
      final results = await search.search(query, limit: limit).toList();
      
      final songs = <Song>[];
      
      for (final video in results) {
        if (video is VideoSearchResult) {
          final song = Song.fromYouTube(
            videoId: video.id.value,
            title: video.title,
            artist: video.author ?? 'Sconosciuto',
            album: null,
            thumbnailUrl: video.thumbnails.mediumResUrl,
            duration: video.duration ?? const Duration(seconds: 0),
          );
          songs.add(song);
        }
      }
      
      // Cache results
      _searchCache[query] = songs;
      _searchResultsController.add(songs);
      
      return songs;
    } catch (e) {
      _errorController.add('Errore nella ricerca: ${e.toString()}');
      rethrow;
    }
  }

  /// Get video info by ID
  Future<Song?> getVideoInfo(String videoId) async {
    try {
      // Check cache
      if (_videoCache.containsKey(videoId)) {
        return _videoCache[videoId];
      }
      
      final video = await _yt.videos.get(videoId);
      
      final song = Song.fromYouTube(
        videoId: video.id.value,
        title: video.title,
        artist: video.author ?? 'Sconosciuto',
        album: video.title, // Use title as album for now
        thumbnailUrl: video.thumbnails.mediumResUrl,
        duration: video.duration ?? const Duration(seconds: 0),
      );
      
      // Cache result
      _videoCache[videoId] = song;
      _videoInfoController.add(song);
      
      return song;
    } catch (e) {
      _errorController.add('Errore nel recupero informazioni video: ${e.toString()}');
      return null;
    }
  }

  /// Get audio stream URL for a video
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final video = await _yt.videos.get(videoId);
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      
      // Get the best audio-only stream
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) return null;
      
      // Sort by quality (highest first)
      final sortedStreams = audioStreams.sortedByDescending((s) => s.bitrate);
      
      // Get the first available stream
      final streamInfo = sortedStreams.first;
      
      return streamInfo.url.toString();
    } catch (e) {
      _errorController.add('Errore nel recupero URL audio: ${e.toString()}');
      return null;
    }
  }

  /// Get video thumbnail URL
  Future<String?> getThumbnailUrl(String videoId, {ThumbnailQuality quality = ThumbnailQuality.medium}) async {
    try {
      final video = await _yt.videos.get(videoId);
      
      return video.thumbnails.getByQuality(quality)?.url.toString();
    } catch (e) {
      return null;
    }
  }

  /// Get trending videos
  Future<List<Song>> getTrending({int limit = 10}) async {
    try {
      // YouTube Explode doesn't have a direct trending endpoint
      // So we'll use a popular search query
      return search('trending music', limit: limit);
    } catch (e) {
      _errorController.add('Errore nel recupero trending: ${e.toString()}');
      return [];
    }
  }

  /// Get suggested videos based on a video ID
  Future<List<Song>> getSuggestedVideos(String videoId, {int limit = 10}) async {
    try {
      final suggestions = await _yt.videos.getSuggestions(videoId);
      
      final songs = <Song>[];
      
      for (final suggestion in suggestions) {
        final song = Song.fromYouTube(
          videoId: suggestion.id.value,
          title: suggestion.title,
          artist: suggestion.author ?? 'Sconosciuto',
          album: null,
          thumbnailUrl: suggestion.thumbnails.mediumResUrl,
          duration: suggestion.duration ?? const Duration(seconds: 0),
        );
        songs.add(song);
      }
      
      return songs;
    } catch (e) {
      _errorController.add('Errore nel recupero suggerimenti: ${e.toString()}');
      return [];
    }
  }

  /// Get playlist videos
  Future<List<Song>> getPlaylistVideos(String playlistId, {int limit = 50}) async {
    try {
      final playlist = await _yt.playlists.get(playlistId);
      final videos = await playlist.videos.toList();
      
      final songs = <Song>[];
      
      for (final video in videos.take(limit)) {
        final song = Song.fromYouTube(
          videoId: video.id.value,
          title: video.title,
          artist: video.author ?? 'Sconosciuto',
          album: playlist.title,
          thumbnailUrl: video.thumbnails.mediumResUrl,
          duration: video.duration ?? const Duration(seconds: 0),
        );
        songs.add(song);
      }
      
      return songs;
    } catch (e) {
      _errorController.add('Errore nel recupero playlist: ${e.toString()}');
      return [];
    }
  }

  /// Search for playlists
  Future<List<Map<String, dynamic>>> searchPlaylists(String query, {int limit = 10}) async {
    try {
      final search = _yt.search;
      final results = await search.search(query, filter: SearchFilter.playlist, limit: limit).toList();
      
      final playlists = <Map<String, dynamic>>[];
      
      for (final result in results) {
        if (result is PlaylistSearchResult) {
          playlists.add({
            'id': result.id.value,
            'title': result.title,
            'author': result.author,
            'videoCount': result.videoCount,
            'thumbnailUrl': result.thumbnails.mediumResUrl,
          });
        }
      }
      
      return playlists;
    } catch (e) {
      _errorController.add('Errore nella ricerca playlist: ${e.toString()}');
      return [];
    }
  }

  /// Clear cache
  void clearCache() {
    _searchCache.clear();
    _videoCache.clear();
  }

  /// Dispose the service
  void dispose() {
    _searchResultsController.close();
    _videoInfoController.close();
    _errorController.close();
    _yt.close();
  }
}

/// Thumbnail quality enum
enum ThumbnailQuality {
  low,
  medium,
  high,
  maxRes,
}
