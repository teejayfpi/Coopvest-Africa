import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Feature flags service for Flutter mobile app
/// Connects to admin backend to get feature configurations
class FeatureService {
  static final FeatureService _instance = FeatureService._internal();
  factory FeatureService() => _instance;
  FeatureService._internal();

  final String _baseUrl = 'http://localhost:5000/api';
  static const String _cacheKey = 'feature_flags_cache';
  static const Duration _cacheDuration = Duration(hours: 1);
  
  final Map<String, FeatureFlag> _features = {};
  Timer? _refreshTimer;
  bool _isInitialized = false;

  // Feature flag definitions
  static const Map<String, String> featureNames = {
    'loan_application': 'Loan Application',
    'guarantor_system': 'Guarantor System',
    'qr_verification': 'QR Code Verification',
    'two_factor_auth': 'Two Factor Authentication',
    'advanced_analytics': 'Advanced Analytics',
    'push_notifications': 'Push Notifications',
    'email_notifications': 'Email Notifications',
    'referral_program': 'Referral Program',
    'investment_features': 'Investment Features',
    'offline_mode': 'Offline Mode',
    'biometric_login': 'Biometric Login',
    'salary_deduction': 'Salary Deduction',
    'rollover_requests': 'Rollover Requests',
    'risk_scoring': 'Risk Scoring',
    'compliance_tools': 'Compliance Tools',
  };

  /// Initialize the feature service
  Future<void> init() async {
    if (_isInitialized) return;
    
    await _loadFromCache();
    await _fetchFeatures();
    _startAutoRefresh();
    _isInitialized = true;
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _fetchFeatures(),
    );
  }

  /// Stop auto-refresh
  void dispose() {
    _refreshTimer?.cancel();
  }

  /// Load features from local cache
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = prefs.getString(_cacheKey);
      
      if (cacheData != null) {
        final Map<String, dynamic> cache = jsonDecode(cacheData);
        final timestamp = DateTime.tryParse(cache['timestamp'] ?? '');
        
        if (timestamp != null && 
            DateTime.now().difference(timestamp) < _cacheDuration) {
          final features = cache['features'] as Map<String, dynamic>;
          for (final entry in features.entries) {
            _features[entry.key] = FeatureFlag.fromJson(entry.value);
          }
        }
      }
    } catch (e) {
      // Cache load failed, continue with empty features
    }
  }

  /// Save features to local cache
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cache = {
        'timestamp': DateTime.now().toIso8601String(),
        'features': _features.map((k, v) => MapEntry(k, v.toJson())),
      };
      await prefs.setString(_cacheKey, jsonEncode(cache));
    } catch (e) {
      // Cache save failed
    }
  }

  /// Fetch features from backend
  Future<void> _fetchFeatures() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/features/platform/mobile'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10)); // Add 10 second timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final features = data['data'] as List;
          for (final feature in features) {
            final flag = FeatureFlag.fromJson(feature);
            _features[flag.name] = flag;
          }
          await _saveToCache();
        }
      }
    } catch (e) {
      // Network error or timeout, keep cached values or default to empty
      // App should still work even if feature service fails
    }
  }

  /// Check if a feature is enabled
  bool isEnabled(String featureName) {
    final flag = _features[featureName];
    return flag?.enabled ?? false;
  }

  /// Get feature flag details
  FeatureFlag? getFeature(String featureName) => _features[featureName];

  /// Get all enabled features
  List<FeatureFlag> getEnabledFeatures() {
    final priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
    return _features.values.where((f) => f.enabled).toList()
      ..sort((a, b) => (priorityOrder[a.priority] ?? 2).compareTo(priorityOrder[b.priority] ?? 2));
  }

  /// Get feature by category
  List<FeatureFlag> getFeaturesByCategory(String category) {
    return _features.values
        .where((f) => f.category == category)
        .toList();
  }

  /// Get all unique categories
  List<String> getAllCategories() {
    return _features.values.map((f) => f.category).toSet().toList();
  }

  /// Manually refresh features
  Future<void> refresh() async => _fetchFeatures();

  /// Get all features as a map
  Map<String, FeatureFlag> getAllFeatures() => Map.from(_features);
}

/// Feature flag model
class FeatureFlag {
  final String name;
  final String displayName;
  final String description;
  final String category;
  final List<String> platforms;
  final bool enabled;
  final int rolloutPercentage;
  final String targetAudience;
  final List<String> targetRegions;
  final String priority;
  final String status;
  final Map<String, dynamic> config;
  final DateTime? startDate;
  final DateTime? endDate;

  FeatureFlag({
    required this.name,
    required this.displayName,
    required this.description,
    required this.category,
    required this.platforms,
    required this.enabled,
    required this.rolloutPercentage,
    required this.targetAudience,
    required this.targetRegions,
    required this.priority,
    required this.status,
    required this.config,
    this.startDate,
    this.endDate,
  });

  factory FeatureFlag.fromJson(Map<String, dynamic> json) {
    return FeatureFlag(
      name: json['name'] ?? '',
      displayName: json['displayName'] ?? json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'other',
      platforms: List<String>.from(json['platforms'] ?? []),
      enabled: json['enabled'] ?? false,
      rolloutPercentage: json['rolloutPercentage'] ?? 0,
      targetAudience: json['targetAudience'] ?? 'all',
      targetRegions: List<String>.from(json['targetRegions'] ?? []),
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'planning',
      config: Map<String, dynamic>.from(json['config'] ?? {}),
      startDate: json['startDate'] != null 
          ? DateTime.tryParse(json['startDate']) 
          : null,
      endDate: json['endDate'] != null 
          ? DateTime.tryParse(json['endDate']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'displayName': displayName,
    'description': description,
    'category': category,
    'platforms': platforms,
    'enabled': enabled,
    'rolloutPercentage': rolloutPercentage,
    'targetAudience': targetAudience,
    'targetRegions': targetRegions,
    'priority': priority,
    'status': status,
    'config': config,
    'startDate': startDate?.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
  };

  /// Check if feature is currently active based on dates
  bool get isActive {
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return status == 'active';
  }
}

/// Extension methods for common feature checks
extension FeatureExtensions on FeatureService {
  bool get loansEnabled => isEnabled('loan_application');
  bool get guarantorEnabled => isEnabled('guarantor_system');
  bool get qrEnabled => isEnabled('qr_verification');
  bool get biometricEnabled => isEnabled('biometric_login');
  bool get referralEnabled => isEnabled('referral_program');
  bool get investmentEnabled => isEnabled('investment_features');
  bool get offlineEnabled => isEnabled('offline_mode');
  bool get rolloverEnabled => isEnabled('rollover_requests');
  bool get pushEnabled => isEnabled('push_notifications');
  bool get emailEnabled => isEnabled('email_notifications');
}
