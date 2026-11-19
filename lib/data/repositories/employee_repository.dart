import 'package:rebs_hrms/core/constants/app_constants.dart';

import '../../core/network/api_client.dart';
import '../../core/network/network_info.dart';
import '../../core/storage/database_helper.dart';
import '../models/employee_model.dart';

class EmployeeRepository {
  final ApiClient apiClient;
  final DatabaseHelper dbHelper;
  final NetworkInfo networkInfo;

  EmployeeRepository({
    required this.apiClient,
    required this.dbHelper,
    required this.networkInfo,
  });

  Future<Employee> getEmployee({bool forceRefresh = false}) async {
    // 1. Try local cache first
    final cached = await dbHelper.getEmployee('EMP-1042');
    final isOnline = await networkInfo.isConnected;

    if (cached != null) {
      // Ensure coordinates match current configured office coordinates
      if (cached.officeLatitude == 28.6139) {
        final updated = cached.copyWith(
          officeLatitude: AppConstants.defaultOfficeLatitude,
          officeLongitude: AppConstants.defaultOfficeLongitude,
        );
        await dbHelper.saveEmployee(updated);
        return updated;
      }
      if (!forceRefresh && !isOnline) {
        return cached;
      }
    }

    // 2. Fetch from remote API if online
    if (isOnline) {
      try {
        final remote = await apiClient.getEmployeeProfile();
        await dbHelper.saveEmployee(remote);
        return remote;
      } catch (_) {
        // Fallback to cache if remote failed
        if (cached != null) return cached;
      }
    }

    if (cached != null) return cached;

    // Default preconfigured employee
    final defaultEmp = Employee.preconfigured();
    await dbHelper.saveEmployee(defaultEmp);
    return defaultEmp;
  }

  Future<void> updateOfficeConfig({
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required String timezone,
  }) async {
    final current = await getEmployee();
    final updated = current.copyWith(
      officeLatitude: latitude,
      officeLongitude: longitude,
      geofenceRadiusMeters: radiusMeters,
      timezone: timezone,
    );
    await dbHelper.saveEmployee(updated);
  }
}
