import 'package:flutter/material.dart';

/// Song model representing a music track with metadata
class Song {
  final String id;
  final String title;
  final String artist;
  final String? album;
  final String? albumArtUrl;
  final String uri; // URI from SAF (content://...)
  final Duration duration;
  final int? trackNumber;
  final DateTime? dateAdded;
  final DateTime? dateModified;
  final int? fileSize;
  final String? genre;
  final int? year;
  final Map<String, String>? metadata;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album,
    this.albumArtUrl,
    required this.uri,
    required this.duration,
    this.trackNumber,
    this.dateAdded,
    this.dateModified,
    this.fileSize,
    this.genre,
    this.year,
    this.metadata,
  });

  /// Create a Song from a file URI (for library scanning)
  factory Song.fromUri({
    required String uri,
    required String title,
    required String artist,
    Duration? duration,
    String? album,
    String? albumArtUrl,
    int? fileSize,
    DateTime? dateAdded,
    DateTime? dateModified,
  }) {
    return Song(
      id: uri.hashCode.toString(),
      title: title,
      artist: artist,
      album: album,
      albumArtUrl: albumArtUrl,
      uri: uri,
      duration: duration ?? const Duration(seconds: 0),
      fileSize: fileSize,
      dateAdded: dateAdded,
      dateModified: dateModified,
    );
  }

  /// Create a Song from YouTube video info
  factory Song.fromYouTube({
    required String videoId,
    required String title,
    required String artist,
    String? album,
    String? thumbnailUrl,
    required Duration duration,
  }) {
    return Song(
      id: 'yt_$videoId',
      title: title,
      artist: artist,
      album: album,
      albumArtUrl: thumbnailUrl,
      uri: 'https://www.youtube.com/watch?v=$videoId',
      duration: duration,
    );
  }

  /// Check if this song is from YouTube
  bool get isFromYouTube => uri.startsWith('https://www.youtube.com') || uri.startsWith('https://youtu.be');

  /// Get the file extension from URI
  String? get fileExtension {
    if (uri.contains('.')) {
      return uri.substring(uri.lastIndexOf('.'));
    }
    return null;
  }

  /// Get a display name for the song
  String get displayName => '$title - $artist';

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtUrl': albumArtUrl,
      'uri': uri,
      'duration': duration.inMilliseconds,
      'trackNumber': trackNumber,
      'dateAdded': dateAdded?.toIso8601String(),
      'dateModified': dateModified?.toIso8601String(),
      'fileSize': fileSize,
      'genre': genre,
      'year': year,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Sconosciuto',
      artist: json['artist'] as String? ?? 'Sconosciuto',
      album: json['album'] as String?,
      albumArtUrl: json['albumArtUrl'] as String?,
      uri: json['uri'] as String? ?? '',
      duration: Duration(milliseconds: json['duration'] as int? ?? 0),
      trackNumber: json['trackNumber'] as int?,
      dateAdded: json['dateAdded'] != null ? DateTime.parse(json['dateAdded'] as String) : null,
      dateModified: json['dateModified'] != null ? DateTime.parse(json['dateModified'] as String) : null,
      fileSize: json['fileSize'] as int?,
      genre: json['genre'] as String?,
      year: json['year'] as int?,
      metadata: json['metadata'] as Map<String, String>?,
    );
  }

  /// Copy with new values
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? albumArtUrl,
    String? uri,
    Duration? duration,
    int? trackNumber,
    DateTime? dateAdded,
    DateTime? dateModified,
    int? fileSize,
    String? genre,
    int? year,
    Map<String, String>? metadata,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtUrl: albumArtUrl ?? this.albumArtUrl,
      uri: uri ?? this.uri,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      fileSize: fileSize ?? this.fileSize,
      genre: genre ?? this.genre,
      year: year ?? this.year,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Song queue item for playback
class QueueItem {
  final Song song;
  final int? index;
  final DateTime? addedAt;

  const QueueItem({
    required this.song,
    this.index,
    this.addedAt,
  });

  factory QueueItem.fromSong(Song song, {int? index}) {
    return QueueItem(
      song: song,
      index: index,
      addedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is QueueItem && other.song == song && other.index == index;

  @override
  int get hashCode => song.hashCode ^ index.hashCode;
}

/// Repeat mode enum
enum RepeatMode {
  none,
  one,
  all,
}

/// Extension for RepeatMode display
extension RepeatModeExtension on RepeatMode {
  String get displayName {
    switch (this) {
      case RepeatMode.none:
        return 'Nessuna ripetizione';
      case RepeatMode.one:
        return 'Ripeti uno';
      case RepeatMode.all:
        return 'Ripeti tutti';
    }
  }

  IconData get icon {
    switch (this) {
      case RepeatMode.none:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
      case RepeatMode.all:
        return Icons.repeat;
    }
  }
}

/// Playback queue model
class PlaybackQueue {
  final List<String> songIds;
  final int currentIndex;
  final bool isShuffled;
  final RepeatMode repeatMode;
  final DateTime? createdAt;

  const PlaybackQueue({
    this.songIds = const [],
    this.currentIndex = 0,
    this.isShuffled = false,
    this.repeatMode = RepeatMode.none,
    this.createdAt,
  });

  /// Get the current song ID
  String? get currentSongId {
    if (songIds.isEmpty || currentIndex < 0 || currentIndex >= songIds.length) {
      return null;
    }
    return songIds[currentIndex];
  }

  /// Get the next song ID
  String? get nextSongId {
    if (songIds.isEmpty) return null;

    if (isShuffled) {
      final nextIndex = (currentIndex + 1) % songIds.length;
      return songIds[nextIndex];
    } else {
      if (currentIndex < songIds.length - 1) {
        return songIds[currentIndex + 1];
      } else if (repeatMode == RepeatMode.all) {
        return songIds[0];
      }
    }
    return null;
  }

  /// Get the previous song ID
  String? get previousSongId {
    if (songIds.isEmpty) return null;

    if (isShuffled) {
      final prevIndex = (currentIndex - 1 + songIds.length) % songIds.length;
      return songIds[prevIndex];
    } else {
      if (currentIndex > 0) {
        return songIds[currentIndex - 1];
      } else if (repeatMode == RepeatMode.all) {
        return songIds.last;
      }
    }
    return null;
  }

  /// Add a song to the queue
  PlaybackQueue addSong(String songId) {
    return PlaybackQueue(
      songIds: [...songIds, songId],
      currentIndex: currentIndex,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Add multiple songs to the queue
  PlaybackQueue addSongs(List<String> songIds) {
    return PlaybackQueue(
      songIds: [...this.songIds, ...songIds],
      currentIndex: currentIndex,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Remove a song from the queue
  PlaybackQueue removeSong(String songId) {
    final newSongIds = songIds.where((id) => id != songId).toList();
    var newIndex = currentIndex;

    if (currentIndex >= newSongIds.length) {
      newIndex = newSongIds.length - 1;
    }

    return PlaybackQueue(
      songIds: newSongIds,
      currentIndex: newIndex,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Clear the queue
  PlaybackQueue clear() {
    return const PlaybackQueue(
      songIds: [],
      currentIndex: 0,
    );
  }

  /// Skip to next song
  PlaybackQueue next() {
    if (songIds.isEmpty) return this;

    final nextIndex = if (isShuffled) {
      (currentIndex + 1) % songIds.length
    } else {
      if (currentIndex < songIds.length - 1) {
        currentIndex + 1
      } else if (repeatMode == RepeatMode.all) {
        0
      } else {
        currentIndex
      }
    };

    return PlaybackQueue(
      songIds: songIds,
      currentIndex: nextIndex,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Skip to previous song
  PlaybackQueue previous() {
    if (songIds.isEmpty) return this;

    final prevIndex = if (isShuffled) {
      (currentIndex - 1 + songIds.length) % songIds.length
    } else {
      if (currentIndex > 0) {
        currentIndex - 1
      } else if (repeatMode == RepeatMode.all) {
        songIds.length - 1
      } else {
        currentIndex
      }
    };

    return PlaybackQueue(
      songIds: songIds,
      currentIndex: prevIndex,
      isShuffled: isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Toggle shuffle
  PlaybackQueue toggleShuffle() {
    return PlaybackQueue(
      songIds: songIds,
      currentIndex: currentIndex,
      isShuffled: !isShuffled,
      repeatMode: repeatMode,
      createdAt: createdAt,
    );
  }

  /// Set repeat mode
  PlaybackQueue setRepeatMode(RepeatMode mode) {
    return PlaybackQueue(
      songIds: songIds,
      currentIndex: currentIndex,
      isShuffled: isShuffled,
      repeatMode: mode,
      createdAt: createdAt,
    );
  }

  /// Convert to Map for serialization
  Map<String, dynamic> toJson() {
    return {
      'songIds': songIds,
      'currentIndex': currentIndex,
      'isShuffled': isShuffled,
      'repeatMode': repeatMode.name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory PlaybackQueue.fromJson(Map<String, dynamic> json) {
    return PlaybackQueue(
      songIds: (json['songIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      currentIndex: json['currentIndex'] as int? ?? 0,
      isShuffled: json['isShuffled'] as bool? ?? false,
      repeatMode: RepeatMode.values.firstWhere(
        (e) => e.name == json['repeatMode'] as String?,
        orElse: () => RepeatMode.none,
      ),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
    );
  }

  @override
  bool operator ==(Object other) => identical(this, other) || 
      other is PlaybackQueue && 
      other.songIds == songIds && 
      other.currentIndex == currentIndex &&
      other.isShuffled == isShuffled &&
      other.repeatMode == repeatMode;

  @override
  int get hashCode => songIds.hashCode ^ currentIndex.hashCode ^ isShuffled.hashCode ^ repeatMode.hashCode;
}
