import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/secret_note.dart';
import '../services/secret_notes_service.dart';

abstract class SecretNotesEvent {}
class SecretNotesLoad extends SecretNotesEvent {}
class SecretNotesSave extends SecretNotesEvent { final SecretNote note; SecretNotesSave(this.note); }
class SecretNotesDelete extends SecretNotesEvent { final String id; SecretNotesDelete(this.id); }

abstract class SecretNotesState {}
class SecretNotesInitial extends SecretNotesState {}
class SecretNotesLoading extends SecretNotesState {}
class SecretNotesLoaded extends SecretNotesState {
  final List<SecretNote> notes;
  SecretNotesLoaded(this.notes);
}
class SecretNotesError extends SecretNotesState { final String message; SecretNotesError(this.message); }

class SecretNotesBloc extends Bloc<SecretNotesEvent, SecretNotesState> {
  final SecretNotesService _service;

  SecretNotesBloc({SecretNotesService? service}) : _service = service ?? SecretNotesService(), super(SecretNotesInitial()) {
    on<SecretNotesLoad>(_onLoad);
    on<SecretNotesSave>(_onSave);
    on<SecretNotesDelete>(_onDelete);
  }

  Future<void> _onLoad(SecretNotesLoad e, Emitter<SecretNotesState> emit) async {
    emit(SecretNotesLoading());
    try {
      final notes = await _service.loadNotes();
      emit(SecretNotesLoaded(notes));
    } catch (err) {
      emit(SecretNotesError('Failed to load notes: $err'));
    }
  }

  Future<void> _onSave(SecretNotesSave e, Emitter<SecretNotesState> emit) async {
    try {
      await _service.saveNote(e.note);
      add(SecretNotesLoad());
    } catch (err) {
      emit(SecretNotesError('Failed to save note: $err'));
    }
  }

  Future<void> _onDelete(SecretNotesDelete e, Emitter<SecretNotesState> emit) async {
    try {
      await _service.deleteNote(e.id);
      add(SecretNotesLoad());
    } catch (err) {
      emit(SecretNotesError('Failed to delete note: $err'));
    }
  }
}
