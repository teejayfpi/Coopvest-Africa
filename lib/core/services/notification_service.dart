import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../utils/utils.dart';

/// Notification Service - Handles Firebase Cloud Messaging
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _localNotifications;
  
  Function(RemoteMessage)? _onMessageReceived;
  // final _onBackgroundMessage = _handleBackgroundMessage;

  // Channel IDs
  static const String _channelLoanId = 'loan_notifications';
  static const String _channelGuarantorId = 'guarantor_notifications';
  static const String _channelSavingsId = 'savings_notifications';

  /// Initialize notification service
  Future<void> init() async {
    try {
      _localNotifications = FlutterLocalNotificationsPlugin();
      
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        logger.i('Notification permission granted');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        logger.i('Notification permission granted (provisional)');
      } else {
        logger.w('Notification permission denied');
      }

      // Get FCM token
      final token = await _messaging.getToken();
      logger.i('FCM Token: $token');

      // Set up local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(initSettings);

      // Create notification channels
      await _createNotificationChannels();

      // Set message handlers
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);

      logger.i('Notification service initialized');
    } catch (e, stackTrace) {
      logger.e('Error initializing notification service', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    try {
      const loanChannel = AndroidNotificationChannel(
        _channelLoanId,
        'Loan Notifications',
        description: 'Notifications for loan applications and updates',
        importance: Importance.high,
        enableVibration: true,
      );

      const guarantorChannel = AndroidNotificationChannel(
        _channelGuarantorId,
        'Guarantor Notifications',
        description: 'Notifications for guarantor requests',
        importance: Importance.high,
        enableVibration: true,
      );

      const savingsChannel = AndroidNotificationChannel(
        _channelSavingsId,
        'Savings Notifications',
        description: 'Notifications for savings goals',
        importance: Importance.low,
        enableVibration: false,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(loanChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(guarantorChannel);

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(savingsChannel);
    } catch (e, stackTrace) {
      logger.e('Error creating notification channels', error: e, stackTrace: stackTrace);
    }
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    logger.i('Foreground message received: ${message.messageId}');
    
    try {
      // Show local notification
      _showLocalNotification(
        title: message.notification?.title ?? 'Coopvest Africa',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
      ).catchError((e) {
        logger.e('Error showing local notification', error: e);
      });

      // Call callback
      if (_onMessageReceived != null) {
        try {
          _onMessageReceived!(message);
        } catch (e) {
          logger.e('Error in onMessageReceived callback', error: e);
        }
      }
    } catch (e, stackTrace) {
      logger.e('Error handling foreground message', error: e, stackTrace: stackTrace);
    }
  }

  /// Handle background messages
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    logger.i('Background message received: ${message.messageId}');
    // Perform background work here if needed
  }

  /// Set foreground message callback
  void setOnMessageReceivedCallback(Function(RemoteMessage) callback) {
    _onMessageReceived = callback;
  }

  /// Get device notification token
  Future<String?> getDeviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      logger.e('Error getting device token', error: e);
      return null;
    }
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      logger.i('Subscribed to topic: $topic');
    } catch (e) {
      logger.e('Error subscribing to topic', error: e);
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      logger.i('Unsubscribed from topic: $topic');
    } catch (e) {
      logger.e('Error unsubscribing from topic', error: e);
    }
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'coopvest_notifications',
        'Coopvest Africa Notifications',
        channelDescription: 'General notifications',
        importance: Importance.high,
        priority: Priority.high,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e, stackTrace) {
      logger.e('Error showing local notification', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Notification types
  // static const int _loanApplicationId = 1001;
  // static const int _loanApprovedId = 1002;
  // static const int _loanRepaymentId = 1003;
  // static const int _guarantorRequestId = 2001;
  // static const int _guarantorConfirmedId = 2002;
  // static const int _savingsGoalId = 3001;
  // static const int _savingsContributionId = 3002;

  // Show specific notifications
  Future<void> showLoanApplicationNotification(String loanType, double amount) async {
    try {
      await _showLocalNotification(
        title: 'Loan Application Received',
        body: 'Your $loanType application for ₦${amount.formatNumber()} has been received.',
        payload: 'loan_application',
      );
      logger.i('Shown loan application notification');
    } catch (e, stackTrace) {
      logger.e('Error showing loan application notification', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showLoanApprovedNotification(String loanType, double approvedAmount) async {
    try {
      await _showLocalNotification(
        title: 'Loan Approved! 🎉',
        body: 'Congratulations! Your $loanType for ₦${approvedAmount.formatNumber()} has been approved.',
        payload: 'loan_approved',
      );
      logger.i('Shown loan approved notification');
    } catch (e, stackTrace) {
      logger.e('Error showing loan approved notification', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showLoanRepaymentReminder(double amount, DateTime dueDate) async {
    try {
      final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
      await _showLocalNotification(
        title: 'Loan Repayment Reminder',
        body: 'Payment of ₦${amount.formatNumber()} is due in $daysUntilDue days.',
        payload: 'loan_repayment_reminder',
      );
      logger.i('Shown loan repayment reminder notification');
    } catch (e, stackTrace) {
      logger.e('Error showing loan repayment reminder', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showGuarantorRequestNotification(String borrowerName, double loanAmount) async {
    try {
      await _showLocalNotification(
        title: 'Guarantee Request',
        body: '$borrowerName is requesting your guarantee for ₦${loanAmount.formatNumber()}.',
        payload: 'guarantor_request',
      );
      logger.i('Shown guarantor request notification');
    } catch (e, stackTrace) {
      logger.e('Error showing guarantor request notification', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showGuarantorConfirmedNotification(String guarantorName) async {
    try {
      await _showLocalNotification(
        title: 'Guarantee Confirmed ✓',
        body: '$guarantorName has confirmed their guarantee.',
        payload: 'guarantor_confirmed',
      );
      logger.i('Shown guarantor confirmed notification');
    } catch (e, stackTrace) {
      logger.e('Error showing guarantor confirmed notification', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showSavingsGoalCompletedNotification(String goalName) async {
    try {
      await _showLocalNotification(
        title: 'Savings Goal Completed! 🎉',
        body: 'Congratulations! You\'ve reached your "$goalName" savings goal.',
        payload: 'savings_goal_completed',
      );
      logger.i('Shown savings goal completed notification');
    } catch (e, stackTrace) {
      logger.e('Error showing savings goal notification', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> showSavingsContributionNotification(double amount, String goalName) async {
    try {
      await _showLocalNotification(
        title: 'Savings Contribution Recorded',
        body: 'Your contribution of ₦${amount.formatNumber()} to "$goalName" has been recorded.',
        payload: 'savings_contribution',
      );
      logger.i('Shown savings contribution notification');
    } catch (e, stackTrace) {
      logger.e('Error showing savings contribution notification', error: e, stackTrace: stackTrace);
    }
  }

  // Set callbacks
  void setOnTokenRefreshCallback(Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
