import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onConnectivityChanged;
}

class NetworkInfoImpl implements NetworkInfo {
  final Connectivity connectivity;
  bool? _overrideConnected; // Reviewer manual toggle

  NetworkInfoImpl({required this.connectivity});

  void setManualConnectivityOverride(bool? override) {
    _overrideConnected = override;
  }

  @override
  Future<bool> get isConnected async {
    if (_overrideConnected != null) return _overrideConnected!;
    try {
      final results = await connectivity.checkConnectivity();
      return _hasConnection(results);
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<bool> get onConnectivityChanged {
    return connectivity.onConnectivityChanged.map((results) {
      if (_overrideConnected != null) return _overrideConnected!;
      return _hasConnection(results);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet);
  }
}
