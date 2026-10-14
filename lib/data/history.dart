import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../core/engine.dart';

class DownloadRecord {
  const DownloadRecord({
    required this.id,
    required this.url,
    required this.uploader,
    required this.mediaId,
    required this.files,
    required this.thumbnailPath,
    required this.createdAt,
  });

  final String id;
  final String url;
  final String uploader;
  final String mediaId;
  final List<SavedFile> files;
  final String? thumbnailPath;
  final DateTime createdAt;

  int get totalSize => files.fold(0, (sum, f) => sum + f.size);

  factory DownloadRecord.fromMap(Map map) => DownloadRecord(
        id: map['id'] as String,
        url: map['url'] as String,
        uploader: map['uploader'] as String,
        mediaId: map['mediaId'] as String,
        files: (map['files'] as List).map((e) => SavedFile.fromMap(e as Map)).toList(),
        thumbnailPath: map['thumbnailPath'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'url': url,
        'uploader': uploader,
        'mediaId': mediaId,
        'files': files.map((f) => f.toMap()).toList(),
        'thumbnailPath': thumbnailPath,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };
}

/// Local storage for download history and small settings, backed by Hive.
class Storage {
  static const _historyBox = 'history';
  static const _settingsBox = 'settings';

  static Future<void> open() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_historyBox);
    await Hive.openBox(_settingsBox);
  }

  Box<Map> get _history => Hive.box<Map>(_historyBox);
  Box get _settings => Hive.box(_settingsBox);

  List<DownloadRecord> loadHistory() {
    final records = _history.values.map(DownloadRecord.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<void> saveRecord(DownloadRecord record) => _history.put(record.id, record.toMap());

  Future<void> deleteRecord(String id) => _history.delete(id);

  DateTime? get lastEngineUpdate {
    final millis = _settings.get('lastEngineUpdate') as int?;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  set lastEngineUpdate(DateTime? value) =>
      _settings.put('lastEngineUpdate', value?.millisecondsSinceEpoch);

  Future<void> clearHistory() => _history.clear();

  String get themeMode => _settings.get('themeMode', defaultValue: 'system') as String;
  set themeMode(String value) => _settings.put('themeMode', value);

  String get font => _settings.get('font', defaultValue: 'Default') as String;
  set font(String value) => _settings.put('font', value);

  String get language => _settings.get('language', defaultValue: 'en') as String;
  set language(String value) => _settings.put('language', value);

  double get textScale => (_settings.get('textScale', defaultValue: 1.0) as num).toDouble();
  set textScale(double value) => _settings.put('textScale', value);
}
