import 'package:equatable/equatable.dart';

/// App Notification Model
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type; // loan_approved, contribution, guarantor_request, repayment_reminder, etc.
  final String icon;
  final String color;
  final DateTime timestamp;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.icon,
    required this.color,
    required this.timestamp,
    this.isRead = false,
    this.metadata,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      icon: json['icon'] as String? ?? 'notifications',
      color: json['color'] as String? ?? '#1B5E20',
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['is_read'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'type': type,
      'icon': icon,
      'color': color,
      'timestamp': timestamp.toIso8601String(),
      'is_read': isRead,
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    String? icon,
    String? color,
    DateTime? timestamp,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    body,
    type,
    icon,
    color,
    timestamp,
    isRead,
    metadata,
  ];
}
