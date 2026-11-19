import 'dart:async';
import '../../core/network/network_info.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/leave_repository.dart';

class SyncService {
  final AttendanceRepository attendanceRepository;
  final LeaveRepository? leaveRepository;
  final NetworkInfo networkInfo;

  StreamSubscription<bool>? _connectivitySub;
  final _syncStatusController = StreamController<SyncResult>.broadcast();
  bool _isSyncing = false;

  SyncService({
    required this.attendanceRepository,
    this.leaveRepository,
    required this.networkInfo,
  }) {
    _initConnectivityListener();
  }

  Stream<SyncResult> get syncResults => _syncStatusController.stream;
  bool get isSyncing => _isSyncing;

  void _initConnectivityListener() {
    _connectivitySub = networkInfo.onConnectivityChanged.listen((isConnected) {
      if (isConnected && !_isSyncing) {
        // Auto-attempt sync when connectivity returns
        syncNow();
      }
    });
  }

  Future<SyncResult> syncNow({String employeeId = 'EMP-1042'}) async {
    if (_isSyncing) {
      return const SyncResult(
        total: 0,
        synced: 0,
        rejected: 0,
        failed: 0,
        errorMessage: 'Sync already in progress',
      );
    }

    _isSyncing = true;
    try {
      if (leaveRepository != null) {
        await leaveRepository!.synchronizePendingLeaves(employeeId);
      }
      final result = await attendanceRepository.synchronizePendingEvents();
      _syncStatusController.add(result);
      return result;
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncStatusController.close();
  }
}
