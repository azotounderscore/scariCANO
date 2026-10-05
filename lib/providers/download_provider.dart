import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_task.dart';
import '../services/download_service.dart';

/// Download state
@immutable
class DownloadState {
  final List<DownloadTask> activeDownloads;
  final List<DownloadTask> queuedDownloads;
  final List<DownloadTask> completedDownloads;
  final bool isDownloading;
  final String? error;
  final AudioFormat defaultFormat;

  const DownloadState({
    this.activeDownloads = const [],
    this.queuedDownloads = const [],
    this.completedDownloads = const [],
    this.isDownloading = false,
    this.error = null,
    this.defaultFormat = AudioFormat.mp3,
  });

  DownloadState copyWith({
    List<DownloadTask>? activeDownloads,
    List<DownloadTask>? queuedDownloads,
    List<DownloadTask>? completedDownloads,
    bool? isDownloading,
    String? error,
    AudioFormat? defaultFormat,
  }) {
    return DownloadState(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      queuedDownloads: queuedDownloads ?? this.queuedDownloads,
      completedDownloads: completedDownloads ?? this.completedDownloads,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error ?? this.error,
      defaultFormat: defaultFormat ?? this.defaultFormat,
    );
  }

  List<DownloadTask> get allDownloads => [...activeDownloads, ...queuedDownloads, ...completedDownloads];
  bool get hasActiveDownloads => activeDownloads.isNotEmpty;
  bool get hasQueuedDownloads => queuedDownloads.isNotEmpty;
  bool get hasCompletedDownloads => completedDownloads.isNotEmpty;
  bool get hasDownloads => allDownloads.isNotEmpty;
}

/// Download provider
final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier();
});

/// Download notifier
class DownloadNotifier extends StateNotifier<DownloadState> {
  static const String _prefsKey = 'default_download_format';
  
  final DownloadService _downloadService = DownloadService.instance;
  
  DownloadNotifier() : super(const DownloadState()) {
    _initialize();
  }

  /// Initialize the notifier
  Future<void> _initialize() async {
    await _downloadService.initialize();
    
    // Load default format from preferences
    await _loadDefaultFormat();
    
    // Listen to download service events
    _downloadService.onDownloadAdded.listen((task) {
      _updateDownloads();
    });
    
    _downloadService.onDownloadUpdated.listen((task) {
      _updateDownloads();
    });
    
    _downloadService.onDownloadCompleted.listen((task) {
      _updateDownloads();
    });
    
    _downloadService.onDownloadFailed.listen((task) {
      _updateDownloads();
    });
    
    // Initial update
    _updateDownloads();
  }

  /// Load default format from preferences
  Future<void> _loadDefaultFormat() async {
    final prefs = await SharedPreferences.getInstance();
    final formatName = prefs.getString(_prefsKey);
    
    if (formatName != null) {
      final format = AudioFormat.values.firstWhere(
        (e) => e.name == formatName,
        orElse: () => AudioFormat.mp3,
      );
      state = state.copyWith(defaultFormat: format);
    }
  }

  /// Update downloads from download service
  void _updateDownloads() {
    state = state.copyWith(
      activeDownloads: _downloadService.activeDownloads,
      queuedDownloads: _downloadService.queuedDownloads,
      completedDownloads: _downloadService.completedDownloads,
      isDownloading: _downloadService.activeDownloads.isNotEmpty,
    );
  }

  /// Set default format
  Future<void> setDefaultFormat(AudioFormat format) async {
    state = state.copyWith(defaultFormat: format);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, format.name);
  }

  /// Start a download
  Future<DownloadTask> startDownload({
    required String url,
    required String destinationUri,
    required String fileName,
    String? songId,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat? format,
  }) async {
    try {
      final effectiveFormat = format ?? state.defaultFormat;
      
      final task = await _downloadService.startDownload(
        url: url,
        destinationUri: destinationUri,
        fileName: fileName,
        songId: songId,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        format: effectiveFormat,
      );
      
      _updateDownloads();
      return task;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Start a YouTube download
  Future<DownloadTask> startYouTubeDownload({
    required String videoId,
    required String url,
    required String destinationUri,
    required String fileName,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat? format,
  }) async {
    try {
      final effectiveFormat = format ?? state.defaultFormat;
      
      final task = await _downloadService.startYouTubeDownload(
        videoId: videoId,
        url: url,
        destinationUri: destinationUri,
        fileName: fileName,
        title: title,
        artist: artist,
        thumbnailUrl: thumbnailUrl,
        format: effectiveFormat,
      );
      
      _updateDownloads();
      return task;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  /// Pause a download
  Future<bool> pauseDownload(String downloadId) async {
    try {
      final success = await _downloadService.pauseDownload(downloadId);
      if (success) {
        _updateDownloads();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Resume a download
  Future<bool> resumeDownload(String downloadId) async {
    try {
      final success = await _downloadService.resumeDownload(downloadId);
      if (success) {
        _updateDownloads();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Cancel a download
  Future<bool> cancelDownload(String downloadId) async {
    try {
      final success = await _downloadService.cancelDownload(downloadId);
      if (success) {
        _updateDownloads();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Remove a completed download
  Future<bool> removeDownload(String downloadId) async {
    try {
      final success = await _downloadService.removeDownload(downloadId);
      if (success) {
        _updateDownloads();
      }
      return success;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Clear all completed downloads
  Future<void> clearCompletedDownloads() async {
    try {
      await _downloadService.clearCompletedDownloads();
      _updateDownloads();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    try {
      await _downloadService.clearAllDownloads();
      _updateDownloads();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Get download by ID
  DownloadTask? getDownload(String downloadId) {
    return _downloadService.getDownload(downloadId);
  }

  /// Get download status
  DownloadStatus? getDownloadStatus(String downloadId) {
    return _downloadService.getDownloadStatus(downloadId);
  }

  /// Get download progress
  double getDownloadProgress(String downloadId) {
    return _downloadService.getDownloadProgress(downloadId);
  }

  @override
  void dispose() {
    _downloadService.dispose();
    super.dispose();
  }
}
