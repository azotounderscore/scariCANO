import 'package:flutter/material.dart';

/// Library folder model for tracking scanned directories
class LibraryFolder {
  final String uri;
  final String name;
  final String? path;
  final bool isWritable;
  final DateTime? lastScanned;
  final int songCount;
  final bool isScanning;
  final String? error;

  const LibraryFolder({
    required this.uri,
    required this.name,
    this.path,
    this.isWritable = false,
    this.lastScanned,
    this.songCount = 0,
    this.isScanning = false,
    this.error,
  });

  /// Create a folder from URI
  factory LibraryFolder.fromUri({
    required String uri,
    required String name,
    String? path,
    bool? isWritable,
  }) {
    return LibraryFolder(
      uri: uri,
      name: name,
      path: path,
      isWritable: isWritable ?? false,
      lastScanned: null,
      songCount: 0,
    );
  }

  /// Check if folder is currently being scanned
  bool get isCurrentlyScanning => isScanning;

  /// Check if folder has been scanned at least once
  bool get hasBeenScanned => lastScanned != null;

  /// Check if folder has songs
  bool get hasSongs => songCount > 0;

  /// Get display path (shortened if too long)
  String get displayPath {
    if (path == null) return name;
    if (path.length <= 40) return path;
    return '...${path.substring(path.length - 35)}';
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'uri': uri,
      'name': name,
      'path': path,
      'isWritable': isWritable,
      'lastScanned': lastScanned?.toIso8601String(),
      'songCount': songCount,
      'isScanning': isScanning,
      'error': error,
    };
  }

  /// Create from JSON
  factory LibraryFolder.fromJson(Map<String, dynamic> json) {
    return LibraryFolder(
      uri: json['uri'] as String? ?? '',
      name: json['name'] as String? ?? 'Nuova Cartella',
      path: json['path'] as String?,
      isWritable: json['isWritable'] as bool? ?? false,
      lastScanned: json['lastScanned'] != null ? DateTime.parse(json['lastScanned'] as String) : null,
      songCount: json['songCount'] as int? ?? 0,
      isScanning: json['isScanning'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  /// Copy with new values
  LibraryFolder copyWith({
    String? uri,
    String? name,
    String? path,
    bool? isWritable,
    DateTime? lastScanned,
    int? songCount,
    bool? isScanning,
    String? error,
  }) {
    return LibraryFolder(
      uri: uri ?? this.uri,
      name: name ?? this.name,
      path: path ?? this.path,
      isWritable: isWritable ?? this.isWritable,
      lastScanned: lastScanned ?? this.lastScanned,
      songCount: songCount ?? this.songCount,
      isScanning: isScanning ?? this.isScanning,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is LibraryFolder && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Scan status enum
enum ScanStatus {
  pending,
  scanning,
  completed,
  failed,
}

/// Scan progress model
class ScanProgress {
  final String folderUri;
  final ScanStatus status;
  final int filesScanned;
  final int filesFound;
  final int currentFile;
  final String? currentFileName;
  final String? error;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const ScanProgress({
    required this.folderUri,
    this.status = ScanStatus.scanning,
    this.filesScanned = 0,
    this.filesFound = 0,
    this.currentFile = 0,
    this.currentFileName,
    this.error,
    this.startedAt,
    this.completedAt,
  });

  /// Get progress percentage
  double get progress {
    if (filesScanned <= 0) return 0.0;
    return (filesFound / filesScanned).coerceIn(0.0, 1.0);
  }

  /// Check if scan is complete
  bool get isComplete => status == ScanStatus.completed || status == ScanStatus.failed;

  /// Get estimated time remaining (simplified)
  Duration? get estimatedTimeRemaining {
    // This would require tracking scan speed
    return null;
  }

  /// Copy with new values
  ScanProgress copyWith({
    String? folderUri,
    ScanStatus? status,
    int? filesScanned,
    int? filesFound,
    int? currentFile,
    String? currentFileName,
    String? error,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ScanProgress(
      folderUri: folderUri ?? this.folderUri,
      status: status ?? this.status,
      filesScanned: filesScanned ?? this.filesScanned,
      filesFound: filesFound ?? this.filesFound,
      currentFile: currentFile ?? this.currentFile,
      currentFileName: currentFileName ?? this.currentFileName,
      error: error ?? this.error,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is ScanProgress && other.folderUri == folderUri;

  @override
  int get hashCode => folderUri.hashCode;
}
