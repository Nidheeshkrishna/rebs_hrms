import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/employee_model.dart';
import '../../data/models/leave_model.dart';
import '../providers/leave_provider.dart';
import '../providers/sync_provider.dart';

class LeaveApplyScreen extends StatefulWidget {
  final Employee employee;

  const LeaveApplyScreen({super.key, required this.employee});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();

  LeaveType _selectedType = LeaveType.casual;
  late DateTime _startDate;
  late DateTime _endDate;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _startDate = today;
    _endDate = today;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _calculatedDays => AppDateUtils.calculateLeaveDays(_startDate, _endDate);

  @override
  Widget build(BuildContext context) {
    final leaveProvider = context.watch<LeaveProvider>();
    final syncProvider = context.watch<SyncProvider>();
    final balance = leaveProvider.balance;
    final available = balance != null ? balance.getBalanceFor(_selectedType) : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Offline Alert Banner
              if (!syncProvider.isOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.cloud_off_rounded, color: Color(0xFF1976D2), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Working Offline: You can submit your leave request now. It will be stored safely on your device and will auto-sync when connection is restored.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF0D47A1), fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // Balance summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available ${_selectedType.label}:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    Text(
                      '$available days',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Leave Type Selector
              const Text(
                'Leave Type',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<LeaveType>(
                      title: const Text('Casual'),
                      value: LeaveType.casual,
                      groupValue: _selectedType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<LeaveType>(
                      title: const Text('Sick'),
                      value: LeaveType.sick,
                      groupValue: _selectedType,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedType = val);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Date Range Selectors
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isStart: true),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppDateUtils.formatDisplayDate(_startDate),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cannot be before today',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('End Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _pickDate(isStart: false),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppDateUtils.formatDisplayDate(_endDate),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cannot be before start date',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              Text(
                'Total Duration: $_calculatedDays ${_calculatedDays == 1 ? "day" : "days"} (All calendar days count)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
              ),

              const SizedBox(height: 20),

              // Reason Input
              const Text(
                'Reason for Leave (at least 10 non-whitespace characters)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Enter a detailed reason for leave...',
                  hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (_) => setState(() {}),
                validator: (val) {
                  final text = val ?? '';
                  final count = text.replaceAll(RegExp(r'\s+'), '').length;
                  if (count < 10) {
                    return 'Reason must have at least 10 characters ($count/10)';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Character count: ${_reasonController.text.replaceAll(RegExp(r'\s+'), '').length} / 10 required',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),

              // Inline error banner
              if (_inlineError != null || leaveProvider.errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: Colors.red.shade800, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _inlineError ?? leaveProvider.errorMessage!,
                          style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: leaveProvider.isSubmitting ? null : _submit,
                  icon: leaveProvider.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(leaveProvider.isSubmitting ? 'Submitting...' : 'Submit Application'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime initialDate = isStart
        ? (_startDate.isBefore(today) ? today : _startDate)
        : (_endDate.isBefore(_startDate) ? _startDate : _endDate);

    final DateTime firstDate = isStart ? today : _startDate;
    final DateTime lastDate = DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isStart ? 'Select Start Date (Today or Later)' : 'Select End Date (On or After Start Date)',
    );

    if (picked != null) {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      setState(() {
        if (isStart) {
          _startDate = normalized;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = normalized;
        }
        _inlineError = null;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _inlineError = null);
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);

    // Business rule 1: Start date cannot be before current company date
    if (start.isBefore(today)) {
      setState(() {
        _inlineError =
            'Start date cannot be before current company date (${AppDateUtils.formatDisplayDate(today)}).';
      });
      return;
    }

    // Business rule 2: End date cannot be before start date
    if (end.isBefore(start)) {
      setState(() {
        _inlineError = 'End date cannot be before start date.';
      });
      return;
    }

    final leaveProv = context.read<LeaveProvider>();
    final success = await leaveProv.submitLeaveRequest(
      employeeId: widget.employee.id,
      type: _selectedType,
      startDate: start,
      endDate: end,
      reason: _reasonController.text.trim(),
      companyCurrentDate: today,
    );

    if (success && mounted) {
      final isOnline = context.read<SyncProvider>().isOnline;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Leave application submitted successfully!'
                : 'Leave application saved offline! It will sync automatically when connected.',
          ),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted && leaveProv.errorMessage != null) {
      setState(() {
        _inlineError = leaveProv.errorMessage;
      });
    }
  }
}
