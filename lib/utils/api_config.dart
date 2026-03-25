class ApiConfig {
  // ---------------------------------------------------------
  // 🌐 API CONFIGURATION (MONGODB-PURE)
  // ---------------------------------------------------------
  static const String baseUrl = 'https://sos-guardian-api.onrender.com'; 
  
  // Auth Routes
  static String get registerUrl => '$baseUrl/register';
  static String get loginUrl => '$baseUrl/login';
  static String get updateCodewordUrl => '$baseUrl/update-codeword';

  // System Health
  static String get statusUrl => '$baseUrl/status';

  // SOS Emergency Routes
  static String get reportSosUrl => '$baseUrl/report-sos';
  
  // Police HQ Routes
  static String get hqDashboardUrl => '$baseUrl/hq-dashboard';
  static String get hqResolveUrl => '$baseUrl/hq-resolve';
  static String get hqHistoryUrl => '$baseUrl/hq-history';
  
  // User History
  static String myHistoryUrl(String userId) => '$baseUrl/my-history/$userId';
  
  // External (Twilio Forwarding via Server)
  static String get makeCallUrl => '$baseUrl/make-call';
  static String get sendSmsUrl => '$baseUrl/send-sms';
}
