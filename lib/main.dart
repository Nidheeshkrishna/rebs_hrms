import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/constants/app_constants.dart';
import 'core/network/api_client.dart';
import 'core/network/mock_http_client.dart';
import 'core/network/network_info.dart';
import 'core/storage/database_helper.dart';
import 'data/repositories/attendance_repository.dart';
import 'data/repositories/employee_repository.dart';
import 'data/repositories/leave_repository.dart';
import 'domain/services/location_service.dart';
import 'domain/services/sync_service.dart';
import 'presentation/providers/attendance_provider.dart';
import 'presentation/providers/employee_provider.dart';
import 'presentation/providers/leave_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/sync_provider.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final dbHelper = DatabaseHelper.instance;
  final connectivity = Connectivity();
  final networkInfo = NetworkInfoImpl(connectivity: connectivity);
  final locationService = LocationService();
  final mockHttpClient = MockHttpClient();

  final apiClient = ApiClient(
    client: mockHttpClient,
    baseUrl: AppConstants.defaultBaseUrl,
  );

  // Repositories
  final employeeRepository = EmployeeRepository(
    apiClient: apiClient,
    dbHelper: dbHelper,
    networkInfo: networkInfo,
  );

  final attendanceRepository = AttendanceRepository(
    apiClient: apiClient,
    dbHelper: dbHelper,
    networkInfo: networkInfo,
  );

  final leaveRepository = LeaveRepository(
    apiClient: apiClient,
    dbHelper: dbHelper,
    networkInfo: networkInfo,
  );

  final syncService = SyncService(
    attendanceRepository: attendanceRepository,
    leaveRepository: leaveRepository,
    networkInfo: networkInfo,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SettingsProvider(
            prefs: prefs,
            locationService: locationService,
            mockHttpClient: mockHttpClient,
            networkInfo: networkInfo,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => EmployeeProvider(repository: employeeRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AttendanceProvider(
            repository: attendanceRepository,
            locationService: locationService,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => LeaveProvider(repository: leaveRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              SyncProvider(syncService: syncService, networkInfo: networkInfo),
        ),
      ],
      child: const RebsHrmsApp(),
    ),
  );
}

class RebsHrmsApp extends StatelessWidget {
  const RebsHrmsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2),
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF00897B),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 1.5,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
