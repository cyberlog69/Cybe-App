import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

abstract class NetworkEvent {}
class NetworkMonitoringStarted extends NetworkEvent {}
class NetworkStatusChanged extends NetworkEvent {
  final List<ConnectivityResult> result;
  NetworkStatusChanged(this.result);
}

abstract class NetworkState {}
class NetworkInitial extends NetworkState {}
class NetworkConnected extends NetworkState {
  final String connectionType;
  NetworkConnected(this.connectionType);
}
class NetworkDisconnected extends NetworkState {}

class NetworkBloc extends Bloc<NetworkEvent, NetworkState> {
  final _connectivity = Connectivity();
  StreamSubscription? _sub;

  NetworkBloc() : super(NetworkInitial()) {
    on<NetworkMonitoringStarted>(_onStarted);
    on<NetworkStatusChanged>(_onChanged);
  }

  Future<void> _onStarted(NetworkMonitoringStarted e, Emitter<NetworkState> emit) async {
    final result = await _connectivity.checkConnectivity();
    emit(_mapResult(result));
    _sub = _connectivity.onConnectivityChanged.listen(
      (result) => add(NetworkStatusChanged(result)),
    );
  }

  void _onChanged(NetworkStatusChanged e, Emitter<NetworkState> emit) {
    emit(_mapResult(e.result));
  }

  NetworkState _mapResult(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi)) return NetworkConnected('Wi-Fi');
    if (results.contains(ConnectivityResult.mobile)) return NetworkConnected('Mobile');
    if (results.contains(ConnectivityResult.ethernet)) return NetworkConnected('Ethernet');
    return NetworkDisconnected();
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
