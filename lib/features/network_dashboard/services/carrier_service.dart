import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'carrier_database.dart';

class SimCardInfo {
  final String carrierName;
  final String isoCountryCode;
  final String mobileCountryCode;
  final String mobileNetworkCode;
  final String networkGeneration;
  final String radioType;
  final String phoneNumber;
  final String simSlotLabel;
  final bool isEmbedded;
  final bool isRoaming;
  final String simState;
  final String networkOperatorName;
  final int simSlotIndex;
  final int subscriptionId;
  final String simSerialNumber;

  const SimCardInfo({
    this.carrierName = 'Not Available',
    this.isoCountryCode = 'N/A',
    this.mobileCountryCode = 'N/A',
    this.mobileNetworkCode = 'N/A',
    this.networkGeneration = 'Unknown',
    this.radioType = 'Unknown',
    this.phoneNumber = 'Not Provisioned',
    this.simSlotLabel = 'SIM 1',
    this.isEmbedded = false,
    this.isRoaming = false,
    this.simState = 'Unknown',
    this.networkOperatorName = '',
    this.simSlotIndex = 0,
    this.subscriptionId = 0,
    this.simSerialNumber = '',
  });

  String get simType => isEmbedded ? 'eSIM' : 'Physical SIM';
}

class CarrierDetails {
  final List<SimCardInfo> simSlots;
  final bool isMultiSimSupported;
  final bool isVoiceCapable;
  final bool isDataCapable;
  final bool isSmsCapable;
  final bool isDataEnabled;
  final String imeiStatus;
  final int simSlotCount;
  final bool supportsEmbeddedSim;

  const CarrierDetails({
    this.simSlots = const [],
    this.isMultiSimSupported = false,
    this.isVoiceCapable = false,
    this.isDataCapable = false,
    this.isSmsCapable = false,
    this.isDataEnabled = false,
    this.imeiStatus = 'N/A (Desktop/Emulated)',
    this.simSlotCount = 0,
    this.supportsEmbeddedSim = false,
  });

  factory CarrierDetails.empty() => const CarrierDetails();

  int get activeSlotCount => simSlots.length;

  bool get hasCellularConnectivity =>
      simSlots.isNotEmpty && simSlots.any((s) => s.carrierName != 'Not Available');
}

class CarrierService {
  static Future<CarrierDetails> getCarrierInfo() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return CarrierDetails.empty();
    }

    try {
      if (Platform.isAndroid) {
        // Request telephony & location permissions for SIM detection
        if (!await Permission.phone.isGranted) {
          await Permission.phone.request();
        }
        if (!await Permission.locationWhenInUse.isGranted) {
          await Permission.locationWhenInUse.request();
        }
        return await _getAndroidCarrierInfo();
      } else if (Platform.isIOS) {
        return await _getIosCarrierInfo();
      }

      return CarrierDetails.empty();
    } catch (e) {
      debugPrint('[CarrierService] Error reading carrier info: $e');
      return CarrierDetails.empty();
    }
  }

  static Future<CarrierDetails> _getAndroidCarrierInfo() async {
    AndroidCarrierData? info;
    try {
      info = await CarrierInfo.getAndroidInfo();
    } catch (e) {
      debugPrint('[CarrierService] Error calling getAndroidInfo: $e');
    }

    if (info == null) {
      return CarrierDetails.empty();
    }

    final List<SimCardInfo> sims = [];

    // Process subscription info (physical & eSIM slots)
    for (final sub in info.subscriptionsInfo) {
      final mcc = sub.mobileCountryCode;
      final mnc = sub.mobileNetworkCode;
      final mccMncKey = '$mcc-$mnc';

      String carrierName = sub.displayName;
      if ((carrierName.isEmpty || carrierName == 'Unknown Carrier') &&
          carrierDatabase.containsKey(mccMncKey)) {
        carrierName = carrierDatabase[mccMncKey]!;
      }
      if (carrierName.isEmpty) {
        carrierName = 'Cellular Carrier';
      }

      String isoCountry = sub.countryIso.toUpperCase();
      if (isoCountry.isEmpty) {
        isoCountry = 'N/A';
      }

      final slotNum = sub.simSlotIndex >= 0 ? sub.simSlotIndex + 1 : sims.length + 1;
      final slotLabel = 'SIM $slotNum';

      sims.add(SimCardInfo(
        carrierName: carrierName,
        isoCountryCode: isoCountry,
        mobileCountryCode: mcc.isNotEmpty ? mcc : 'N/A',
        mobileNetworkCode: mnc.isNotEmpty ? mnc : 'N/A',
        phoneNumber: sub.phoneNumber.isNotEmpty ? sub.phoneNumber : 'Protected / SIM Unread',
        simSlotLabel: slotLabel,
        isEmbedded: sub.isEmbedded,
        isRoaming: sub.isNetworkRoaming,
        simSlotIndex: sub.simSlotIndex >= 0 ? sub.simSlotIndex : slotNum - 1,
        subscriptionId: sub.subscriptionId,
        simSerialNumber: sub.simSerialNo.isNotEmpty ? sub.simSerialNo : 'Not Available',
      ));
    }

    // Merge or append telephony info (radio generation, 5G/4G, network operators)
    for (final tel in info.telephonyInfo) {
      final mcc = tel.mobileCountryCode;
      final mnc = tel.mobileNetworkCode;
      final mccMncKey = '$mcc-$mnc';

      String carrierName = tel.carrierName;
      if ((carrierName.isEmpty || carrierName == 'Unknown Carrier') &&
          carrierDatabase.containsKey(mccMncKey)) {
        carrierName = carrierDatabase[mccMncKey]!;
      }

      // Match existing SIM slot strictly by subscriptionId or non-empty MCC/MNC
      final existingIdx = sims.indexWhere((s) =>
          (tel.subscriptionId != 0 && s.subscriptionId == tel.subscriptionId) ||
          (mcc.isNotEmpty && mnc.isNotEmpty && mcc != 'N/A' &&
              s.mobileCountryCode == mcc && s.mobileNetworkCode == mnc));

      if (existingIdx >= 0) {
        final existing = sims[existingIdx];
        sims[existingIdx] = SimCardInfo(
          carrierName: carrierName.isNotEmpty ? carrierName : existing.carrierName,
          isoCountryCode: tel.isoCountryCode.isNotEmpty
              ? tel.isoCountryCode.toUpperCase()
              : existing.isoCountryCode,
          mobileCountryCode: mcc.isNotEmpty ? mcc : existing.mobileCountryCode,
          mobileNetworkCode: mnc.isNotEmpty ? mnc : existing.mobileNetworkCode,
          networkGeneration: tel.networkGeneration.isNotEmpty ? tel.networkGeneration : existing.networkGeneration,
          radioType: tel.radioType ?? existing.radioType,
          phoneNumber: tel.phoneNumber.isNotEmpty ? tel.phoneNumber : existing.phoneNumber,
          simSlotLabel: existing.simSlotLabel,
          isEmbedded: existing.isEmbedded,
          isRoaming: existing.isRoaming,
          simState: tel.simState.isNotEmpty ? tel.simState : existing.simState,
          networkOperatorName: tel.networkOperatorName.isNotEmpty ? tel.networkOperatorName : existing.networkOperatorName,
          simSlotIndex: existing.simSlotIndex,
          subscriptionId: tel.subscriptionId != 0 ? tel.subscriptionId : existing.subscriptionId,
          simSerialNumber: existing.simSerialNumber,
        );
      } else {
        final slotNum = sims.length + 1;
        String iso = tel.isoCountryCode.toUpperCase();
        if (iso.isEmpty) iso = 'N/A';

        sims.add(SimCardInfo(
          carrierName: carrierName.isNotEmpty
              ? carrierName
              : (tel.displayName.isNotEmpty ? tel.displayName : 'Cellular Network'),
          isoCountryCode: iso,
          mobileCountryCode: mcc.isNotEmpty ? mcc : 'N/A',
          mobileNetworkCode: mnc.isNotEmpty ? mnc : 'N/A',
          networkGeneration: tel.networkGeneration.isNotEmpty ? tel.networkGeneration : '5G / 4G LTE',
          radioType: tel.radioType ?? 'Mobile Data',
          phoneNumber: tel.phoneNumber.isNotEmpty ? tel.phoneNumber : 'Protected / SIM Unread',
          simSlotLabel: 'SIM $slotNum',
          isRoaming: false,
          simState: tel.simState.isNotEmpty ? tel.simState : 'Active',
          networkOperatorName: tel.networkOperatorName.isNotEmpty ? tel.networkOperatorName : '',
          simSlotIndex: slotNum - 1,
          subscriptionId: tel.subscriptionId,
        ));
      }
    }

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    String imeiStatus;
    if (androidInfo.version.sdkInt >= 29) {
      imeiStatus = 'Protected (Android 10+ Privileged OS Policy)';
    } else {
      imeiStatus = 'Requires READ_PHONE_STATE permission';
    }

    return CarrierDetails(
      simSlots: sims,
      isMultiSimSupported: info.isMultiSimSupported.isNotEmpty,
      isVoiceCapable: info.isVoiceCapable,
      isDataCapable: info.isDataCapable,
      isSmsCapable: info.isSmsCapable,
      isDataEnabled: info.isDataEnabled,
      imeiStatus: imeiStatus,
      simSlotCount: sims.length,
    );
  }

  static Future<CarrierDetails> _getIosCarrierInfo() async {
    final iosInfo = await CarrierInfo.getIosInfo();
    final List<SimCardInfo> sims = [];

    for (final carrier in iosInfo.carrierData) {
      final mcc = carrier.mobileCountryCode ?? '';
      final mnc = carrier.mobileNetworkCode ?? '';
      final mccMncKey = '$mcc-$mnc';

      String carrierName = carrier.carrierName ?? '';
      if (carrierName.isEmpty && carrierDatabase.containsKey(mccMncKey)) {
        carrierName = carrierDatabase[mccMncKey]!;
      }
      if (carrierName.isEmpty) {
        carrierName = 'Unknown Carrier';
      }

      String iso = carrier.isoCountryCode?.toUpperCase() ?? '';
      if (iso.isEmpty) iso = 'N/A';

      sims.add(SimCardInfo(
        carrierName: carrierName,
        isoCountryCode: iso,
        mobileCountryCode: mcc.isNotEmpty ? mcc : 'N/A',
        mobileNetworkCode: mnc.isNotEmpty ? mnc : 'N/A',
        simSlotLabel: sims.isEmpty ? 'Primary' : 'Secondary',
        isEmbedded: false,
        simSlotIndex: sims.length,
      ));
    }

    return CarrierDetails(
      simSlots: sims,
      simSlotCount: sims.length,
      supportsEmbeddedSim: iosInfo.supportsEmbeddedSIM,
      isVoiceCapable: iosInfo.isSIMInserted,
      isDataCapable: iosInfo.networkStatus?.hasCellularData ?? false,
      imeiStatus: 'Protected (iOS Privacy Sandbox)',
    );
  }
}
