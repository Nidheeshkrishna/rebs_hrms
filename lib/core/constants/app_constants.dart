class AppConstants {
  static const String appName = 'REBS HRMS';
  
  // Default Office Coordinates (HQ)
  // Configured Coordinates: 10.0159° N, 76.3419° E
  static const double defaultOfficeLatitude = 10.0159;
  static const double defaultOfficeLongitude = 76.3419;
  static const double geofenceRadiusMeters = 200.0;
  
  // Timezone
  static const String defaultTimezone = 'Asia/Kolkata (UTC+05:30)';
  static const int defaultTimezoneOffsetMinutes = 330; // 5 hours 30 mins

  // Preconfigured Employee
  static const String defaultEmployeeId = 'EMP-1042';
  static const String defaultEmployeeName = 'Alexander Wright';
  static const String defaultEmployeeDepartment = 'Core Business Automation';
  static const String defaultEmployeeRole = 'Senior Software Engineer';

  // API Config
  static const String defaultBaseUrl = 'http://localhost:8080';
  static const Duration apiTimeout = Duration(seconds: 8);

  // Sync intervals
  static const Duration syncRetryInterval = Duration(seconds: 30);
}
