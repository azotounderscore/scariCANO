import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../services/youtube_service.dart';

/// YouTube state
@immutable
class YouTubeState {
  final List<Song> searchResults;
  final List<Song> trending;
  final List<Song> suggestions;
  final bool isSearching;
  final bool isLoading;
  final String? query;
  final String? error;

  const YouTubeState({
    this.searchResults = const [],
    this.trending = const [],
    this.suggestions = const [],
    this.isSearching = false,
    this.isLoading = false,
    this.query = null,
    this.error = null,
  });

  YouTubeState copyWith({
    List<Song>? searchResults,
    List<Song>? trending,
    List<Song>? suggestions,
    bool? isSearching,
    bool? isLoading,
    String? query,
    String? error,
  }) {
    return YouTubeState(
      searchResults: searchResults ?? this.searchResults,
      trending: trending ?? this.trending,
      suggestions: suggestions ?? this.suggestions,
      isSearching: isSearching ?? this.isSearching,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      error: error ?? this.error,
    );
  }

  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get hasTrending => trending.isNotEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;
}

/// YouTube provider
final youtubeProvider = StateNotifierProvider<YouTubeNotifier, YouTubeState>((ref) {
  return YouTubeNotifier();
});

/// YouTube notifier
class YouTubeNotifier extends StateNotifier<YouTubeState> {
  final YouTubeService _youtubeService = YouTubeService.instance;
  
  YouTubeNotifier() : super(const YouTubeState()) {
    _initialize();
  }

  /// Initialize the notifier
  Future<void> _initialize() async {
    await _youtubeService.initialize();
    
    // Load trending on startup
    await loadTrending();
    
    // Listen to YouTube service events
    _youtubeService.onSearchResults.listen((results) {
      state = state.copyWith(
        searchResults: results,
        isSearching: false,
      );
    });
    
    _youtubeService.onVideoInfo.listen((song) {
      // Handle video info if needed
    });
    
    _youtubeService.onError.listen((error) {
      state = state.copyWith(error: error);
    });
  }

  /// Search for videos
  Future<void> search(String query) async {
    state = state.copyWith(
      isSearching: true,
      isLoading: true,
      query: query,
      error: null,
    );
    
    try {
      final results = await _youtubeService.search(query);
      state = state.copyWith(
        searchResults: results,
        isSearching: false,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSearching: false,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Load trending videos
  Future<void> loadTrending() async {
    state = state.copyWith(
      isLoading: true,
      error: null,
    );
    
    try {
      final trending = await _youtubeService.getTrending();
      state = state.copyWith(
        trending: trending,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Get video info
  Future<Song?> getVideoInfo(String videoId) async {
    try {
      return await _youtubeService.getVideoInfo(videoId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get audio stream URL
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      return await _youtubeService.getAudioStreamUrl(videoId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get thumbnail URL
  Future<String?> getThumbnailUrl(String videoId) async {
    try {
      return await _youtubeService.getThumbnailUrl(videoId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  /// Get suggested videos
  Future<void> loadSuggestions(String videoId) async {
    try {
      final suggestions = await _youtubeService.getSuggestedVideos(videoId);
      state = state.copyWith(suggestions: suggestions);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Get playlist videos
  Future<List<Song>> getPlaylistVideos(String playlistId) async {
    try {
      return await _youtubeService.getPlaylistVideos(playlistId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Search for playlists
  Future<List<Map<String, dynamic>>> searchPlaylists(String query) async {
    try {
      return await _youtubeService.searchPlaylists(query);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return [];
    }
  }

  /// Clear search results
  void clearSearchResults() {
    state = state.copyWith(
      searchResults: [],
      query: null,
    );
  }

  @override
  void dispose() {
    _youtubeService.dispose();
    super.dispose();
  }
}
