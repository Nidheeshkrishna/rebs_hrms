import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/employee_model.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../domain/services/location_service.dart';

class AttendanceProvider extends ChangeNotifier {
  final AttendanceRepository repository;
  final LocationService locationService;

  AttendanceRecord? _todayRecord;
  List<AttendanceRecord> _recentRecords = [];
  List<AttendanceEvent> _queuedEvents = [];
  bool _isLoading = false;
  bool _isActionInProgress = false; // Debounce guard against rapid taps
  String? _errorMessage;
  String? _locationWarning;
  Timer? _durationTimer;
  Duration _elapsedDuration = Duration.zero;
  double? _lastKnownLat;
  double? _lastKnownLng;

  AttendanceProvider({
    required this.repository,
    required this.locationService,
  });

  AttendanceRecord? get todayRecord => _todayRecord;
  DailyAttendanceStatus get todayStatus =>
      _todayRecord?.dailyStatus ?? DailyAttendanceStatus.notCheckedIn;
  List<AttendanceRecord> get recentRecords => _recentRecords;
  List<AttendanceEvent> get queuedEvents => _queuedEvents;
  bool get isLoading => _isLoading;
  bool get isActionInProgress => _isActionInProgress;
  String? get errorMessage => _errorMessage;
  String? get locationWarning => _locationWarning;
  Duration get elapsedDuration => _elapsedDuration;
  double? get lastKnownLat => _lastKnownLat;
  double? get lastKnownLng => _lastKnownLng;

  int get pendingEventsCount =>
      _queuedEvents.where((e) => e.syncStatus == SyncStatus.pendingSync).length;

  Future<void> initialize(Employee employee) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      _todayRecord = await repository.getTodayAttendance(employee.id, now);
      _recentRecords = await repository.getAttendanceHistory(employee.id, limit: 5);
      _queuedEvents = await repository.getAllQueuedEvents();
      _updateElapsedDuration();
      _startDurationTimer();
    } catch (e) {
      _errorMessage = 'Failed to load attendance: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (todayStatus == DailyAttendanceStatus.checkedIn) {
        _updateElapsedDuration();
        notifyListeners();
      }
    });
  }

  void _updateElapsedDuration() {
    if (_todayRecord?.checkInTime != null) {
      final end = _todayRecord?.checkOutTime ?? DateTime.now();
      _elapsedDuration = end.difference(_todayRecord!.checkInTime!);
      if (_elapsedDuration.isNegative) _elapsedDuration = Duration.zero;
    } else {
      _elapsedDuration = Duration.zero;
    }
  }

  /// Check-in action with Geofencing, permission handling, and debouncing.
  Future<bool> handleCheckIn(Employee employee) async {
    if (_isActionInProgress) return false;
    _isActionInProgress = true;
    _errorMessage = null;
    _locationWarning = null;
    notifyListeners();

    try {
      // 1. Check Geofence & GPS permission
      final locResult = await locationService.checkGeofence(
        officeLat: employee.officeLatitude,
        officeLng: employee.officeLongitude,
        radiusMeters: employee.geofenceRadiusMeters,
      );

      if (locResult.latitude != null) {
        _lastKnownLat = locResult.latitude;
        _lastKnownLng = locResult.longitude;
      }

      if (!locResult.isSuccess) {
        _errorMessage = locResult.errorMessage ?? 'Location check failed';
        return false;
      }

      if (!locResult.isWithinGeofence) {
        _errorMessage = locResult.errorMessage;
        _locationWarning = locResult.errorMessage;
        return false;
      }

      // 2. Perform check-in in repository
      final now = DateTime.now();
      final updatedRecord = await repository.checkIn(
        employee: employee,
        timestamp: now,
        latitude: locResult.latitude!,
        longitude: locResult.longitude!,
        distanceMeters: locResult.distanceMeters ?? 0.0,
      );

      _todayRecord = updatedRecord;
      _updateElapsedDuration();
      await _refreshHistoryAndQueue(employee.id);
      return true;
    } on AttendanceValidationException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Check-in error: ${e.toString()}';
      return false;
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  /// Check-out action with Geofencing, permission handling, and debouncing.
  Future<bool> handleCheckOut(Employee employee) async {
    if (_isActionInProgress) return false;
    _isActionInProgress = true;
    _errorMessage = null;
    _locationWarning = null;
    notifyListeners();

    try {
      // 1. Check Geofence & GPS permission
      final locResult = await locationService.checkGeofence(
        officeLat: employee.officeLatitude,
        officeLng: employee.officeLongitude,
        radiusMeters: employee.geofenceRadiusMeters,
      );

      if (locResult.latitude != null) {
        _lastKnownLat = locResult.latitude;
        _lastKnownLng = locResult.longitude;
      }

      if (!locResult.isSuccess) {
        _errorMessage = locResult.errorMessage ?? 'Location check failed';
        return false;
      }

      if (!locResult.isWithinGeofence) {
        _errorMessage = locResult.errorMessage;
        _locationWarning = locResult.errorMessage;
        return false;
      }

      // 2. Perform check-out in repository
      final now = DateTime.now();
      final updatedRecord = await repository.checkOut(
        employee: employee,
        timestamp: now,
        latitude: locResult.latitude!,
        longitude: locResult.longitude!,
        distanceMeters: locResult.distanceMeters ?? 0.0,
      );

      _todayRecord = updatedRecord;
      _updateElapsedDuration();
      await _refreshHistoryAndQueue(employee.id);
      return true;
    } on AttendanceValidationException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Check-out error: ${e.toString()}';
      return false;
    } finally {
      _isActionInProgress = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterSync(Employee employee) async {
    final now = DateTime.now();
    _todayRecord = await repository.getTodayAttendance(employee.id, now);
    await _refreshHistoryAndQueue(employee.id);
    _updateElapsedDuration();
    notifyListeners();
  }

  Future<void> _refreshHistoryAndQueue(String employeeId) async {
    _recentRecords = await repository.getAttendanceHistory(employeeId, limit: 5);
    _queuedEvents = await repository.getAllQueuedEvents();
  }

  void clearErrorMessage() {
    _errorMessage = null;
    _locationWarning = null;
    notifyListeners();
  }

  /// Clears today's attendance records and resets session state to "Not Checked In"
  Future<void> resetAttendance(Employee employee) async {
    _durationTimer?.cancel();
    _elapsedDuration = Duration.zero;
    _todayRecord = null;
    _errorMessage = null;
    _locationWarning = null;
    await repository.resetAttendance();
    await initialize(employee);
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }
}
