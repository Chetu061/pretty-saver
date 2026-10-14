import 'package:flutter/services.dart';

/// Progress update emitted by yt-dlp while a download runs.
class EngineProgress {
  const EngineProgress({
    required this.taskId,
    required this.percent,
    required this.etaSeconds,
    required this.line,
  });

  final String taskId;
  final double percent;
  final int etaSeconds;
  final String line;

  bool get isMerging => line.contains('[Merger]') || line.contains('[VideoConvertor]');
}

class SavedFile {
  const SavedFile({required this.uri, required this.fileName, required this.size});

  final String uri;
  final String fileName;
  final int size;

  factory SavedFile.fromMap(Map map) => SavedFile(
        uri: map['uri'] as String,
        fileName: map['fileName'] as String,
        size: (map['size'] as num).toInt(),
      );

  Map<String, dynamic> toMap() => {'uri': uri, 'fileName': fileName, 'size': size};
}

class DownloadOutput {
  const DownloadOutput({
    required this.files,
    required this.thumbnailPath,
    required this.uploader,
    required this.mediaId,
  });

  final List<SavedFile> files;
  final String? thumbnailPath;
  final String uploader;
  final String mediaId;
}

/// Thin wrapper over the Kotlin bridge (MainActivity.kt) that runs yt-dlp on-device.
class Engine {
  static const _method = MethodChannel('insta_saver/engine');
  static const _progress = EventChannel('insta_saver/progress');

  static Stream<EngineProgress>? _progressStream;

  /// Unpacks python/yt-dlp/ffmpeg on first launch; returns the yt-dlp version.
  Future<String?> init() => _method.invokeMethod<String>('init');

  Future<String?> version() => _method.invokeMethod<String>('version');

  /// Returns the new yt-dlp version after updating (or confirming it is current).
  Future<String?> update() async {
    final result = await _method.invokeMapMethod<String, dynamic>('update');
    return result?['version'] as String?;
  }

  /// Always true on Android 10+; asks for storage access on Android 9 and below.
  Future<bool> ensureStoragePermission() async =>
      await _method.invokeMethod<bool>('ensureStoragePermission') ?? false;

  Future<bool> isSignedIn() async => await _method.invokeMethod<bool>('isSignedIn') ?? false;

  /// Opens Instagram's login page; true once a session was saved.
  Future<bool> signIn() async => await _method.invokeMethod<bool>('signIn') ?? false;

  Future<void> signOut() => _method.invokeMethod('signOut');

  /// Link the app was opened with via Android's share sheet, if any (consumed once).
  Future<String?> takeSharedText() => _method.invokeMethod<String>('takeSharedText');

  /// Links shared while the app is already open.
  void onSharedText(void Function(String text) handler) {
    _method.setMethodCallHandler((call) async {
      if (call.method == 'sharedText' && call.arguments is String) {
        handler(call.arguments as String);
      }
    });
  }

  Stream<EngineProgress> get progress => _progressStream ??= _progress
      .receiveBroadcastStream()
      .map((event) {
        final map = event as Map;
        return EngineProgress(
          taskId: map['taskId'] as String,
          percent: (map['progress'] as num).toDouble(),
          etaSeconds: (map['eta'] as num).toInt(),
          line: map['line'] as String? ?? '',
        );
      })
      .asBroadcastStream();

  Future<DownloadOutput> download({required String url, required String taskId}) async {
    final result = await _method.invokeMapMethod<String, dynamic>(
      'download',
      {'url': url, 'taskId': taskId},
    );
    return DownloadOutput(
      files: (result!['files'] as List).map((e) => SavedFile.fromMap(e as Map)).toList(),
      thumbnailPath: result['thumbnail'] as String?,
      uploader: result['uploader'] as String,
      mediaId: result['mediaId'] as String,
    );
  }

  Future<void> cancel(String taskId) => _method.invokeMethod('cancel', {'taskId': taskId});

  Future<void> open(String uri) => _method.invokeMethod('open', {'uri': uri});

  Future<void> share(String uri) => _method.invokeMethod('share', {'uri': uri});

  Future<bool> delete(String uri) async =>
      await _method.invokeMethod<bool>('delete', {'uri': uri}) ?? false;
}
