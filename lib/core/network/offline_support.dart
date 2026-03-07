import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Connection Status Enum
enum ConnectionStatus {
  online,
  offline,
  unknown,
}

/// Network Connectivity Notifier
class NetworkNotifier extends StateNotifier<ConnectionStatus> {
  final Connectivity _connectivity;

  NetworkNotifier(this._connectivity) : super(ConnectionStatus.unknown) {
    _initialize();
  }

  Future<void> _initialize() async {
    // Check initial status
    final results = await _connectivity.checkConnectivity();
    _updateStatus(results);

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((results) {
      _updateStatus(results);
    });
  }

  void _updateStatus(dynamic results) {
    // Handle both single result and list of results
    List<ConnectivityResult> resultList;
    if (results is List<ConnectivityResult>) {
      resultList = results;
    } else if (results is ConnectivityResult) {
      resultList = [results];
    } else {
      resultList = [];
    }
    
    if (resultList.isEmpty || resultList.contains(ConnectivityResult.none)) {
      state = ConnectionStatus.offline;
    } else {
      state = ConnectionStatus.online;
    }
  }

  Future<bool> checkInternetConnection() async {
    final results = await _connectivity.checkConnectivity();
    final resultList = _convertToList(results);
    return resultList.isNotEmpty && !resultList.contains(ConnectivityResult.none);
  }

  List<ConnectivityResult> _convertToList(dynamic results) {
    if (results is List<ConnectivityResult>) {
      return results;
    } else if (results is List) {
      return results.cast<ConnectivityResult>();
    } else if (results is ConnectivityResult) {
      return [results];
    } else {
      return [];
    }
  }
}

/// Network Provider
final networkProvider = StateNotifierProvider<NetworkNotifier, ConnectionStatus>((ref) {
  final connectivity = Connectivity();
  return NetworkNotifier(connectivity);
});

/// Is Online Provider
final isOnlineProvider = Provider<bool>((ref) {
  final status = ref.watch(networkProvider);
  return status == ConnectionStatus.online;
});

/// Offline Data Manager for Caching and Sync
class OfflineDataManager {
  static const String _pendingOperationsKey = 'pending_operations';
  static const String _cachedDataKey = 'cached_data';

  // Save operation to be synced later
  Future<void> savePendingOperation(Map<String, dynamic> operation) async {
    final prefs = await SharedPreferences.getInstance();
    final operations = prefs.getStringList(_pendingOperationsKey) ?? [];
    operations.add(operation.toString());
    await prefs.setStringList(_pendingOperationsKey, operations);
  }

  // Get all pending operations
  Future<List<Map<String, dynamic>>> getPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    final operations = prefs.getStringList(_pendingOperationsKey) ?? [];
    return operations.map((e) => {'data': e}).toList();
  }

  // Clear pending operations after successful sync
  Future<void> clearPendingOperations() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOperationsKey);
  }

  // Cache data for offline access
  Future<void> cacheData(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachedDataKey:$key', data.toString());
  }

  // Get cached data
  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('$_cachedDataKey:$key');
    if (data != null) {
      return {'data': data};
    }
    return null;
  }

  // Clear cached data
  Future<void> clearCache(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_cachedDataKey:$key');
  }

  // Clear all cache
  Future<void> clearAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith(_cachedDataKey));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

/// Offline Data Manager Provider
final offlineDataManagerProvider = Provider<OfflineDataManager>((ref) {
  return OfflineDataManager();
});

/// Sync Status Enum
enum SyncStatus {
  idle,
  syncing,
  success,
  error,
}

/// Sync Notifier
class SyncNotifier extends StateNotifier<SyncStatus> {
  final OfflineDataManager _offlineDataManager;
  final Function _syncCallback;

  SyncNotifier(this._offlineDataManager, this._syncCallback) : super(SyncStatus.idle);

  Future<void> syncPendingOperations() async {
    state = SyncStatus.syncing;

    try {
      final pendingOperations = await _offlineDataManager.getPendingOperations();
      
      if (pendingOperations.isEmpty) {
        state = SyncStatus.success;
        return;
      }

      // Process each pending operation
      for (final operation in pendingOperations) {
        try {
          await _syncCallback(operation);
        } catch (e) {
          state = SyncStatus.error;
          return;
        }
      }

      // Clear pending operations after successful sync
      await _offlineDataManager.clearPendingOperations();
      state = SyncStatus.success;
    } catch (e) {
      state = SyncStatus.error;
    }
  }

  void reset() {
    state = SyncStatus.idle;
  }
}

/// Sync Provider
final syncProvider = StateNotifierProvider<SyncNotifier, SyncStatus>((ref) {
  final offlineDataManager = ref.read(offlineDataManagerProvider);
  // This would be a callback to sync data with the server
  Future<void> syncCallback(Map<String, dynamic> operation) async {
    // Simulate sync operation
    await Future.delayed(const Duration(milliseconds: 100));
  }
  
  return SyncNotifier(offlineDataManager, syncCallback);
});

/// Connection Aware Widget
class ConnectionAwareBuilder extends ConsumerWidget {
  final Widget Function(bool isOnline) builder;
  final Widget? offlineWidget;
  final Widget? loadingWidget;

  const ConnectionAwareBuilder({
    super.key,
    required this.builder,
    this.offlineWidget,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(networkProvider);

    switch (connectionStatus) {
      case ConnectionStatus.unknown:
        return loadingWidget ?? const Center(child: CircularProgressIndicator());
      case ConnectionStatus.offline:
        return offlineWidget ?? _defaultOfflineWidget();
      case ConnectionStatus.online:
        return builder(true);
    }
  }

  Widget _defaultOfflineWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// Auto-sync on reconnection
class AutoSyncOnReconnect extends ConsumerStatefulWidget {
  final Widget child;

  const AutoSyncOnReconnect({super.key, required this.child});

  @override
  ConsumerState<AutoSyncOnReconnect> createState() => _AutoSyncOnReconnectState();
}

class _AutoSyncOnReconnectState extends ConsumerState<AutoSyncOnReconnect> {
  ConnectionStatus _previousStatus = ConnectionStatus.unknown;

  @override
  void initState() {
    super.initState();
    _setupReconnectListener();
  }

  void _setupReconnectListener() {
    ref.listenManual<ConnectionStatus>(networkProvider, (previous, current) {
      if (_previousStatus == ConnectionStatus.offline && current == ConnectionStatus.online) {
        // Auto-sync when coming back online
        ref.read(syncProvider.notifier).syncPendingOperations();
      }
      _previousStatus = current;
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
