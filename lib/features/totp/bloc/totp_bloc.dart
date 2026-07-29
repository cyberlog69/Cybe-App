import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/totp_item.dart';
import '../services/totp_service.dart';

abstract class TotpEvent {}
class TotpLoad extends TotpEvent {}
class TotpAdd extends TotpEvent { final TotpItem item; TotpAdd(this.item); }
class TotpDelete extends TotpEvent { final String id; TotpDelete(this.id); }
class TotpTick extends TotpEvent {}

abstract class TotpState {}
class TotpInitial extends TotpState {}
class TotpLoading extends TotpState {}
class TotpLoaded extends TotpState {
  final List<TotpItem> items;
  final int tick;
  TotpLoaded(this.items, {this.tick = 0});
}
class TotpError extends TotpState { final String message; TotpError(this.message); }

class TotpBloc extends Bloc<TotpEvent, TotpState> {
  final TotpService _service;
  Timer? _timer;

  TotpBloc({TotpService? service}) : _service = service ?? TotpService(), super(TotpInitial()) {
    on<TotpLoad>(_onLoad);
    on<TotpAdd>(_onAdd);
    on<TotpDelete>(_onDelete);
    on<TotpTick>(_onTick);
  }

  Future<void> _onLoad(TotpLoad e, Emitter<TotpState> emit) async {
    emit(TotpLoading());
    try {
      final items = await _service.loadItems();
      emit(TotpLoaded(items));
      _startTimer();
    } catch (err) {
      emit(TotpError('Failed to load 2FA items: $err'));
    }
  }

  Future<void> _onAdd(TotpAdd e, Emitter<TotpState> emit) async {
    try {
      await _service.addItem(e.item);
      add(TotpLoad());
    } catch (err) {
      emit(TotpError('Failed to add 2FA item: $err'));
    }
  }

  Future<void> _onDelete(TotpDelete e, Emitter<TotpState> emit) async {
    try {
      await _service.deleteItem(e.id);
      add(TotpLoad());
    } catch (err) {
      emit(TotpError('Failed to delete item: $err'));
    }
  }

  void _onTick(TotpTick e, Emitter<TotpState> emit) {
    if (state is TotpLoaded) {
      final current = state as TotpLoaded;
      emit(TotpLoaded(current.items, tick: current.tick + 1));
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isClosed) add(TotpTick());
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
