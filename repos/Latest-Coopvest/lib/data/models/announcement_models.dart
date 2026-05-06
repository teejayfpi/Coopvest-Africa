/// Announcement Model - For admin broadcasts to all members
class Announcement {
  final String id;
  final String title;
  final String content;
  final String type; // 'general', 'loan', 'contribution', 'event', 'important'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isPinned;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.isRead = false,
    this.isPinned = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: json['type'] ?? 'general',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'])
          : null,
      isRead: json['isRead'] ?? false,
      isPinned: json['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isRead': isRead,
      'isPinned': isPinned,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isRead,
    bool? isPinned,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isRead: isRead ?? this.isRead,
      isPinned: isPinned ?? this.isPinned,
    );
  }
}

/// Response model for announcements list
class AnnouncementsResponse {
  final List<Announcement> announcements;
  final int unreadCount;
  final int totalCount;

  AnnouncementsResponse({
    required this.announcements,
    required this.unreadCount,
    required this.totalCount,
  });

  factory AnnouncementsResponse.fromJson(Map<String, dynamic> json) {
    return AnnouncementsResponse(
      announcements: (json['announcements'] as List<dynamic>?)
              ?.map((x) => Announcement.fromJson(x))
              .toList() ??
          [],
      unreadCount: json['unreadCount'] ?? 0,
      totalCount: json['totalCount'] ?? 0,
    );
  }
}
