import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/engine.dart';
import '../core/errors.dart';
import '../core/links.dart';
import '../data/history.dart';

final engineProvider = Provider((ref) => Engine());
final storageProvider = Provider((ref) => Storage());

// ---- Engine (yt-dlp) status --------------------------------------------------------------

class EngineStatus {
  const EngineStatus({this.version, this.ready = false, this.updating = false, this.error});

  final String? version;
  final bool ready;
  final bool updating;
  final String? error;

  EngineStatus copyWith({String? version, bool? ready, bool? updating, String? error}) => EngineStatus(
        version: version ?? this.version,
        ready: ready ?? this.ready,
        updating: updating ?? this.updating,
        error: error,
      );
}

class EngineController extends Notifier<EngineStatus> {
  static const _autoUpdateEvery = Duration(days: 1);

  Engine get _engine => ref.read(engineProvider);
  Storage get _storage => ref.read(storageProvider);

  late final Future<void> _startup = _init();
  Future<String?>? _pendingUpdate;

  @override
  EngineStatus build() {
    Future.microtask(() => _startup);
    return const EngineStatus();
  }

  /// Completes once the engine is unpacked and any due update has finished,
  /// so a download never runs on the outdated yt-dlp bundled with the APK.
  Future<void> ready() async {
    await _startup;
    final pending = _pendingUpdate;
    if (pending != null) await pending.catchError((_) => null);
  }

  Future<void> _init() async {
    try {
      final version = await _engine.init();
      state = state.copyWith(version: version, ready: true);
    } catch (e) {
      state = state.copyWith(error: 'Could not start the download engine: $e');
      return;
    }

    // Instagram changes often; a fresh yt-dlp is the main thing that keeps downloads working.
    final last = _storage.lastEngineUpdate;
    if (last == null || DateTime.now().difference(last) > _autoUpdateEvery) {
      unawaited(update().catchError((_) => null));
    }
  }

  /// Updates yt-dlp to the latest stable release. Returns the resulting version.
  Future<String?> update() => _pendingUpdate ??= _runUpdate().whenComplete(() => _pendingUpdate = null);

  Future<String?> _runUpdate() async {
    state = state.copyWith(updating: true);
    try {
      final version = await _engine.update();
      _storage.lastEngineUpdate = DateTime.now();
      state = state.copyWith(version: version, updating: false);
      return version;
    } catch (e) {
      state = state.copyWith(updating: false);
      rethrow;
    }
  }
}

final engineStatusProvider = NotifierProvider<EngineController, EngineStatus>(EngineController.new);

// ---- Appearance ----------------------------------------------------------------------------

class Appearance {
  const Appearance({
    required this.themeMode,
    required this.font,
    required this.textScale,
    required this.language,
  });

  final ThemeMode themeMode;
  final String font;
  final double textScale;

  /// 'en', 'hi' or 'mr'.
  final String language;

  Appearance copyWith({ThemeMode? themeMode, String? font, double? textScale, String? language}) => Appearance(
        themeMode: themeMode ?? this.themeMode,
        font: font ?? this.font,
        textScale: textScale ?? this.textScale,
        language: language ?? this.language,
      );
}

class AppearanceController extends Notifier<Appearance> {
  Storage get _storage => ref.read(storageProvider);

  @override
  Appearance build() => Appearance(
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == _storage.themeMode,
          orElse: () => ThemeMode.system,
        ),
        font: _storage.font,
        textScale: _storage.textScale,
        language: _storage.language,
      );

  void setLanguage(String language) {
    _storage.language = language;
    state = state.copyWith(language: language);
  }

  void setThemeMode(ThemeMode mode) {
    _storage.themeMode = mode.name;
    state = state.copyWith(themeMode: mode);
  }

  void setFont(String font) {
    _storage.font = font;
    state = state.copyWith(font: font);
  }

  void setTextScale(double scale) {
    _storage.textScale = scale;
    state = state.copyWith(textScale: scale);
  }
}

final appearanceProvider = NotifierProvider<AppearanceController, Appearance>(AppearanceController.new);

// ---- Instagram account (optional sign-in) ------------------------------------------------

class AccountController extends Notifier<bool> {
  Engine get _engine => ref.read(engineProvider);

  @override
  bool build() {
    _engine.isSignedIn().then((signedIn) => state = signedIn);
    return false;
  }

  Future<bool> signIn() async {
    state = await _engine.signIn();
    return state;
  }

  Future<void> signOut() async {
    await _engine.signOut();
    state = false;
  }
}

final accountProvider = NotifierProvider<AccountController, bool>(AccountController.new);

// ---- History -----------------------------------------------------------------------------

class HistoryController extends Notifier<List<DownloadRecord>> {
  Storage get _storage => ref.read(storageProvider);

  @override
  List<DownloadRecord> build() => _storage.loadHistory();

  Future<void> add(DownloadRecord record) async {
    await _storage.saveRecord(record);
    state = [record, ...state];
  }

  /// Empties the list only; saved videos stay on the phone.
  Future<void> clear() async {
    for (final record in state) {
      final thumb = record.thumbnailPath;
      if (thumb != null) {
        final file = File(thumb);
        if (await file.exists()) await file.delete();
      }
    }
    await _storage.clearHistory();
    state = [];
  }

  /// Removes the entry, and the video files too when [deleteFiles] is set.
  Future<void> remove(DownloadRecord record, {required bool deleteFiles}) async {
    if (deleteFiles) {
      final engine = ref.read(engineProvider);
      for (final file in record.files) {
        await engine.delete(file.uri);
      }
    }
    final thumb = record.thumbnailPath;
    if (thumb != null) {
      final file = File(thumb);
      if (await file.exists()) await file.delete();
    }
    await _storage.deleteRecord(record.id);
    state = state.where((r) => r.id != record.id).toList();
  }
}

final historyProvider = NotifierProvider<HistoryController, List<DownloadRecord>>(HistoryController.new);

// ---- Current download --------------------------------------------------------------------

sealed class DownloadPhase {
  const DownloadPhase();
}

class Idle extends DownloadPhase {
  const Idle();
}

enum RunStatus { preparing, updating, fetching, downloading, merging }

class Running extends DownloadPhase {
  const Running({required this.taskId, required this.url, this.percent = 0, this.status = RunStatus.preparing});

  final String taskId;
  final String url;
  final double percent;
  final RunStatus status;
}

class Done extends DownloadPhase {
  const Done(this.record);
  final DownloadRecord record;
}

class Failed extends DownloadPhase {
  const Failed(this.problem, {this.details, this.retryUrl});
  final Problem problem;
  final String? retryUrl;

  /// Instagram refused a logged-out request; the card offers "Sign in" and retries.
  bool get needsSignIn => problem == Problem.needsSignIn;

  /// Raw engine output, shown under "Details" so it can be copied into a bug report.
  final String? details;
}

class DownloadController extends Notifier<DownloadPhase> {
  Engine get _engine => ref.read(engineProvider);

  @override
  DownloadPhase build() => const Idle();

  bool get isRunning => state is Running;

  Future<void> start(String input) async {
    if (isRunning) return;

    final link = checkLink(input);
    if (link is InvalidLink) {
      state = Failed(link.reason);
      return;
    }
    final url = (link as ValidLink).url;

    if (!await _engine.ensureStoragePermission()) {
      state = const Failed(Problem.storagePermission);
      return;
    }

    final taskId = DateTime.now().millisecondsSinceEpoch.toString();
    state = Running(taskId: taskId, url: url);

    final sub = _engine.progress.where((p) => p.taskId == taskId).listen((p) {
      final current = state;
      if (current is! Running) return;
      state = Running(
        taskId: taskId,
        url: url,
        percent: p.percent.clamp(0, 100),
        status: p.isMerging ? RunStatus.merging : RunStatus.downloading,
      );
    });

    try {
      final engine = ref.read(engineStatusProvider.notifier);
      if (ref.read(engineStatusProvider).updating) {
        state = Running(taskId: taskId, url: url, status: RunStatus.updating);
      }
      await engine.ready();
      state = Running(taskId: taskId, url: url, status: RunStatus.fetching);
      final output = await _engine.download(url: url, taskId: taskId);
      final record = DownloadRecord(
        id: taskId,
        url: url,
        uploader: output.uploader,
        mediaId: output.mediaId,
        files: output.files,
        thumbnailPath: output.thumbnailPath,
        createdAt: DateTime.now(),
      );
      await ref.read(historyProvider.notifier).add(record);
      state = Done(record);
    } catch (e) {
      final signInHelps = needsSignIn(e) && !ref.read(accountProvider);
      state = Failed(
        signInHelps ? Problem.needsSignIn : classifyError(e),
        details: errorDetails(e),
        retryUrl: url,
      );
    } finally {
      await sub.cancel();
    }
  }

  Future<void> cancel() async {
    final current = state;
    if (current is Running) await _engine.cancel(current.taskId);
  }

  void reset() {
    if (!isRunning) state = const Idle();
  }
}

final downloadProvider = NotifierProvider<DownloadController, DownloadPhase>(DownloadController.new);
