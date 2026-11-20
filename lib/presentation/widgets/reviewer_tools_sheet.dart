import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/network/mock_http_client.dart';
import '../../core/storage/database_helper.dart';
import '../../domain/services/location_service.dart';
import '../providers/attendance_provider.dart';
import '../providers/employee_provider.dart';
import '../providers/leave_provider.dart';
import '../providers/settings_provider.dart';

class ReviewerToolsSheet extends StatelessWidget {
  const ReviewerToolsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final employeeProvider = context.watch<EmployeeProvider>();
    final employee = employeeProvider.employee;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header Drag Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: Colors.blueAccent),
                        SizedBox(width: 8),
                        Text(
                          'Reviewer & Simulation Tools',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Section 1: Location Simulation
                    _buildSectionHeader('1. GPS & Geofence Simulation', Icons.my_location_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Simulate coordinates relative to the configured office (200m radius limit):',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('At Office (0m)'),
                          selected: settings.simulationMode == LocationSimulationMode.atOffice,
                          onSelected: (_) => settings.setSimulationMode(LocationSimulationMode.atOffice),
                        ),
                        ChoiceChip(
                          label: const Text('Near Office (120m)'),
                          selected: settings.simulationMode == LocationSimulationMode.withinGeofence,
                          onSelected: (_) => settings.setSimulationMode(LocationSimulationMode.withinGeofence),
                        ),
                        ChoiceChip(
                          label: const Text('Outside (450m)'),
                          selected: settings.simulationMode == LocationSimulationMode.outsideGeofence,
                          onSelected: (_) => settings.setSimulationMode(LocationSimulationMode.outsideGeofence),
                        ),
                        ChoiceChip(
                          label: const Text('Real Device GPS'),
                          selected: settings.simulationMode == LocationSimulationMode.disabled,
                          onSelected: (_) => settings.setSimulationMode(LocationSimulationMode.disabled),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 2: Mock API Scenarios
                    _buildSectionHeader('2. Repeatable Mock API Scenarios', Icons.science_rounded),
                    const SizedBox(height: 8),
                    const Text(
                      'Test edge cases, timeouts, conflict rejections, and server errors:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<MockScenario>(
                          isExpanded: true,
                          value: settings.scenario,
                          items: const [
                            DropdownMenuItem(
                              value: MockScenario.normal,
                              child: Text('Normal (200 OK / 201 Created)'),
                            ),
                            DropdownMenuItem(
                              value: MockScenario.slowTimeout,
                              child: Text('Slow Response & Timeout (>8s)'),
                            ),
                            DropdownMenuItem(
                              value: MockScenario.serverError,
                              child: Text('Server Error (500 Internal Server Error)'),
                            ),
                            DropdownMenuItem(
                              value: MockScenario.duplicateAttendanceConflict,
                              child: Text('Duplicate Attendance Conflict (409 Conflict)'),
                            ),
                            DropdownMenuItem(
                              value: MockScenario.leaveValidationRejection,
                              child: Text('Leave Policy Rejection (422 Unprocessable)'),
                            ),
                          ],
                          onChanged: (sc) {
                            if (sc != null) settings.setScenario(sc);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Section 3: Connectivity Override
                    _buildSectionHeader('3. Connectivity Simulator', Icons.wifi_tethering_rounded),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Auto (Device)')),
                            selected: settings.connectivityOverride == null,
                            onSelected: (_) => settings.setConnectivityOverride(null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Force Online')),
                            selected: settings.connectivityOverride == true,
                            onSelected: (_) => settings.setConnectivityOverride(true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(child: Text('Force Offline')),
                            selected: settings.connectivityOverride == false,
                            onSelected: (_) => settings.setConnectivityOverride(false),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section 4: Office Coordinates & Timezone
                    _buildSectionHeader('4. Company & Office Configuration', Icons.business_rounded),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Office Coordinates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${settings.officeLatitude.toStringAsFixed(4)}° N, ${settings.officeLongitude.toStringAsFixed(4)}° E • Radius: ${settings.geofenceRadius.toInt()}m',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: TextButton(
                        onPressed: () => _showEditOfficeDialog(context, settings),
                        child: const Text('Edit'),
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Company Timezone', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Text(settings.companyTimezone, style: const TextStyle(fontSize: 12)),
                    ),

                    const SizedBox(height: 24),

                    // Section 5: Reset / Clear Cache
                    _buildSectionHeader('5. Clean Slate & Reset', Icons.restart_alt_rounded),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade800,
                        elevation: 0,
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                      onPressed: () async {
                        await DatabaseHelper.instance.clearAll();
                        settings.mockHttpClient.reset();
                        if (employee != null && context.mounted) {
                          await context.read<AttendanceProvider>().initialize(employee);
                          if (context.mounted) {
                            await context.read<LeaveProvider>().loadLeaveData(employee.id, forceRefresh: true);
                          }
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Database cache and mock server reset to initial state.')),
                          );
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Reset All Local Data & Seed Fresh'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.blueAccent),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showEditOfficeDialog(BuildContext context, SettingsProvider settings) {
    final latController = TextEditingController(text: settings.officeLatitude.toString());
    final lngController = TextEditingController(text: settings.officeLongitude.toString());
    final radiusController = TextEditingController(text: settings.geofenceRadius.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Office Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latController,
              decoration: const InputDecoration(labelText: 'Office Latitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: lngController,
              decoration: const InputDecoration(labelText: 'Office Longitude'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: radiusController,
              decoration: const InputDecoration(labelText: 'Geofence Radius (meters)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final lat = double.tryParse(latController.text) ?? settings.officeLatitude;
              final lng = double.tryParse(lngController.text) ?? settings.officeLongitude;
              final rad = double.tryParse(radiusController.text) ?? settings.geofenceRadius;
              settings.updateOfficeCoordinates(lat: lat, lng: lng, radius: rad);
              context.read<EmployeeProvider>().updateOfficeLocation(lat, lng);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
