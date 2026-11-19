import 'package:flutter/foundation.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/employee_repository.dart';

class EmployeeProvider extends ChangeNotifier {
  final EmployeeRepository repository;

  Employee? _employee;
  bool _isLoading = false;
  String? _errorMessage;

  EmployeeProvider({required this.repository});

  Employee? get employee => _employee;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadEmployee({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _employee = await repository.getEmployee(forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOfficeLocation(double latitude, double longitude) async {
    if (_employee == null) return;
    await repository.updateOfficeConfig(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: _employee!.geofenceRadiusMeters,
      timezone: _employee!.timezone,
    );
    await loadEmployee(forceRefresh: true);
  }
}
