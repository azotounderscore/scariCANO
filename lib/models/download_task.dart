import 'package:flutter/material.dart';
import 'song.dart';

/// Audio format enum for download
enum AudioFormat {
  mp3,
  m4a,
  original,
}

/// Extension for AudioFormat display
extension AudioFormatExtension on AudioFormat {
  String get displayName {
    switch (this) {
      case AudioFormat.mp3:
        return 'MP3';
      case AudioFormat.m4a:
        return 'M4A (AAC)';
      case AudioFormat.original:
        return 'Originale';
    }
  }

  String get fileExtension {
    switch (this) {
      case AudioFormat.mp3:
        return '.mp3';
      case AudioFormat.m4a:
        return '.m4a';
      case AudioFormat.original:
        return '';
    }
  }

  String get mimeType {
    switch (this) {
      case AudioFormat.mp3:
        return 'audio/mpeg';
      case AudioFormat.m4a:
        return 'audio/mp4';
      case AudioFormat.original:
        return 'audio/*';
    }
  }
}

/// Download task model for tracking active and completed downloads
class DownloadTask {
  final String id;
  final String url;
  final String destinationUri;
  final String fileName;
  DownloadStatus status;
  double progress;
  String? error;
  DateTime? createdAt;
  DateTime? completedAt;
  int? totalBytes;
  int? downloadedBytes;
  String? songId;
  String? title;
  String? artist;
  String? thumbnailUrl;
  final AudioFormat format;
  String? tempFilePath;

  DownloadTask({
    required this.id,
    required this.url,
    required this.destinationUri,
    required this.fileName,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.error,
    this.createdAt,
    this.completedAt,
    this.totalBytes,
    this.downloadedBytes,
    this.songId,
    this.title,
    this.artist,
    this.thumbnailUrl,
    this.format = AudioFormat.original,
    this.tempFilePath,
  });

  /// Create a new task from YouTube video
  factory DownloadTask.fromYouTube({
    required String videoId,
    required String url,
    required String destinationUri,
    required String fileName,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat format = AudioFormat.mp3,
  }) {
    return DownloadTask(
      id: 'download_${DateTime.now().millisecondsSinceEpoch}_$videoId',
      url: url,
      destinationUri: destinationUri,
      fileName: _getFileNameWithExtension(fileName, format),
      title: title,
      artist: artist,
      thumbnailUrl: thumbnailUrl,
      createdAt: DateTime.now(),
      format: format,
    );
  }

  /// Create a new task from direct URL
  factory DownloadTask.fromUrl({
    required String url,
    required String destinationUri,
    required String fileName,
    AudioFormat format = AudioFormat.original,
  }) {
    return DownloadTask(
      id: 'download_${DateTime.now().millisecondsSinceEpoch}_${url.hashCode}',
      url: url,
      destinationUri: destinationUri,
      fileName: _getFileNameWithExtension(fileName, format),
      createdAt: DateTime.now(),
      format: format,
    );
  }

  static String _getFileNameWithExtension(String fileName, AudioFormat format) {
    if (format == AudioFormat.original) return fileName;
    if (fileName.toLowerCase().endsWith('.mp3') && format == AudioFormat.mp3) return fileName;
    if (fileName.toLowerCase().endsWith('.m4a') && format == AudioFormat.m4a) return fileName;
    
    // Remove existing extension
    final baseName = fileName.contains('.') 
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    
    return '$baseName${format.fileExtension}';
  }

  /// Check if download is active (running or paused)
  bool get isActive => status == DownloadStatus.running || status == DownloadStatus.paused;

  /// Check if download is finished (completed, failed, or cancelled)
  bool get isFinished => status == DownloadStatus.completed || 
                        status == DownloadStatus.failed || 
                        status == DownloadStatus.cancelled;

  /// Check if conversion is needed
  bool get needsConversion => format != AudioFormat.original;

  /// Get progress percentage as integer
  int get progressPercentage => (progress * 100).toInt();

  /// Get remaining bytes to download
  int? get remainingBytes {
    if (totalBytes == null || downloadedBytes == null) return null;
    return totalBytes! - downloadedBytes!;
  }

  /// Get estimated time remaining (in seconds)
  Duration? get estimatedTimeRemaining {
    // This would require download speed tracking
    return null;
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'destinationUri': destinationUri,
      'fileName': fileName,
      'status': status.name,
      'progress': progress,
      'error': error,
      'createdAt': createdAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'totalBytes': totalBytes,
      'downloadedBytes': downloadedBytes,
      'songId': songId,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'format': format.name,
      'tempFilePath': tempFilePath,
    };
  }

  /// Create from JSON
  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      destinationUri: json['destinationUri'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      status: DownloadStatus.values.firstWhere(
        (e) => e.name == json['status'] as String?,
        orElse: () => DownloadStatus.pending,
      ),
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      error: json['error'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt'] as String) : null,
      totalBytes: json['totalBytes'] as int?,
      downloadedBytes: json['downloadedBytes'] as int?,
      songId: json['songId'] as String?,
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      format: AudioFormat.values.firstWhere(
        (e) => e.name == json['format'] as String?,
        orElse: () => AudioFormat.original,
      ),
      tempFilePath: json['tempFilePath'] as String?,
    );
  }

  /// Copy with new values
  DownloadTask copyWith({
    String? id,
    String? url,
    String? destinationUri,
    String? fileName,
    DownloadStatus? status,
    double? progress,
    String? error,
    DateTime? createdAt,
    DateTime? completedAt,
    int? totalBytes,
    int? downloadedBytes,
    String? songId,
    String? title,
    String? artist,
    String? thumbnailUrl,
    AudioFormat? format,
    String? tempFilePath,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      destinationUri: destinationUri ?? this.destinationUri,
      fileName: fileName ?? this.fileName,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      songId: songId ?? this.songId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      format: format ?? this.format,
      tempFilePath: tempFilePath ?? this.tempFilePath,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is DownloadTask && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Download status enum
enum DownloadStatus {
  pending,
  running,
  paused,
  completed,
  failed,
  cancelled,
  converting,
}

/// Extension to convert DownloadStatus to string for display
extension DownloadStatusExtension on DownloadStatus {
  String get displayName {
    switch (this) {
      case DownloadStatus.pending:
        return 'In attesa';
      case DownloadStatus.running:
        return 'In corso';
      case DownloadStatus.paused:
        return 'In pausa';
      case DownloadStatus.completed:
        return 'Completato';
      case DownloadStatus.failed:
        return 'Errore';
      case DownloadStatus.cancelled:
        return 'Annullato';
      case DownloadStatus.converting:
        return 'Conversione...';
    }
  }

  Color get statusColor {
    switch (this) {
      case DownloadStatus.pending:
        return const Color(0xFFB3B3B3);
      case DownloadStatus.running:
      case DownloadStatus.converting:
        return const Color(0xFFFF9800);
      case DownloadStatus.paused:
        return const Color(0xFFB3B3B3);
      case DownloadStatus.completed:
        return const Color(0xFF4CAF50);
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return const Color(0xFFF44336);
    }
  }
}
