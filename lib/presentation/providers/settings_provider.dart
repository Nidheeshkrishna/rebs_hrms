import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/mock_http_client.dart';
import '../../core/network/network_info.dart';
import '../../domain/services/location_service.dart';

class SettingsProvider extends ChangeNotifier {
  final SharedPreferences prefs;
  final LocationService locationService;
  final MockHttpClient mockHttpClient;
  final NetworkInfoImpl networkInfo;

  double _officeLatitude = AppConstants.defaultOfficeLatitude;
  double _officeLongitude = AppConstants.defaultOfficeLongitude;
  double _geofenceRadius = AppConstants.geofenceRadiusMeters;
  String _companyTimezone = AppConstants.defaultTimezone;
  LocationSimulationMode _simulationMode = LocationSimulationMode.disabled;
  MockScenario _scenario = MockScenario.normal;
  bool _useInternalMock = true;
  String _baseUrl = AppConstants.defaultBaseUrl;
  bool? _connectivityOverride;

  SettingsProvider({
    required this.prefs,
    required this.locationService,
    required this.mockHttpClient,
    required this.networkInfo,
  }) {
    _loadPreferences();
  }

  double get officeLatitude => _officeLatitude;
  double get officeLongitude => _officeLongitude;
  double get geofenceRadius => _geofenceRadius;
  String get companyTimezone => _companyTimezone;
  LocationSimulationMode get simulationMode => _simulationMode;
  MockScenario get scenario => _scenario;
  bool get useInternalMock => _useInternalMock;
  String get baseUrl => _baseUrl;
  bool? get connectivityOverride => _connectivityOverride;

  void _loadPreferences() {
    _officeLatitude = prefs.getDouble('office_lat') ?? AppConstants.defaultOfficeLatitude;
    _officeLongitude = prefs.getDouble('office_lng') ?? AppConstants.defaultOfficeLongitude;
    _geofenceRadius = prefs.getDouble('geofence_radius') ?? AppConstants.geofenceRadiusMeters;
    _companyTimezone = prefs.getString('company_timezone') ?? AppConstants.defaultTimezone;
    _baseUrl = prefs.getString('base_url') ?? AppConstants.defaultBaseUrl;
    _useInternalMock = prefs.getBool('use_internal_mock') ?? true;

    final simIndex = prefs.getInt('simulation_mode') ?? LocationSimulationMode.disabled.index;
    _simulationMode = LocationSimulationMode.values[simIndex];
    locationService.setSimulationMode(_simulationMode);

    notifyListeners();
  }

  Future<void> updateOfficeCoordinates({
    required double lat,
    required double lng,
    required double radius,
  }) async {
    _officeLatitude = lat;
    _officeLongitude = lng;
    _geofenceRadius = radius;
    await prefs.setDouble('office_lat', lat);
    await prefs.setDouble('office_lng', lng);
    await prefs.setDouble('geofence_radius', radius);
    notifyListeners();
  }

  Future<void> setSimulationMode(LocationSimulationMode mode, {double? customLat, double? customLng}) async {
    _simulationMode = mode;
    locationService.setSimulationMode(mode, lat: customLat, lng: customLng);
    await prefs.setInt('simulation_mode', mode.index);
    notifyListeners();
  }

  Future<void> setScenario(MockScenario newScenario) async {
    _scenario = newScenario;
    mockHttpClient.scenario = newScenario;
    notifyListeners();
  }

  Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    await prefs.setString('base_url', url);
    notifyListeners();
  }

  Future<void> setUseInternalMock(bool value) async {
    _useInternalMock = value;
    await prefs.setBool('use_internal_mock', value);
    notifyListeners();
  }

  void setConnectivityOverride(bool? isOnline) {
    _connectivityOverride = isOnline;
    networkInfo.setManualConnectivityOverride(isOnline);
    notifyListeners();
  }

  Future<void> setCompanyTimezone(String tz) async {
    _companyTimezone = tz;
    await prefs.setString('company_timezone', tz);
    notifyListeners();
  }
}
