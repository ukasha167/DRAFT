import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/providers/repository_providers.dart';

// ---------------------------------------------------------------------------
// Theme
// ---------------------------------------------------------------------------

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (_) => ThemeModeNotifier(),
);

// ---------------------------------------------------------------------------
// Backup / Restore
// ---------------------------------------------------------------------------

enum BackupPhase { idle, working, done, error }

class BackupState {
  final BackupPhase phase;
  final String? errorMessage;
  const BackupState({this.phase = BackupPhase.idle, this.errorMessage});
  BackupState copyWith({BackupPhase? phase, String? errorMessage}) =>
      BackupState(phase: phase ?? this.phase, errorMessage: errorMessage);
}

class BackupNotifier extends StateNotifier<BackupState> {
  final Ref _ref;
  BackupNotifier(this._ref) : super(const BackupState());

  Future<void> export() async {
    state = const BackupState(phase: BackupPhase.working);
    try {
      final repo = _ref.read(bookRepositoryProvider);
      final data = await repo.exportToJson();
      final jsonBytes = utf8.encode(jsonEncode(data));

      final archive = Archive()
        ..addFile(ArchiveFile('books.json', jsonBytes.length, jsonBytes));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) throw Exception('Failed to encode archive');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/book_tracker_backup.zip');
      await file.writeAsBytes(zipBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/zip')],
        subject: 'Book Tracker Backup',
      );

      state = const BackupState(phase: BackupPhase.done);
    } catch (e) {
      state = BackupState(
        phase: BackupPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> importFromFile({required bool replaceAll}) async {
    state = const BackupState(phase: BackupPhase.working);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      if (result == null || result.files.single.path == null) {
        state = const BackupState(phase: BackupPhase.idle);
        return;
      }

      final bytes = await File(result.files.single.path!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      final jsonFile = archive.findFile('books.json');
      if (jsonFile == null) throw Exception('Invalid backup: missing books.json');

      final content = utf8.decode(jsonFile.content as List<int>);
      final data = jsonDecode(content) as Map<String, dynamic>;

      final repo = _ref.read(bookRepositoryProvider);
      await repo.importFromJson(data, replaceAll: replaceAll);

      state = const BackupState(phase: BackupPhase.done);
    } catch (e) {
      state = BackupState(
        phase: BackupPhase.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = const BackupState();
}

final backupProvider =
    StateNotifierProvider.autoDispose<BackupNotifier, BackupState>(
  (ref) => BackupNotifier(ref),
);
