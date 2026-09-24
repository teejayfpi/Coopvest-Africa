/// Announcement Model - For admin broadcasts to members
///
/// The API returns `content` (translated from the table's `body`), `type`
/// (translated from `category`) and camelCase dates. This model previously read
/// only those camelCase names while the API returned snake_case, so an
/// announcement rendered blank even when a row existed. Both spellings are
/// accepted here so either contract works.
class Announcement {
  final String id;
  final String title;
  final String content;
  final String type; // 'general', 'loan', 'contribution', 'event', 'important'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isRead;
  final bool isPinned;

  /// How the app should surface it: 'banner', 'popup', 'marquee' or 'all'.
  final String displayMode;

  /// 'low' | 'normal' | 'high' | 'critical'.
  final String priority;

  /// A popup the member must dismiss, versus one they can close.
  final bool dismissible;

  /// Optional call-to-action on the banner/popup.
  final String? actionLabel;
  final String? actionUrl;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.isRead = false,
    this.isPinned = false,
    this.displayMode = 'banner',
    this.priority = 'normal',
    this.dismissible = true,
    this.actionLabel,
    this.actionUrl,
  });

  /// True when this announcement should be shown as a scrolling ticker.
  bool get showInMarquee => displayMode == 'marquee' || displayMode == 'all';

  /// True when this announcement should be shown as a card in the list.
  ///
  /// This is the DEFAULT surface, so it also covers any display mode the client
  /// does not recognise. An unrecognised value must not make an announcement
  /// invisible: a newer server sending `displayMode: 'fullscreen'` should still
  /// reach the member through the list, not silently disappear. The two
  /// specialised surfaces stay exact matches, so an unknown value cannot
  /// accidentally hijack the ticker or throw a dialog in the member's face.
  bool get showAsBanner =>
      displayMode == 'banner' ||
      displayMode == 'all' ||
      !_isKnownDisplayMode;

  bool get _isKnownDisplayMode =>
      displayMode == 'banner' ||
      displayMode == 'popup' ||
      displayMode == 'marquee' ||
      displayMode == 'all';

  /// True when this announcement should pop up as a dialog.
  bool get showAsPopup => displayMode == 'popup' || displayMode == 'all';

  factory Announcement.fromJson(Map<String, dynamic> json) {
    // Accept both the camelCase the API now returns and the snake_case the
    // table uses, so a future contract change cannot blank the UI again.
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return '';
    }

    DateTime? parseDate(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) {
          final parsed = DateTime.tryParse(v.toString());
          if (parsed != null) return parsed;
        }
      }
      return null;
    }

    return Announcement(
      id: pick(['id']),
      title: pick(['title']),
      content: pick(['content', 'body', 'message']),
      type: pick(['type', 'category']),
      createdAt: parseDate(['createdAt', 'created_at', 'publishedAt', 'published_at']) ?? DateTime.now(),
      expiresAt: parseDate(['expiresAt', 'expires_at']),
      isRead: json['isRead'] ?? json['is_read'] ?? false,
      isPinned: json['isPinned'] ?? json['is_pinned'] ?? false,
      displayMode: pick(['displayMode', 'display_mode']).isEmpty
          ? 'banner'
          : pick(['displayMode', 'display_mode']),
      priority: pick(['priority']).isEmpty ? 'normal' : pick(['priority']),
      dismissible: json['dismissible'] ?? true,
      actionLabel: json['actionLabel'] ?? json['action_label'],
      actionUrl: json['actionUrl'] ?? json['action_url'],
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
      'displayMode': displayMode,
      'priority': priority,
      'dismissible': dismissible,
      'actionLabel': actionLabel,
      'actionUrl': actionUrl,
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
    String? displayMode,
    String? priority,
    bool? dismissible,
    String? actionLabel,
    String? actionUrl,
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
      displayMode: displayMode ?? this.displayMode,
      priority: priority ?? this.priority,
      dismissible: dismissible ?? this.dismissible,
      actionLabel: actionLabel ?? this.actionLabel,
      actionUrl: actionUrl ?? this.actionUrl,
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
