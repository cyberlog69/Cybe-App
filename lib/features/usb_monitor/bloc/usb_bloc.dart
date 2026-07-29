import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../models/usb_history_entry.dart';
import '../services/usb_service.dart';

// ─── Events ───────────────────────────────────────────────────────────────────
abstract class UsbEvent {}

/// Bootstraps the monitor: opens Hive, loads history, starts polling.
class UsbInitialize extends UsbEvent {}

/// Triggers a manual device re-scan (also called by the poll timer).
class UsbScanRequested extends UsbEvent {}

/// Marks [device] as trusted and persists the decision.
class UsbDeviceTrusted extends UsbEvent {
  final UsbDeviceInfo device;
  UsbDeviceTrusted(this.device);
}

/// Removes [device] from the connected list and logs a blocked event.
class UsbDeviceBlocked extends UsbEvent {
  final UsbDeviceInfo device;
  UsbDeviceBlocked(this.device);
}

/// Clears all persisted history entries.
class UsbHistoryCleared extends UsbEvent {}

// ─── States ───────────────────────────────────────────────────────────────────
abstract class UsbState {}

class UsbInitial extends UsbState {}
class UsbLoading extends UsbState {}

class UsbLoaded extends UsbState {
  final List<UsbDeviceInfo> connectedDevices;
  final List<UsbHistoryEntry> history;
  final Set<String> trustedDeviceKeys;
  final bool isSupported;
  final bool scanning;

  UsbLoaded({
    required this.connectedDevices,
    required this.history,
    required this.trustedDeviceKeys,
    required this.isSupported,
    this.scanning = false,
  });

  /// Returns [connectedDevices] with trust status applied from [trustedDeviceKeys].
  List<UsbDeviceInfo> get devicesWithTrust => connectedDevices
      .map((d) => d.copyWith(isTrusted: trustedDeviceKeys.contains(d.deviceKey)))
      .toList();

  UsbLoaded copyWith({
    List<UsbDeviceInfo>? connectedDevices,
    List<UsbHistoryEntry>? history,
    Set<String>? trustedDeviceKeys,
    bool? scanning,
  }) =>
      UsbLoaded(
        connectedDevices: connectedDevices ?? this.connectedDevices,
        history: history ?? this.history,
        trustedDeviceKeys: trustedDeviceKeys ?? this.trustedDeviceKeys,
        isSupported: isSupported,
        scanning: scanning ?? this.scanning,
      );
}

// ─── BLoC ────────────────────────────────────────────────────────────────────
class UsbBloc extends Bloc<UsbEvent, UsbState> {
  final UsbService _service;
  Timer? _pollTimer;

  UsbBloc({UsbService? service})
      : _service = service ?? UsbService(),
        super(UsbInitial()) {
    on<UsbInitialize>(_onInit);
    on<UsbScanRequested>(_onScan);
    on<UsbDeviceTrusted>(_onTrust);
    on<UsbDeviceBlocked>(_onBlock);
    on<UsbHistoryCleared>(_onClear);
  }

  static bool get _isSupported => Platform.isAndroid || Platform.isWindows;

  Future<void> _onInit(UsbInitialize _, Emitter<UsbState> emit) async {
    emit(UsbLoading());
    final trusted = await _service.loadTrustedDevices();
    final history = await _service.loadHistory();
    List<UsbDeviceInfo> devices = [];
    if (_isSupported) devices = await _service.scanDevices();

    emit(UsbLoaded(
      connectedDevices: devices,
      history: history,
      trustedDeviceKeys: trusted,
      isSupported: _isSupported,
    ));

    if (_isSupported) _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isClosed) add(UsbScanRequested());
    });
  }

  Future<void> _onScan(UsbScanRequested _, Emitter<UsbState> emit) async {
    if (state is! UsbLoaded) return;
    final current = state as UsbLoaded;
    final newDevices = await _service.scanDevices();
    final List<UsbHistoryEntry> newHistory = List.from(current.history);

    // Detect new connections
    for (final d in newDevices) {
      final wasPresent = current.connectedDevices.any(
          (old) => old.deviceKey == d.deviceKey || old.displayName == d.displayName);
      if (!wasPresent) {
        final entry = UsbHistoryEntry(
          id: const Uuid().v4(),
          deviceName: d.displayName,
          vendorId: d.vendorId,
          productId: d.productId,
          eventType: 'connected',
          timestamp: DateTime.now(),
        );
        await _service.addHistoryEntry(entry);
        newHistory.insert(0, entry);
      }
    }

    // Detect disconnections
    for (final old in current.connectedDevices) {
      final stillPresent = newDevices.any(
          (d) => d.deviceKey == old.deviceKey || d.displayName == old.displayName);
      if (!stillPresent) {
        final entry = UsbHistoryEntry(
          id: const Uuid().v4(),
          deviceName: old.displayName,
          vendorId: old.vendorId,
          productId: old.productId,
          eventType: 'disconnected',
          timestamp: DateTime.now(),
        );
        await _service.addHistoryEntry(entry);
        newHistory.insert(0, entry);
      }
    }

    emit(current.copyWith(
      connectedDevices: newDevices,
      history: newHistory.take(50).toList(),
    ));
  }

  Future<void> _onTrust(UsbDeviceTrusted event, Emitter<UsbState> emit) async {
    if (state is! UsbLoaded) return;
    final current = state as UsbLoaded;
    await _service.trustDevice(event.device.deviceKey);
    final entry = UsbHistoryEntry(
      id: const Uuid().v4(),
      deviceName: event.device.displayName,
      vendorId: event.device.vendorId,
      productId: event.device.productId,
      eventType: 'trusted',
      timestamp: DateTime.now(),
    );
    await _service.addHistoryEntry(entry);
    final trusted = Set<String>.from(current.trustedDeviceKeys)
      ..add(event.device.deviceKey);
    emit(current.copyWith(
      trustedDeviceKeys: trusted,
      history: [entry, ...current.history].take(50).toList(),
    ));
  }

  Future<void> _onBlock(UsbDeviceBlocked event, Emitter<UsbState> emit) async {
    if (state is! UsbLoaded) return;
    final current = state as UsbLoaded;
    final entry = UsbHistoryEntry(
      id: const Uuid().v4(),
      deviceName: event.device.displayName,
      vendorId: event.device.vendorId,
      productId: event.device.productId,
      eventType: 'blocked',
      timestamp: DateTime.now(),
    );
    await _service.addHistoryEntry(entry);
    final newDevices = current.connectedDevices
        .where((d) => d.deviceKey != event.device.deviceKey)
        .toList();
    emit(current.copyWith(
      connectedDevices: newDevices,
      history: [entry, ...current.history].take(50).toList(),
    ));
  }

  Future<void> _onClear(UsbHistoryCleared _, Emitter<UsbState> emit) async {
    if (state is! UsbLoaded) return;
    final current = state as UsbLoaded;
    await _service.clearHistory();
    emit(current.copyWith(history: []));
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
