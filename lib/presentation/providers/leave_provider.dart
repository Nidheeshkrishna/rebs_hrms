import 'package:flutter/foundation.dart';
import '../../data/models/leave_model.dart';
import '../../data/repositories/leave_repository.dart';

class LeaveProvider extends ChangeNotifier {
  final LeaveRepository repository;

  LeaveBalance? _balance;
  List<LeaveRequest> _requests = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  LeaveProvider({required this.repository});

  LeaveBalance? get balance => _balance;
  List<LeaveRequest> get requests => _requests;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> loadLeaveData(String employeeId, {bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _balance = await repository.getLeaveBalance(forceRefresh: forceRefresh);
      _requests = await repository.getLeaveRequests(employeeId, forceRefresh: forceRefresh);
    } catch (e) {
      _errorMessage = 'Failed to load leave data: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> submitLeaveRequest({
    required String employeeId,
    required LeaveType type,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    required DateTime companyCurrentDate,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final created = await repository.submitLeaveRequest(
        employeeId: employeeId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        companyCurrentDate: companyCurrentDate,
      );

      // Refresh balance and list
      _balance = await repository.getLeaveBalance();
      _requests.insert(0, created);
      _successMessage = 'Leave application submitted successfully.';
      return true;
    } on LeaveValidationException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = 'Leave application failed: ${e.toString()}';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
