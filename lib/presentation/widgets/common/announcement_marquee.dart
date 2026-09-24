import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/announcement_models.dart';
import '../../providers/announcement_provider.dart';

/// Scrolling "news ticker" for admin announcements.
///
/// Shows active announcements flagged as `displayMode: 'marquee'` (or `'all'`)
/// as a continuously scrolling line, so a member sees Coopvest news without
/// having to open the announcements list.
///
/// Deliberately dependency-free: rather than adding a marquee package, the text
/// is measured and translated with an AnimationController. It renders nothing
/// at all when there are no marquee announcements, so the home screen layout is
/// unchanged for accounts that have none.
class AnnouncementMarquee extends ConsumerStatefulWidget {
  /// Optional callback when the ticker is tapped.
  final VoidCallback? onTap;

  /// Height of the ticker strip.
  final double height;

  const AnnouncementMarquee({super.key, this.onTap, this.height = 40});

  @override
  ConsumerState<AnnouncementMarquee> createState() => _AnnouncementMarqueeState();
}

class _AnnouncementMarqueeState extends ConsumerState<AnnouncementMarquee>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // The distance the text must travel: text width + available width, so it
  // enters from the right edge and fully exits the left before repeating.
  double _travel = 0;
  bool _didRequestLoad = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    // Load once on mount. The provider is shared, so this is cheap if the
    // announcements screen has already fetched them.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLoaded());
  }

  void _ensureLoaded() {
    if (_didRequestLoad || !mounted) return;
    _didRequestLoad = true;
    final state = ref.read(announcementProvider);
    if (state.announcements.isEmpty && !state.isLoading) {
      ref.read(announcementProvider.notifier).loadAnnouncements();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Recalculate the scroll distance whenever the text or width changes.
  void _syncAnimation(List<Announcement> items) {
    final text = _tickerText(items);
    final style = const TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final screenWidth = MediaQuery.of(context).size.width;
    final needed = tp.width + screenWidth;

    if ((needed - _travel).abs() > 1) {
      _travel = needed;
      // Duration scales with distance so the scroll speed stays constant rather
      // than long announcements racing and short ones crawling.
      final seconds = (needed / 60).clamp(8.0, 60.0);
      _controller.duration = Duration(milliseconds: (seconds * 1000).round());
      _controller.repeat();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  String _tickerText(List<Announcement> items) {
    final parts = items.map((a) => a.title.trim()).where((t) => t.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    // Separator so consecutive items do not run together.
    return parts.join('     •     ');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);
    final marquee = state.announcements
        .where((a) => a.showInMarquee && !a.isExpired)
        .toList();

    // Nothing configured as a ticker: take no vertical space at all.
    if (marquee.isEmpty) return const SizedBox.shrink();

    _syncAnimation(marquee);
    final text = _tickerText(marquee);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                // A "news" marker, so the strip reads as a ticker rather than a
                // stray line of text.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'NEWS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) {
                            return Transform.translate(
                              offset: Offset(
                                constraints.maxWidth - (_controller.value * _travel),
                                0,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
