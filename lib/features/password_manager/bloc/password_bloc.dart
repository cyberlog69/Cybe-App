import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/constants/app_constants.dart';
import '../models/password_entry.dart';

abstract class PasswordEvent {}
class PasswordLoad extends PasswordEvent {}
class PasswordAdd extends PasswordEvent {
  final String site, username, password, category, url, notes;
  PasswordAdd({required this.site, required this.username, required this.password,
    this.category = 'Other', this.url = '', this.notes = ''});
}
class PasswordUpdate extends PasswordEvent {
  final String id;
  final String site, username, password, category, url, notes;
  PasswordUpdate({required this.id, required this.site, required this.username,
    required this.password, this.category = 'Other', this.url = '', this.notes = ''});
}
class PasswordDelete extends PasswordEvent { final String id; PasswordDelete(this.id); }
class PasswordSearch extends PasswordEvent { final String query; PasswordSearch(this.query); }
class PasswordFilterCategory extends PasswordEvent { final String category; PasswordFilterCategory(this.category); }

abstract class PasswordState {}
class PasswordInitial extends PasswordState {}
class PasswordLoading extends PasswordState {}
class PasswordLoaded extends PasswordState {
  final List<PasswordEntry> entries;
  final String searchQuery;
  final String selectedCategory;
  PasswordLoaded(this.entries, {this.searchQuery = '', this.selectedCategory = 'All'});
  List<PasswordEntry> get filtered {
    var list = entries;
    if (selectedCategory != 'All') list = list.where((e) => e.category == selectedCategory).toList();
    if (searchQuery.isNotEmpty) {
      list = list.where((e) => e.site.toLowerCase().contains(searchQuery.toLowerCase())
          || e.username.toLowerCase().contains(searchQuery.toLowerCase())).toList();
    }
    return list;
  }
}
class PasswordError extends PasswordState { final String message; PasswordError(this.message); }

class PasswordBloc extends Bloc<PasswordEvent, PasswordState> {
  final _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  Box? _box;

  PasswordBloc() : super(PasswordInitial()) {
    on<PasswordLoad>(_onLoad);
    on<PasswordAdd>(_onAdd);
    on<PasswordUpdate>(_onUpdate);
    on<PasswordDelete>(_onDelete);
    on<PasswordSearch>(_onSearch);
    on<PasswordFilterCategory>(_onFilter);
  }

  Future<List<int>> _getKey() async {
    final keyStr = await _storage.read(key: AppConstants.encryptionKeyKey);
    if (keyStr == null) throw Exception('Encryption key not found');
    return base64.decode(keyStr);
  }

  Future<void> _onLoad(PasswordLoad e, Emitter<PasswordState> emit) async {
    emit(PasswordLoading());
    try {
      _box ??= await Hive.openBox(AppConstants.passwordBoxName);
      final key = await _getKey();
      final entries = _box!.values.map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        return PasswordEntry.fromEncrypted(map, key);
      }).toList();
      emit(PasswordLoaded(entries));
    } catch (err) {
      emit(PasswordError(err.toString()));
    }
  }

  Future<void> _onAdd(PasswordAdd e, Emitter<PasswordState> emit) async {
    try {
      final key = await _getKey();
      final entry = PasswordEntry.create(
        site: e.site, username: e.username, password: e.password,
        category: e.category, url: e.url, notes: e.notes,
      );
      final encrypted = entry.toEncrypted(key);
      await _box!.put(entry.id, encrypted);
      add(PasswordLoad());
    } catch (err) {
      emit(PasswordError(err.toString()));
    }
  }

  Future<void> _onUpdate(PasswordUpdate e, Emitter<PasswordState> emit) async {
    try {
      final key = await _getKey();
      final entry = PasswordEntry.create(
        site: e.site, username: e.username, password: e.password,
        category: e.category, url: e.url, notes: e.notes,
        existingId: e.id,
      );
      final encrypted = entry.toEncrypted(key);
      await _box!.put(entry.id, encrypted);
      add(PasswordLoad());
    } catch (err) {
      emit(PasswordError(err.toString()));
    }
  }

  Future<void> _onDelete(PasswordDelete e, Emitter<PasswordState> emit) async {
    await _box!.delete(e.id);
    add(PasswordLoad());
  }

  void _onSearch(PasswordSearch e, Emitter<PasswordState> emit) {
    if (state is PasswordLoaded) {
      final current = state as PasswordLoaded;
      emit(PasswordLoaded(current.entries, searchQuery: e.query, selectedCategory: current.selectedCategory));
    }
  }

  void _onFilter(PasswordFilterCategory e, Emitter<PasswordState> emit) {
    if (state is PasswordLoaded) {
      final current = state as PasswordLoaded;
      emit(PasswordLoaded(current.entries, searchQuery: current.searchQuery, selectedCategory: e.category));
    }
  }
}
