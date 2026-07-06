import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool>? _connectionStatusController;
  bool _isConnected = true;

  /// Get the connection status stream
  Stream<bool> get connectionStream {
    _connectionStatusController ??= StreamController<bool>.broadcast();
    return _connectionStatusController!.stream;
  }

  /// Check if currently connected
  bool get isConnected => _isConnected;

  /// Initialize and start listening for connectivity changes
  Future<void> initialize() async {
    // Check initial status
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    
    // Listen for changes (v6 returns List<ConnectivityResult>)
    _connectivity.onConnectivityChanged.listen((results) {
      _updateConnectionStatus(results);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final hasConnection = results.isNotEmpty && 
        !results.contains(ConnectivityResult.none);
    
    if (_isConnected != hasConnection) {
      _isConnected = hasConnection;
      _connectionStatusController?.add(_isConnected);
    }
  }

  /// Check connectivity manually
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    _updateConnectionStatus(results);
    return _isConnected;
  }

  /// Dispose the service
  void dispose() {
    _connectionStatusController?.close();
    _connectionStatusController = null;
  }
}

/// Provider for connectivity service
final connectivityService = ConnectivityService();