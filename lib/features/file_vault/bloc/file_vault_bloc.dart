import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/vault_file_entry.dart';
import '../services/file_vault_service.dart';

// ─── Events ──────────────────────────────────────────────────────────────────
abstract class FileVaultEvent {}

/// Triggers initial load of vault metadata from Hive.
class FileVaultLoad extends FileVaultEvent {}

/// Requests encryption + import of a file at [filePath].
class FileVaultImport extends FileVaultEvent {
  final String filePath;
  final String fileName;
  final bool deleteOriginal;
  FileVaultImport({
    required this.filePath,
    required this.fileName,
    this.deleteOriginal = true,
  });
}

/// Requests decryption + restore of a vault [entry] back to filesystem.
class FileVaultRestore extends FileVaultEvent {
  final VaultFileEntry entry;
  FileVaultRestore(this.entry);
}

/// Requests decryption + share of an existing vault [entry].
class FileVaultDecrypt extends FileVaultEvent {
  final VaultFileEntry entry;
  FileVaultDecrypt(this.entry);
}

/// Requests permanent deletion of a vault [entry].
class FileVaultDelete extends FileVaultEvent {
  final VaultFileEntry entry;
  FileVaultDelete(this.entry);
}

// ─── States ──────────────────────────────────────────────────────────────────
abstract class FileVaultState {}

class FileVaultInitial extends FileVaultState {}

class FileVaultLoading extends FileVaultState {}

class FileVaultLoaded extends FileVaultState {
  final List<VaultFileEntry> files;
  final bool operationInProgress;
  final String? error;
  final String? successMessage;

  FileVaultLoaded({
    required this.files,
    this.operationInProgress = false,
    this.error,
    this.successMessage,
  });

  FileVaultLoaded copyWith({
    List<VaultFileEntry>? files,
    bool? operationInProgress,
    String? error,
    String? successMessage,
  }) =>
      FileVaultLoaded(
        files: files ?? this.files,
        operationInProgress: operationInProgress ?? this.operationInProgress,
        error: error,
        successMessage: successMessage,
      );
}

class FileVaultError extends FileVaultState {
  final String message;
  FileVaultError(this.message);
}

// ─── BLoC ────────────────────────────────────────────────────────────────────
class FileVaultBloc extends Bloc<FileVaultEvent, FileVaultState> {
  final FileVaultService _service;

  FileVaultBloc({FileVaultService? service})
      : _service = service ?? FileVaultService(),
        super(FileVaultInitial()) {
    on<FileVaultLoad>(_onLoad);
    on<FileVaultImport>(_onImport);
    on<FileVaultRestore>(_onRestore);
    on<FileVaultDecrypt>(_onDecrypt);
    on<FileVaultDelete>(_onDelete);
  }

  List<VaultFileEntry> get _currentFiles =>
      state is FileVaultLoaded ? (state as FileVaultLoaded).files : [];

  Future<void> _onLoad(FileVaultLoad _, Emitter<FileVaultState> emit) async {
    emit(FileVaultLoading());
    try {
      await _service.init();
      final files = await _service.loadFiles();
      emit(FileVaultLoaded(files: files));
    } catch (e) {
      emit(FileVaultError('Failed to load vault: $e'));
    }
  }

  Future<void> _onImport(
      FileVaultImport event, Emitter<FileVaultState> emit) async {
    emit(FileVaultLoaded(
        files: _currentFiles, operationInProgress: true));
    try {
      await _service.importFile(event.filePath, event.fileName,
          deleteOriginal: event.deleteOriginal);
      final files = await _service.loadFiles();
      emit(FileVaultLoaded(
          files: files,
          successMessage:
              '${event.fileName} encrypted into vault (original source removed)'));
    } catch (e) {
      emit(FileVaultLoaded(
          files: _currentFiles, error: 'Encryption failed: $e'));
    }
  }

  Future<void> _onRestore(
      FileVaultRestore event, Emitter<FileVaultState> emit) async {
    emit(FileVaultLoaded(
        files: _currentFiles, operationInProgress: true));
    try {
      final destPath = await _service.restoreFile(event.entry);
      final files = await _service.loadFiles();
      emit(FileVaultLoaded(
          files: files,
          successMessage: '${event.entry.name} decrypted and restored to $destPath'));
    } catch (e) {
      emit(FileVaultLoaded(
          files: _currentFiles, error: 'Decryption & Restore failed: $e'));
    }
  }

  Future<void> _onDecrypt(
      FileVaultDecrypt event, Emitter<FileVaultState> emit) async {
    emit(FileVaultLoaded(
        files: _currentFiles, operationInProgress: true));
    try {
      await _service.shareDecrypted(event.entry);
      emit(FileVaultLoaded(
          files: _currentFiles,
          successMessage: 'File decrypted and shared'));
    } catch (e) {
      emit(FileVaultLoaded(
          files: _currentFiles, error: 'Decryption failed: $e'));
    }
  }

  Future<void> _onDelete(
      FileVaultDelete event, Emitter<FileVaultState> emit) async {
    emit(FileVaultLoaded(
        files: _currentFiles, operationInProgress: true));
    try {
      await _service.deleteFile(event.entry);
      final files = await _service.loadFiles();
      emit(FileVaultLoaded(files: files));
    } catch (e) {
      emit(FileVaultLoaded(
          files: _currentFiles, error: 'Delete failed: $e'));
    }
  }
}
