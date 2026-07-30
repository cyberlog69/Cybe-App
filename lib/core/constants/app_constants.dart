class AppConstants {
  static const String appName = 'Cybe Security';
  static const String appVersion = '1.0.0';

  // Hive box names
  static const String passwordBoxName = 'passwords_box';
  static const String vaultBoxName = 'vault_box';
  static const String settingsBoxName = 'settings_box';
  static const String networkLogBoxName = 'network_log_box';
  static const String phishingHistoryBoxName = 'phishing_history_box';
  static const String usbHistoryBoxName = 'usb_history_box';
  static const String securityLogsBoxName = 'security_logs_box';

  // Secure storage keys
  static const String masterPasswordHashKey = 'master_pw_hash';
  static const String masterSaltKey = 'master_salt';
  static const String encryptionKeyKey = 'enc_key';
  static const String vaultKeyKey = 'vault_key';

  // Security config
  static const int pbkdf2Iterations = 100000;
  static const int saltLength = 32;
  static const int ivLength = 16;
  static const int clipboardClearSeconds = 30;
  static const int autoLockMinutes = 5;

  // Google Safe Browsing API
  static const String safeBrowsingBaseUrl = 'https://safebrowsing.googleapis.com/v4';
  static const String safeBrowsingApiKey = 'YOUR_GOOGLE_SAFE_BROWSING_API_KEY';

  // Ping targets for network test
  static const List<String> pingHosts = ['8.8.8.8', '1.1.1.1', '9.9.9.9'];

  // Password categories
  static const List<String> categories = [
    'All', 'Social', 'Banking', 'Email', 'Work', 'Shopping', 'Entertainment', 'Other'
  ];

  // WiFi security levels
  static const String wifiSecOpen = 'Open';
  static const String wifiSecWep = 'WEP';
  static const String wifiSecWpa = 'WPA';
  static const String wifiSecWpa2 = 'WPA2';
  static const String wifiSecWpa3 = 'WPA3';
}
