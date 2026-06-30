import 'package:flutter/material.dart';

/// Pull-to-refresh wrapper for consistent refresh pattern
class PullToRefresh extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final String? refreshMessage;

  const PullToRefresh({
    Key? key,
    required this.child,
    required this.onRefresh,
    this.refreshMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

/// Pull-to-refresh list view with common patterns
class PullToRefreshListView extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function() onRefresh;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;
  final bool addAutomaticKeepAlive;

  const PullToRefreshListView({
    Key? key,
    required this.children,
    required this.onRefresh,
    this.controller,
    this.padding,
    this.addAutomaticKeepAlive = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        controller: controller,
        padding: padding ?? const EdgeInsets.all(16),
        children: children,
        addAutomaticKeepAlives: addAutomaticKeepAlive,
      ),
    );
  }
}

/// Pull-to-refresh sliver list
class PullToRefreshSliverList extends StatelessWidget {
  final Widget Function(BuildContext, int) itemBuilder;
  final int itemCount;
  final Future<void> Function() onRefresh;
  final EdgeInsetsGeometry? padding;

  const PullToRefreshSliverList({
    Key? key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onRefresh,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding ?? const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                itemBuilder,
                childCount: itemCount,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
