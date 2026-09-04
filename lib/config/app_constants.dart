import 'package:flutter/foundation.dart';

class AppConstants {
  // Sidebar width
  static const double sidebarWidth = 260;
  static const double topbarHeight = 56;

  // Border radius
  static const double radiusSmall = 8;
  static const double radiusMedium = 13;
  static const double radiusLarge = 14;

  // Padding & Spacing
  static const double paddingXS = 4;
  static const double paddingS = 8;
  static const double paddingM = 12;
  static const double paddingL = 16;
  static const double paddingXL = 20;

  // QR Code sizes
  static const double qrCodeSizeMobile = 180;
  static const double qrCodeSizeDesktop = 200;

  // Shadow
  static const String shadowLight = '0 1px 3px rgba(7,42,31,.07)';
  static const String shadowMedium = '0 4px 16px rgba(7,42,31,.11)';

  // API
  static String get apiHost {
    const configuredHost = String.fromEnvironment('SANTE_API_HOST');
    if (configuredHost.isNotEmpty) return configuredHost;

    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://127.0.0.1:3000';
    }
    return 'http://localhost:3000';
  }

  static String get baseUrl => '$apiHost/api';
  static String get healthCheck => '$apiHost/health';

  // Cache keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser = 'user_data';
  static const String keyPatientQr = 'patient_qr_code';
  static const String keyLastSync = 'last_sync_timestamp';
}
