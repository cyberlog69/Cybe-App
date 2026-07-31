import 'dart:convert';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:usb_serial/usb_serial.dart';
import '../../../core/constants/app_constants.dart';
import '../models/usb_history_entry.dart';

/// Service layer for USB monitoring.
/// Encapsulates platform-specific USB scanning (Android + Windows)
/// and Hive-backed persistence for history and trusted-device list.
class UsbService {
  static const _boxName = AppConstants.usbHistoryBoxName;
  static const _trustedKey = '__trusted_devices__';
  Box? _box;

  Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
    } else {
      _box = Hive.box(_boxName);
    }
  }

  // ── Device Scanning ───────────────────────────────────────────────────────

  Future<List<UsbDeviceInfo>> scanDevices() async {
    if (Platform.isAndroid) return _scanAndroid();
    if (Platform.isWindows) return _scanWindows();
    if (Platform.isMacOS) return _scanMacOS();
    if (Platform.isLinux) return _scanLinux();
    return [];
  }

  Future<List<UsbDeviceInfo>> _scanAndroid() async {
    try {
      final ports = await UsbSerial.listDevices();
      return ports
          .map((p) => UsbDeviceInfo(
                vendorId: p.vid
                        ?.toRadixString(16)
                        .padLeft(4, '0')
                        .toUpperCase() ??
                    'N/A',
                productId: p.pid
                        ?.toRadixString(16)
                        .padLeft(4, '0')
                        .toUpperCase() ??
                    'N/A',
                manufacturer: p.manufacturerName,
                productName: p.productName,
                connectedAt: DateTime.now(),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UsbDeviceInfo>> _scanWindows() async {
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'Get-PnpDevice -PresentOnly -Class USB,Ports | '
            'Select-Object FriendlyName, InstanceId, Status | ConvertTo-Json',
      ]);
      if (result.exitCode != 0 || result.stdout.toString().trim().isEmpty) {
        return [];
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(result.stdout.toString().trim());
      } catch (_) {
        return [];
      }
      final items = decoded is List ? decoded : [decoded];
      final vidReg =
          RegExp(r'VID_([0-9A-Fa-f]{4})', caseSensitive: false);
      final pidReg =
          RegExp(r'PID_([0-9A-Fa-f]{4})', caseSensitive: false);

      return items.whereType<Map>().map((item) {
        final name = (item['FriendlyName'] ?? 'USB Device').toString();
        final instanceId = (item['InstanceId'] ?? '').toString();
        return UsbDeviceInfo(
          vendorId:
              vidReg.firstMatch(instanceId)?.group(1)?.toUpperCase() ??
                  'N/A',
          productId:
              pidReg.firstMatch(instanceId)?.group(1)?.toUpperCase() ??
                  'N/A',
          productName: name,
          connectedAt: DateTime.now(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<UsbDeviceInfo>> _scanMacOS() async {
    try {
      final res = await Process.run('system_profiler', ['SPUSBDataType', '-json']);
      if (res.exitCode != 0 || res.stdout.toString().isEmpty) return [];
      final data = jsonDecode(res.stdout.toString());
      final List<UsbDeviceInfo> devices = [];
      if (data is Map && data.containsKey('SPUSBDataType')) {
        final items = data['SPUSBDataType'] as List?;
        if (items != null) {
          for (final item in items) {
            if (item is Map) {
              final name = (item['_name'] ?? 'USB Peripheral').toString();
              devices.add(UsbDeviceInfo(
                vendorId: 'APPLE/USB',
                productId: '0x1000',
                productName: name,
                connectedAt: DateTime.now(),
              ));
            }
          }
        }
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  Future<List<UsbDeviceInfo>> _scanLinux() async {
    try {
      final res = await Process.run('lsusb', []);
      if (res.exitCode != 0 || res.stdout.toString().isEmpty) return [];
      final lines = res.stdout.toString().split('\n');
      final List<UsbDeviceInfo> devices = [];
      final reg = RegExp(r'ID\s+([0-9a-fA-F]{4}):([0-9a-fA-F]{4})\s+(.+)');

      for (final line in lines) {
        final match = reg.firstMatch(line);
        if (match != null) {
          devices.add(UsbDeviceInfo(
            vendorId: match.group(1)!.toUpperCase(),
            productId: match.group(2)!.toUpperCase(),
            productName: match.group(3)!.trim(),
            connectedAt: DateTime.now(),
          ));
        }
      }
      return devices;
    } catch (_) {
      return [];
    }
  }

  // ── Hive History ─────────────────────────────────────────────────────────

  Future<List<UsbHistoryEntry>> loadHistory() async {
    await init();
    return _box!.values
        .whereType<Map>()
        .map((v) => UsbHistoryEntry.fromMap(v))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addHistoryEntry(UsbHistoryEntry entry) async {
    await init();
    await _box!.put(entry.id, entry.toMap());
  }

  Future<void> clearHistory() async {
    await init();
    final historyKeys =
        _box!.keys.where((k) => k != _trustedKey).toList();
    await _box!.deleteAll(historyKeys);
  }

  // ── Trusted Devices ───────────────────────────────────────────────────────

  Future<Set<String>> loadTrustedDevices() async {
    await init();
    final raw = _box!.get(_trustedKey);
    if (raw == null) return {};
    return Set<String>.from((raw as List).cast<String>());
  }

  Future<void> trustDevice(String deviceKey) async {
    await init();
    final trusted = await loadTrustedDevices();
    trusted.add(deviceKey);
    await _box!.put(_trustedKey, trusted.toList());
  }

  Future<void> untrustDevice(String deviceKey) async {
    await init();
    final trusted = await loadTrustedDevices();
    trusted.remove(deviceKey);
    await _box!.put(_trustedKey, trusted.toList());
  }
}
