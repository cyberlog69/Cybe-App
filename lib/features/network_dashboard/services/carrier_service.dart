import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:device_info_plus/device_info_plus.dart';

class CarrierDetails {
  final String carrierName;
  final String isoCountryCode;
  final String mobileCountryCode;
  final String mobileNetworkCode;
  final String networkType;
  final String phoneNumber;
  final String imeiStatus;
  final String radioType;

  const CarrierDetails({
    required this.carrierName,
    required this.isoCountryCode,
    required this.mobileCountryCode,
    required this.mobileNetworkCode,
    required this.networkType,
    required this.phoneNumber,
    required this.imeiStatus,
    required this.radioType,
  });

  factory CarrierDetails.empty() => const CarrierDetails(
        carrierName: 'Not Available',
        isoCountryCode: 'N/A',
        mobileCountryCode: 'N/A',
        mobileNetworkCode: 'N/A',
        networkType: 'Wi-Fi / Ethernet',
        phoneNumber: 'Not Provisioned',
        imeiStatus: 'N/A (Desktop/Emulated)',
        radioType: 'Unknown',
      );
}

class CarrierService {
  static Future<CarrierDetails> getCarrierInfo() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return CarrierDetails.empty();
    }

    try {
      String carrierName = 'Cellular Network';
      String country = 'N/A';
      String mcc = 'N/A';
      String mnc = 'N/A';
      const String radio = '4G LTE / 5G';
      String phoneNumber = 'Protected / SIM Unread';
      String imeiStatus = 'Protected (Android 10+ OS Policy)';

      if (Platform.isAndroid) {
        final info = await CarrierInfo.getAndroidInfo();
        if (info != null && info.subscriptionsInfo.isNotEmpty) {
          final sub = info.subscriptionsInfo.first;
          if (sub.displayName.isNotEmpty) carrierName = sub.displayName;
          if (sub.countryIso.isNotEmpty) country = sub.countryIso.toUpperCase();
          if (sub.mobileCountryCode.isNotEmpty) mcc = sub.mobileCountryCode;
          if (sub.mobileNetworkCode.isNotEmpty) mnc = sub.mobileNetworkCode;
          if (sub.phoneNumber.isNotEmpty) phoneNumber = sub.phoneNumber;
        }

        final androidInfo = await DeviceInfoPlugin().androidInfo;
        if (androidInfo.version.sdkInt >= 29) {
          imeiStatus = 'Protected (Android 10+ Privileged OS Policy)';
        } else {
          imeiStatus = 'Requires READ_PHONE_STATE permission';
        }
      } else if (Platform.isIOS) {
        final iosInfo = await CarrierInfo.getIosInfo();
        if (iosInfo.carrierData.isNotEmpty) {
          final carrier = iosInfo.carrierData.first;
          if (carrier.carrierName != null && carrier.carrierName!.isNotEmpty) carrierName = carrier.carrierName!;
          if (carrier.isoCountryCode != null && carrier.isoCountryCode!.isNotEmpty) country = carrier.isoCountryCode!.toUpperCase();
          if (carrier.mobileCountryCode != null && carrier.mobileCountryCode!.isNotEmpty) mcc = carrier.mobileCountryCode!;
          if (carrier.mobileNetworkCode != null && carrier.mobileNetworkCode!.isNotEmpty) mnc = carrier.mobileNetworkCode!;
        }
        imeiStatus = 'Protected (iOS Privacy Sandbox)';
      }

      return CarrierDetails(
        carrierName: carrierName,
        isoCountryCode: country,
        mobileCountryCode: mcc,
        mobileNetworkCode: mnc,
        networkType: radio,
        phoneNumber: phoneNumber,
        imeiStatus: imeiStatus,
        radioType: radio,
      );
    } catch (e) {
      debugPrint('[CarrierService] Error reading carrier info: $e');
      return CarrierDetails.empty();
    }
  }
}
