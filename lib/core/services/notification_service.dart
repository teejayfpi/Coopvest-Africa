import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../utils/utils.dart';
import 'deep_link_service.dart';
import '../../main.dart';

/// Notification Service — handles FCM + local notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  late final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  late final FlutterLocalNotificationsPlugin _localNotifications;

  Function(RemoteMessage)? _onMessageReceived;

  // ── Channel IDs ──────────────────────────────────────────────────────────────
  static const String _channelLoanId       = 'loan_notifications';
  static const String _channelGuarantorId  = 'guarantor_notifications';
  static const String _channelSavingsId    = 'savings_notifications';
  static const String _channelWalletId     = 'wallet_notifications';
  static const String _channelOtpId        = 'otp_notifications';
  static const String _channelGeneralId    = 'coopvest_notifications';

  // ── Init ─────────────────────────────────────────────────────────────────────

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

      // Log FCM token for debugging
      final token = await _messaging.getToken();
      logger.i('FCM Token: $token');

      // Local notifications init
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

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (details) {
          if (details.payload != null) {
            _handleNotificationTap(details.payload!);
          }
        },
      );

      await _createNotificationChannels();

      // Foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background / terminated tap-through
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(jsonEncode(message.data));
      });

      // App launched from a terminated-state notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(jsonEncode(initialMessage.data));
      }

      // Token refresh — re-register with backend whenever it changes
      _messaging.onTokenRefresh.listen((newToken) {
        logger.i('FCM token refreshed');
      });

      logger.i('Notification service initialised');
    } catch (e, stackTrace) {
      logger.e('Error initialising notification service', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // ── Channels ─────────────────────────────────────────────────────────────────

  Future<void> _createNotificationChannels() async {
    try {
      final plugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      const channels = [
        AndroidNotificationChannel(
          _channelLoanId,
          'Loan Notifications',
          description: 'Loan application and approval alerts',
          importance: Importance.high,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          _channelGuarantorId,
          'Guarantor Notifications',
          description: 'Guarantor request alerts',
          importance: Importance.high,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          _channelSavingsId,
          'Savings Notifications',
          description: 'Savings goal alerts',
          importance: Importance.defaultImportance,
          enableVibration: false,
        ),
        AndroidNotificationChannel(
          _channelWalletId,
          'Wallet Notifications',
          description: 'Wallet credit and debit alerts',
          importance: Importance.high,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          _channelOtpId,
          'OTP Notifications',
          description: 'One-time password delivery',
          importance: Importance.max,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          _channelGeneralId,
          'General Notifications',
          description: 'General Coopvest Africa alerts',
          importance: Importance.high,
          enableVibration: true,
        ),
      ];

      for (final ch in channels) {
        await plugin?.createNotificationChannel(ch);
      }
    } catch (e, stackTrace) {
      logger.e('Error creating notification channels', error: e, stackTrace: stackTrace);
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────────

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    logger.i('Foreground FCM message: ${message.messageId} type=${message.data['type']}');
    try {
      final type = message.data['type'] as String? ?? '';
      final channelId = _channelForType(type);

      await _showLocalNotification(
        title: message.notification?.title ?? 'Coopvest Africa',
        body: message.notification?.body ?? '',
        payload: jsonEncode(message.data),
        channelId: channelId,
      );

      _onMessageReceived?.call(message);
    } catch (e, stackTrace) {
      logger.e('Error handling foreground message', error: e, stackTrace: stackTrace);
    }
  }

  /// Maps a notification type string to the appropriate Android channel.
  String _channelForType(String type) {
    switch (type) {
      case 'loan_approved':
      case 'loan_update':
      case 'loan_rejected':
      case 'loan_application':
        return _channelLoanId;
      case 'guarantor_request':
      case 'guarantor_confirmed':
        return _channelGuarantorId;
      case 'savings_goal':
      case 'savings_contribution':
        return _channelSavingsId;
      case 'wallet_credited':
      case 'wallet_debited':
      case 'deposit':
      case 'withdrawal':
        return _channelWalletId;
      case 'otp':
      case 'otp_sent':
        return _channelOtpId;
      default:
        return _channelGeneralId;
    }
  }

  void _handleNotificationTap(String payload) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        logger.w('Navigator context is null, cannot route notification');
        return;
      }

      final Map<String, dynamic> data = jsonDecode(payload);

      // Deep link takes priority
      if (data.containsKey('link')) {
        final deepLinkData = DeepLinkService.parseDeepLink(data['link'] as String);
        DeepLinkNavigator.navigateToScreen(context, deepLinkData);
        return;
      }

      final type = data['type'] as String? ?? payload;
      switch (type) {
        case 'loan_approved':
        case 'loan_update':
          if (data.containsKey('loanId')) {
            navigatorKey.currentState?.pushNamed('/loan-details', arguments: {'loanId': data['loanId']});
          }
          break;
        case 'guarantor_request':
          if (data.containsKey('loanId')) {
            navigatorKey.currentState?.pushNamed('/guarantor-verification', arguments: data);
          }
          break;
        case 'savings_goal':
        case 'savings_contribution':
          navigatorKey.currentState?.pushNamed('/savings-goal');
          break;
        case 'wallet_credited':
        case 'wallet_debited':
        case 'deposit':
        case 'withdrawal':
          navigatorKey.currentState?.pushNamed('/home');
          break;
        case 'otp':
        case 'otp_sent':
          // OTP arrives in the notification body — no navigation needed,
          // the user reads it from the notification shade.
          break;
        default:
          logger.i('Unhandled notification type tapped: $type');
      }
    } catch (e) {
      logger.e('Error handling notification tap: $e');
    }
  }

  // ── Local notification display ────────────────────────────────────────────────

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required String payload,
    String channelId = _channelGeneralId,
  }) async {
    try {
      final androidDetails = AndroidNotificationDetails(
        channelId,
        _channelNameForId(channelId),
        importance: channelId == _channelOtpId ? Importance.max : Importance.high,
        priority: channelId == _channelOtpId ? Priority.max : Priority.high,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
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

  String _channelNameForId(String id) {
    switch (id) {
      case _channelLoanId:       return 'Loan Notifications';
      case _channelGuarantorId:  return 'Guarantor Notifications';
      case _channelSavingsId:    return 'Savings Notifications';
      case _channelWalletId:     return 'Wallet Notifications';
      case _channelOtpId:        return 'OTP Notifications';
      default:                   return 'Coopvest Africa Notifications';
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  void setOnMessageReceivedCallback(Function(RemoteMessage) callback) {
    _onMessageReceived = callback;
  }

  void setOnTokenRefreshCallback(Function(String) callback) {
    _messaging.onTokenRefresh.listen(callback);
  }

  Future<String?> getDeviceToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      logger.e('Error getting device token', error: e);
      return null;
    }
  }

  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      logger.i('Subscribed to FCM topic: $topic');
    } catch (e) {
      logger.e('Error subscribing to topic', error: e);
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      logger.i('Unsubscribed from FCM topic: $topic');
    } catch (e) {
      logger.e('Error unsubscribing from topic', error: e);
    }
  }

  // ── Convenience show methods ──────────────────────────────────────────────────

  Future<void> showLoanApplicationNotification(String loanType, double amount) async {
    await _showLocalNotification(
      title: 'Loan Application Received',
      body: 'Your $loanType application for \u20a6${amount.formatNumber()} has been received.',
      payload: jsonEncode({'type': 'loan_application'}),
      channelId: _channelLoanId,
    );
  }

  Future<void> showLoanApprovedNotification(String loanType, double approvedAmount) async {
    await _showLocalNotification(
      title: 'Loan Approved!',
      body: 'Congratulations! Your $loanType for \u20a6${approvedAmount.formatNumber()} has been approved.',
      payload: jsonEncode({'type': 'loan_approved'}),
      channelId: _channelLoanId,
    );
  }

  Future<void> showLoanRepaymentReminder(double amount, DateTime dueDate) async {
    final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
    await _showLocalNotification(
      title: 'Loan Repayment Reminder',
      body: 'Payment of \u20a6${amount.formatNumber()} is due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}.',
      payload: jsonEncode({'type': 'loan_repayment_reminder'}),
      channelId: _channelLoanId,
    );
  }

  Future<void> showGuarantorRequestNotification(String borrowerName, double loanAmount) async {
    await _showLocalNotification(
      title: 'Guarantee Request',
      body: '$borrowerName is requesting your guarantee for \u20a6${loanAmount.formatNumber()}.',
      payload: jsonEncode({'type': 'guarantor_request'}),
      channelId: _channelGuarantorId,
    );
  }

  Future<void> showGuarantorConfirmedNotification(String guarantorName) async {
    await _showLocalNotification(
      title: 'Guarantee Confirmed',
      body: '$guarantorName has confirmed their guarantee.',
      payload: jsonEncode({'type': 'guarantor_confirmed'}),
      channelId: _channelGuarantorId,
    );
  }

  Future<void> showSavingsGoalCompletedNotification(String goalName) async {
    await _showLocalNotification(
      title: 'Savings Goal Completed!',
      body: 'You\'ve reached your "$goalName" savings goal. Well done!',
      payload: jsonEncode({'type': 'savings_goal'}),
      channelId: _channelSavingsId,
    );
  }

  Future<void> showSavingsContributionNotification(double amount, String goalName) async {
    await _showLocalNotification(
      title: 'Savings Contribution Recorded',
      body: 'Your contribution of \u20a6${amount.formatNumber()} to "$goalName" has been recorded.',
      payload: jsonEncode({'type': 'savings_contribution'}),
      channelId: _channelSavingsId,
    );
  }

  /// Show a wallet credit notification when funds land in the user's wallet.
  Future<void> showWalletCreditedNotification(double amount, {String? description}) async {
    final desc = description != null ? ' — $description' : '';
    await _showLocalNotification(
      title: 'Wallet Credited',
      body: '\u20a6${amount.formatNumber()} has been added to your wallet$desc.',
      payload: jsonEncode({'type': 'wallet_credited'}),
      channelId: _channelWalletId,
    );
  }

  /// Show a wallet debit notification.
  Future<void> showWalletDebitedNotification(double amount, {String? description}) async {
    final desc = description != null ? ' — $description' : '';
    await _showLocalNotification(
      title: 'Wallet Debited',
      body: '\u20a6${amount.formatNumber()} was deducted from your wallet$desc.',
      payload: jsonEncode({'type': 'wallet_debited'}),
      channelId: _channelWalletId,
    );
  }

  /// Show an OTP notification — used when the OTP is delivered via push
  /// instead of (or in addition to) SMS/email.
  Future<void> showOtpNotification(String otp, {String purpose = 'verification'}) async {
    await _showLocalNotification(
      title: 'Your OTP Code',
      body: 'Your Coopvest $purpose code is $otp. It expires in 10 minutes. Do not share it.',
      payload: jsonEncode({'type': 'otp_sent'}),
      channelId: _channelOtpId,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
