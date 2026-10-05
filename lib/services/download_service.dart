import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import '../models/download_task.dart';
import 'saf_service.dart';

/// Service for managing file downloads
/// Supports parallel downloads, pause/resume, format conversion, and progress tracking
class DownloadService {
  static const int _maxParallelDownloads = 3;
  static const int _chunkSize = 8192;
  
  final Dio _dio = Dio();
  final FlutterFFmpeg _ffmpeg = FlutterFFmpeg();
  final Map<String, DownloadTask> _activeDownloads = {};
  final List<DownloadTask> _queue = [];
  final List<DownloadTask> _completedDownloads = [];
  
  // Stream controllers
  final StreamController<DownloadTask> _downloadAddedController = StreamController.broadcast();
  final StreamController<DownloadTask> _downloadUpdatedController = StreamController.broadcast();
  final StreamController<DownloadTask> _downloadCompletedController = StreamController.broadcast();
  final StreamController<DownloadTask> _downloadFailedController = StreamController.broadcast();
  
  /// Stream for new downloads
  Stream<DownloadTask> get onDownloadAdded => _downloadAddedController.stream;
  
  /// Stream for download updates
  Stream<DownloadTask> get onDownloadUpdated => _downloadUpdatedController.stream;
  
  /// Stream for completed downloads
  Stream<DownloadTask> get onDownloadCompleted => _downloadCompletedController.stream;
  
  /// Stream for failed downloads
  Stream<DownloadTask> get onDownloadFailed => _downloadFailedController.stream;

  /// Private constructor
  DownloadService._();
  
  /// Singleton instance
  static final DownloadService instance = DownloadService._();

  /// Initialize the service
  Future<void> initialize() async {
    _dio.options = BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
    );
  }

  /// Get all active downloads
  List<DownloadTask> get activeDownloads => _activeDownloads.values.toList();

  /// Get all queued downloads
  List<DownloadTask> get queuedDownloads => _queue.toList();

  /// Get all completed downloads
  List<DownloadTask> get completedDownloads => _completedDownloads.toList();

  /// Get all downloads (active + queued + completed)
  List<DownloadTask> get allDownloads {
    return [...activeDownloads, ...queuedDownloads, ...completedDownloads];
  }

  /// Start a new download with format selection
  Future<DownloadTask> startDownload({
    required String url,
    required String destinationUri,
    required String fileName,
    String? songId,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat format = AudioFormat.mp3,
  }) async {
    // Check if already downloading
    for (final task in _activeDownloads.values) {
      if (task.url == url && task.destinationUri == destinationUri) {
        return task;
      }
    }
    
    for (final task in _queue) {
      if (task.url == url && task.destinationUri == destinationUri) {
        return task;
      }
    }

    // Apply format to fileName
    final formattedFileName = _applyFormatToFileName(fileName, format);

    final task = DownloadTask.fromUrl(
      url: url,
      destinationUri: destinationUri,
      fileName: formattedFileName,
      format: format,
    ).copyWith(
      songId: songId,
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
    );

    // Check available space
    try {
      final safService = SafService.instance;
      final availableSpace = await safService.getAvailableSpace(destinationUri);
      
      // Estimate required space (add 50% buffer for conversion)
      final estimatedSize = _estimateDownloadSize(url, format);
      if (availableSpace < estimatedSize * 1.5) {
        throw Exception('Spazio insufficiente: servono ~${(estimatedSize / (1024 * 1024)).toStringAsFixed(1)} MB');
      }
    } catch (e) {
      // Add error to task but continue
      _downloadAddedController.add(task.copyWith(error: e.toString()));
    }

    // If we have space for parallel downloads, start immediately
    if (_activeDownloads.length < _maxParallelDownloads) {
      _startTask(task);
    } else {
      // Otherwise, add to queue
      _queue.add(task);
    }

    _downloadAddedController.add(task);
    return task;
  }

  /// Start a YouTube download with format selection
  Future<DownloadTask> startYouTubeDownload({
    required String videoId,
    required String url,
    required String destinationUri,
    required String fileName,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat format = AudioFormat.mp3,
  }) async {
    return startDownload(
      url: url,
      destinationUri: destinationUri,
      fileName: fileName,
      songId: 'yt_$videoId',
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      format: format,
    );
  }

  /// Apply format extension to fileName
  String _applyFormatToFileName(String fileName, AudioFormat format) {
    if (format == AudioFormat.original) return fileName;
    
    // Remove existing audio extensions
    final baseName = fileName.toLowerCase()
        .replaceAll(RegExp(r'\.(mp3|m4a|aac|wav|flac|ogg|opus)$'), '');
    
    return '$baseName${format.fileExtension}';
  }

  /// Estimate download size based on URL and format
  int _estimateDownloadSize(String url, AudioFormat format) {
    // Default estimate: 5MB for audio files
    // YouTube audio streams are typically 5-10MB for 3-5 minute songs
    const defaultSize = 5 * 1024 * 1024; // 5MB
    
    // If converting to MP3, estimate might be smaller
    if (format == AudioFormat.mp3) {
      return (defaultSize * 0.8).toInt(); // MP3 is typically smaller
    }
    
    return defaultSize;
  }

  /// Pause a download
  Future<bool> pauseDownload(String downloadId) async {
    final task = _activeDownloads[downloadId];
    if (task != null && task.status == DownloadStatus.running) {
      _activeDownloads[downloadId] = task.copyWith(status: DownloadStatus.paused);
      _downloadUpdatedController.add(_activeDownloads[downloadId]!);
      return true;
    }
    return false;
  }

  /// Resume a paused download
  Future<bool> resumeDownload(String downloadId) async {
    // Check if paused
    final activeTask = _activeDownloads[downloadId];
    if (activeTask != null && activeTask.status == DownloadStatus.paused) {
      activeTask.status = DownloadStatus.running;
      _downloadUpdatedController.add(activeTask);
      return true;
    }
    
    // Check queue
    final index = _queue.indexWhere((t) => t.id == downloadId);
    if (index >= 0) {
      final task = _queue.removeAt(index);
      _startTask(task);
      return true;
    }
    return false;
  }

  /// Cancel a download
  Future<bool> cancelDownload(String downloadId) async {
    // Check active downloads
    final activeTask = _activeDownloads[downloadId];
    if (activeTask != null) {
      await _cancelDownloadInternal(activeTask, cancelled: true);
      return true;
    }
    
    // Check queued downloads
    final queueIndex = _queue.indexWhere((t) => t.id == downloadId);
    if (queueIndex >= 0) {
      final task = _queue.removeAt(queueIndex);
      _downloadUpdatedController.add(task.copyWith(status: DownloadStatus.cancelled));
      return true;
    }
    
    return false;
  }

  /// Remove a completed download
  Future<bool> removeDownload(String downloadId) async {
    final index = _completedDownloads.indexWhere((t) => t.id == downloadId);
    if (index >= 0) {
      final task = _completedDownloads.removeAt(index);
      // Also delete the file via SAF
      try {
        await SafService.instance.deleteFile(task.destinationUri, task.fileName);
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }
      return true;
    }
    return false;
  }

  /// Clear all completed downloads
  Future<void> clearCompletedDownloads() async {
    _completedDownloads.clear();
  }

  /// Clear all downloads
  Future<void> clearAllDownloads() async {
    // Cancel active downloads
    for (final task in _activeDownloads.values.toList()) {
      await cancelDownload(task.id);
    }
    
    // Clear queue
    _queue.clear();
    
    // Clear completed
    _completedDownloads.clear();
  }

  /// Get download by ID
  DownloadTask? getDownload(String downloadId) {
    return _activeDownloads[downloadId] ?:
           _queue.firstWhere((t) => t.id == downloadId, orElse: () => null) ?:
           _completedDownloads.firstWhere((t) => t.id == downloadId, orElse: () => null);
  }

  /// Get download status
  DownloadStatus? getDownloadStatus(String downloadId) {
    return getDownload(downloadId)?.status;
  }

  /// Get download progress
  double getDownloadProgress(String downloadId) {
    return getDownload(downloadId)?.progress ?? 0.0;
  }

  /// Start a queued task if there's space
  void _tryStartQueuedTask() {
    if (_queue.isNotEmpty && _activeDownloads.length < _maxParallelDownloads) {
      final task = _queue.removeAt(0);
      _startTask(task);
    }
  }

  /// Start a download task
  Future<void> _startTask(DownloadTask task) async {
    // Update status to running
    _activeDownloads[task.id] = task.copyWith(
      status: DownloadStatus.running,
      downloadedBytes: task.downloadedBytes ?? 0,
    );
    
    _downloadUpdatedController.add(_activeDownloads[task.id]!);

    try {
      // Get file info
      final response = await _dio.head(task.url);
      final totalBytes = int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      final acceptRanges = response.headers.value('accept-ranges') == 'bytes';
      
      // Update task with total bytes
      _activeDownloads[task.id] = task.copyWith(
        totalBytes: totalBytes,
        downloadedBytes: task.downloadedBytes ?? 0,
      );
      _downloadUpdatedController.add(_activeDownloads[task.id]!);

      // Create temp file for download (needed for conversion)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${task.id}.tmp');
      
      // Download the file using native SAF service
      final safService = SafService.instance;
      final destinationFileName = task.fileName;
      
      // For format conversion, we need to download to temp first
      if (task.needsConversion) {
        // Download to temp file
        await _downloadToFile(task.url, tempFile.path!, task, onProgress: (downloaded, total) {
          _activeDownloads[task.id] = task.copyWith(
            downloadedBytes: downloaded,
            totalBytes: total,
            progress: total > 0 ? downloaded / total : 0.0,
          );
          _downloadUpdatedController.add(_activeDownloads[task.id]!);
        });
        
        if (_activeDownloads[task.id]?.status == DownloadStatus.cancelled) {
          // Cleanup temp file
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
          return;
        }
        
        // Convert format
        _activeDownloads[task.id] = task.copyWith(
          status: DownloadStatus.converting,
          tempFilePath: tempFile.path,
        );
        _downloadUpdatedController.add(_activeDownloads[task.id]!);
        
        final convertedFile = File('${tempDir.path}/${task.id}_converted${task.format.fileExtension}');
        
        // Use ffmpeg for conversion
        final convertResult = await _convertAudioFormat(
          tempFile.path!,
          convertedFile.path,
          task.format,
        );
        
        if (!convertResult) {
          throw Exception('Conversione formato fallita');
        }
        
        // Save converted file to destination via SAF
        await safService.saveFileFromPath(
          convertedFile.path,
          task.destinationUri,
          destinationFileName,
        );
        
        // Cleanup temp files
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
        if (await convertedFile.exists()) {
          await convertedFile.delete();
        }
      } else {
        // Direct download to destination via SAF
        // For now, simulate download with SAF
        await safService.downloadToSaf(
          task.url,
          task.destinationUri,
          destinationFileName,
          onProgress: (downloaded, total) {
            _activeDownloads[task.id] = task.copyWith(
              downloadedBytes: downloaded,
              totalBytes: total,
              progress: total > 0 ? downloaded / total : 0.0,
            );
            _downloadUpdatedController.add(_activeDownloads[task.id]!);
          },
        );
      }

      // Check if still active (not cancelled)
      if (_activeDownloads[task.id]?.status != DownloadStatus.cancelled) {
        _completeTask(task);
      } else {
        // Cleanup if cancelled during conversion
        if (task.tempFilePath != null) {
          final tempFile = File(task.tempFilePath!);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }

    } catch (e) {
      debugPrint('Download failed: $e');
      
      _activeDownloads[task.id] = task.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      _downloadFailedController.add(_activeDownloads[task.id]!);
      _activeDownloads.remove(task.id);
      _tryStartQueuedTask();
      
      // Cleanup temp file if exists
      if (task.tempFilePath != null) {
        final tempFile = File(task.tempFilePath!);
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }
    }
  }

  /// Download file to local path
  Future<void> _downloadToFile(
    String url,
    String savePath,
    DownloadTask task,
    {required Function(int downloaded, int total) onProgress},
  ) async {
    final file = File(savePath);
    
    // Check if resume is possible
    int startByte = 0;
    if (await file.exists()) {
      startByte = await file.length();
    }
    
    // Open file for writing
    final sink = file.openWrite(mode: FileMode.append);
    
    try {
      final response = await _dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Range': 'bytes=$startByte-'},
        ),
        onReceiveProgress: (received, total) {
          onProgress(startByte + received, startByte + total);
        },
      );
      
      // Write to file
      final stream = response.data as Stream<List<int>>;
      await stream.pipe(sink);
      
      await sink.close();
      
    } catch (e) {
      await sink.close();
      rethrow;
    }
  }

  /// Convert audio format using ffmpeg
  Future<bool> _convertAudioFormat(String inputPath, String outputPath, AudioFormat format) async {
    try {
      final command = switch (format) {
        AudioFormat.mp3 => '-i "$inputPath" -codec:a libmp3lame -q:a 2 "$outputPath"',
        AudioFormat.m4a => '-i "$inputPath" -codec:a aac -b:a 192k "$outputPath"',
        _ => '-i "$inputPath" -c copy "$outputPath"',
      };
      
      debugPrint('FFmpeg command: ffmpeg $command');
      
      // Execute ffmpeg
      await _ffmpeg.execute(command);
      
      // Check if output file exists
      final outputFile = File(outputPath);
      return await outputFile.exists();
      
    } catch (e) {
      debugPrint('FFmpeg conversion error: $e');
      return false;
    }
  }

  /// Complete a download task
  void _completeTask(DownloadTask task) {
    _activeDownloads.remove(task.id);
    
    final completedTask = task.copyWith(
      status: DownloadStatus.completed,
      progress: 1.0,
      completedAt: DateTime.now(),
      tempFilePath: null, // Cleanup reference
    );
    
    _completedDownloads.add(completedTask);
    _downloadCompletedController.add(completedTask);
    
    // Start next queued task
    _tryStartQueuedTask();
  }

  /// Cancel a download internally
  Future<void> _cancelDownloadInternal(DownloadTask task, {bool cancelled = false}) async {
    _activeDownloads.remove(task.id);
    
    final updatedTask = task.copyWith(
      status: cancelled ? DownloadStatus.cancelled : DownloadStatus.failed,
    );
    
    _downloadUpdatedController.add(updatedTask);
    
    if (cancelled) {
      _downloadFailedController.add(updatedTask);
    }
    
    // Cleanup temp file
    if (task.tempFilePath != null) {
      final tempFile = File(task.tempFilePath!);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
    
    // Start next queued task
    _tryStartQueuedTask();
  }

  /// Dispose the service
  void dispose() {
    _downloadAddedController.close();
    _downloadUpdatedController.close();
    _downloadCompletedController.close();
    _downloadFailedController.close();
    _dio.close();
  }
}
