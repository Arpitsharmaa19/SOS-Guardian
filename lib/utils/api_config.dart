class ApiConfig {
  // ---------------------------------------------------------
  // 🌐 API CONFIGURATION
  // ---------------------------------------------------------
  // For Browser: 'http://127.0.0.1:3000'
  // For Android Emulator: 'http://10.0.2.2:3000'
  // For Physical Device: Use your machine's Local IP (e.g., 'http://192.168.1.5:3000')
  // For Production: Use your deployed URL (e.g., 'https://your-app.render.com')
  // ---------------------------------------------------------
  
  static const String baseUrl = 'https://sos-guardian-api.onrender.com'; 

  static String get statusUrl => '$baseUrl/status';
  static String get reportSosUrl => '$baseUrl/report-sos';
  static String get analyzeEmotionUrl => '$baseUrl/analyze-emotion';
  static String get sendEmailUrl => '$baseUrl/send-email';
  static String get makeCallUrl => '$baseUrl/make-call';
  static String get sendSmsUrl => '$baseUrl/send-sms';
  static String get hqDashboardUrl => '$baseUrl/hq-dashboard';
  static String get hqResolveUrl => '$baseUrl/hq-resolve';
}
