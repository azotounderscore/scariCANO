import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Service for Storage Access Framework (SAF) operations
/// Handles communication with native Kotlin code for USB/OTG/SD card access
class SafService {
  static const String _channelName = 'com.scaricano/saf';
  static const MethodChannel _channel = MethodChannel(_channelName);
  
  // Stream controllers for callbacks
  final StreamController<String> _onDirectorySelectedController = StreamController.broadcast();
  final StreamController<String> _onFileCreatedController = StreamController.broadcast();
  
  /// Stream for directory selection callback
  Stream<String> get onDirectorySelected => _onDirectorySelectedController.stream;
  
  /// Stream for file creation callback
  Stream<String> get onFileCreated => _onFileCreatedController.stream;

  /// Private constructor
  SafService._();
  
  /// Singleton instance
  static final SafService instance = SafService._();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      // No initialization needed for method channel
    } catch (e) {
      rethrow;
    }
  }

  /// Open directory picker for user to select a folder
  Future<void> openDirectoryPicker() async {
    try {
      await _channel.invokeMethod('openDirectoryPicker');
    } on PlatformException catch (e) {
      throw SafException('Errore nell\'apertura del selettore cartelle: ${e.message}');
    }
  }

  /// Get available space in bytes for a URI
  Future<int> getAvailableSpace(String uriString) async {
    try {
      final space = await _channel.invokeMethod('getAvailableSpace', {
        'uri': uriString,
      });
      return space as int;
    } on PlatformException catch (e) {
      throw SafException('Errore nel recupero spazio disponibile: ${e.message}');
    }
  }

  /// Check if a URI is still valid
  Future<bool> isUriValid(String uriString) async {
    try {
      final isValid = await _channel.invokeMethod('isUriValid', {
        'uri': uriString,
      });
      return isValid as bool;
    } on PlatformException catch (e) {
      return false;
    }
  }

  /// Get display name for a URI
  Future<String> getDisplayName(String uriString) async {
    try {
      final displayName = await _channel.invokeMethod('getDisplayName', {
        'uri': uriString,
      });
      return displayName as String;
    } on PlatformException catch (e) {
      return uriString.split('/').last;
    }
  }

  /// Take persistable URI permission
  Future<bool> takePersistablePermission(String uriString) async {
    try {
      final success = await _channel.invokeMethod('takePersistablePermission', {
        'uri': uriString,
      });
      return success as bool;
    } on PlatformException catch (e) {
      return false;
    }
  }

  /// List all files in a directory
  Future<List<String>> listFiles(String uriString) async {
    try {
      final files = await _channel.invokeMethod('listFiles', {
        'uri': uriString,
      });
      return (files as List<dynamic>).map((e) => e as String).toList();
    } on PlatformException catch (e) {
      throw SafException('Errore nella lettura della cartella: ${e.message}');
    }
  }

  /// Check if a URI is a directory
  Future<bool> isDirectory(String uriString) async {
    try {
      final isDir = await _channel.invokeMethod('isDirectory', {
        'uri': uriString,
      });
      return isDir as bool;
    } on PlatformException catch (e) {
      return false;
    }
  }

  /// Revoke access to a URI
  Future<void> revokeAccess(String uriString) async {
    try {
      await _channel.invokeMethod('revokeAccess', {
        'uri': uriString,
      });
    } on PlatformException catch (e) {
      // Ignore errors
    }
  }

  /// Save file from local path to SAF URI
  Future<bool> saveFileFromPath(String localPath, String destinationUri, String fileName) async {
    try {
      final result = await _channel.invokeMethod('saveFileFromPath', {
        'localPath': localPath,
        'destinationUri': destinationUri,
        'fileName': fileName,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw SafException('Errore nel salvataggio file: ${e.message}');
    }
  }

  /// Download from URL to SAF URI with progress
  Future<bool> downloadToSaf(
    String url,
    String destinationUri,
    String fileName, {
    Function(int downloaded, int total)? onProgress,
  }) async {
    try {
      // Fallback implementation using Dio + SAF
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName.tmp');
      
      // Download using Dio
      final dio = Dio();
      
      final response = await dio.get(
        url,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
        ),
        onReceiveProgress: onProgress,
      );
      
      // Write to temp file
      final sink = tempFile.openWrite();
      final stream = response.data as Stream<List<int>>;
      await stream.pipe(sink);
      await sink.close();
      
      // Save to SAF
      final success = await saveFileFromPath(
        tempFile.path,
        destinationUri,
        fileName,
      );
      
      // Cleanup temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      
      return success;
      
    } catch (e) {
      throw SafException('Errore nel download: ${e.toString()}');
    }
  }

  /// Delete a file from SAF URI
  Future<bool> deleteFile(String parentUri, String fileName) async {
    try {
      final result = await _channel.invokeMethod('deleteFile', {
        'parentUri': parentUri,
        'fileName': fileName,
      });
      return result as bool;
    } on PlatformException catch (e) {
      throw SafException('Errore nella cancellazione file: ${e.message}');
    }
  }

  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Dispose the service
  void dispose() {
    _onDirectorySelectedController.close();
    _onFileCreatedController.close();
  }
}

/// Custom exception for SAF operations
class SafException implements Exception {
  final String message;
  
  const SafException(this.message);
  
  @override
  String toString() => 'SafException: $message';
}
