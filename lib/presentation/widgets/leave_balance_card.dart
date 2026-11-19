import 'package:flutter/material.dart';
import '../../data/models/leave_model.dart';

class LeaveBalanceCard extends StatelessWidget {
  final LeaveBalance? balance;
  final bool isLoading;
  final VoidCallback onApplyLeave;
  final VoidCallback onViewHistory;

  const LeaveBalanceCard({
    super.key,
    required this.balance,
    required this.isLoading,
    required this.onApplyLeave,
    required this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.beach_access_rounded, color: Colors.purple.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Leave Balance',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Annual entitlement',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: onViewHistory,
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isLoading && balance == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildBalancePill(
                      label: 'Casual Leave',
                      days: balance?.casual ?? 0,
                      color: Colors.blue.shade700,
                      bgColor: Colors.blue.shade50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBalancePill(
                      label: 'Sick Leave',
                      days: balance?.sick ?? 0,
                      color: Colors.teal.shade700,
                      bgColor: Colors.teal.shade50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildBalancePill(
                      label: 'Total Balance',
                      days: balance?.total ?? 0,
                      color: Colors.deepPurple.shade700,
                      bgColor: Colors.deepPurple.shade50,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: onApplyLeave,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Apply for Leave'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalancePill({
    required String label,
    required int days,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            '$days',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}
