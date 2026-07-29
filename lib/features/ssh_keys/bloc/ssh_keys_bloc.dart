import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/ssh_key_entry.dart';
import '../services/ssh_keys_service.dart';

abstract class SshKeysEvent {}
class SshKeysLoad extends SshKeysEvent {}
class SshKeysSave extends SshKeysEvent { final SshKeyEntry entry; SshKeysSave(this.entry); }
class SshKeysDelete extends SshKeysEvent { final String id; SshKeysDelete(this.id); }

abstract class SshKeysState {}
class SshKeysInitial extends SshKeysState {}
class SshKeysLoading extends SshKeysState {}
class SshKeysLoaded extends SshKeysState {
  final List<SshKeyEntry> keys;
  SshKeysLoaded(this.keys);
}
class SshKeysError extends SshKeysState { final String message; SshKeysError(this.message); }

class SshKeysBloc extends Bloc<SshKeysEvent, SshKeysState> {
  final SshKeysService _service;

  SshKeysBloc({SshKeysService? service}) : _service = service ?? SshKeysService(), super(SshKeysInitial()) {
    on<SshKeysLoad>(_onLoad);
    on<SshKeysSave>(_onSave);
    on<SshKeysDelete>(_onDelete);
  }

  Future<void> _onLoad(SshKeysLoad e, Emitter<SshKeysState> emit) async {
    emit(SshKeysLoading());
    try {
      final keys = await _service.loadKeys();
      emit(SshKeysLoaded(keys));
    } catch (err) {
      emit(SshKeysError('Failed to load SSH keys: $err'));
    }
  }

  Future<void> _onSave(SshKeysSave e, Emitter<SshKeysState> emit) async {
    try {
      await _service.saveKey(e.entry);
      add(SshKeysLoad());
    } catch (err) {
      emit(SshKeysError('Failed to save SSH key: $err'));
    }
  }

  Future<void> _onDelete(SshKeysDelete e, Emitter<SshKeysState> emit) async {
    try {
      await _service.deleteKey(e.id);
      add(SshKeysLoad());
    } catch (err) {
      emit(SshKeysError('Failed to delete SSH key: $err'));
    }
  }
}
