import 'package:flutter/material.dart';

/// Custom animation utilities for smooth transitions and effects
class AppAnimations {
  // Fade animations
  static Widget fadeIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
  }) {
    return AnimatedFadeIn(
      child: child,
      duration: duration,
      curve: curve,
    );
  }

  // Slide animations
  static Widget slideInUp({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double offset = 50.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return AnimatedSlideInUp(
      child: child,
      duration: duration,
      offset: offset,
      curve: curve,
    );
  }

  static Widget slideInLeft({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double offset = 50.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return AnimatedSlideInLeft(
      child: child,
      duration: duration,
      offset: offset,
      curve: curve,
    );
  }

  static Widget slideInRight({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    double offset = 50.0,
    Curve curve = Curves.easeOutCubic,
  }) {
    return AnimatedSlideInRight(
      child: child,
      duration: duration,
      offset: offset,
      curve: curve,
    );
  }

  // Scale animations
  static Widget scaleIn({
    required Widget child,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeOutBack,
  }) {
    return AnimatedScaleIn(
      child: child,
      duration: duration,
      curve: curve,
    );
  }

  // Staggered list animation
  static Widget staggeredList({
    required List<Widget> children,
    Duration duration = const Duration(milliseconds: 300),
    Duration staggerDelay = const Duration(milliseconds: 100),
  }) {
    return AnimatedStaggeredList(
      children: children,
      duration: duration,
      staggerDelay: staggerDelay,
    );
  }

  // Pulse animation for attention-grabbing
  static Widget pulse({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return AnimatedPulse(
      child: child,
      duration: duration,
    );
  }

  // Shimmer loading effect placeholder
  static Widget shimmer({
    required Widget child,
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    return ShimmerLoading(
      child: child,
      duration: duration,
    );
  }
}

/// Animated Fade In
class AnimatedFadeIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedFadeIn({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  }) : super(key: key);

  @override
  State<AnimatedFadeIn> createState() => _AnimatedFadeInState();
}

class _AnimatedFadeInState extends State<AnimatedFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: widget.child,
    );
  }
}

/// Animated Slide In Up
class AnimatedSlideInUp extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final Curve curve;

  const AnimatedSlideInUp({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offset = 50.0,
    this.curve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  State<AnimatedSlideInUp> createState() => _AnimatedSlideInUpState();
}

class _AnimatedSlideInUpState extends State<AnimatedSlideInUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _offset = Tween<Offset>(
      begin: Offset(0, widget.offset / 50),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

/// Animated Slide In Left
class AnimatedSlideInLeft extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final Curve curve;

  const AnimatedSlideInLeft({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offset = 50.0,
    this.curve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  State<AnimatedSlideInLeft> createState() => _AnimatedSlideInLeftState();
}

class _AnimatedSlideInLeftState extends State<AnimatedSlideInLeft> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _offset = Tween<Offset>(
      begin: Offset(widget.offset / 50, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

/// Animated Slide In Right
class AnimatedSlideInRight extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;
  final Curve curve;

  const AnimatedSlideInRight({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.offset = 50.0,
    this.curve = Curves.easeOutCubic,
  }) : super(key: key);

  @override
  State<AnimatedSlideInRight> createState() => _AnimatedSlideInRightState();
}

class _AnimatedSlideInRightState extends State<AnimatedSlideInRight> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: widget.curve);
    _offset = Tween<Offset>(
      begin: Offset(-widget.offset / 50, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: widget.child,
      ),
    );
  }
}

/// Animated Scale In
class AnimatedScaleIn extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Curve curve;

  const AnimatedScaleIn({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.curve = Curves.easeOutBack,
  }) : super(key: key);

  @override
  State<AnimatedScaleIn> createState() => _AnimatedScaleInState();
}

class _AnimatedScaleInState extends State<AnimatedScaleIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

/// Animated Staggered List
class AnimatedStaggeredList extends StatefulWidget {
  final List<Widget> children;
  final Duration duration;
  final Duration staggerDelay;

  const AnimatedStaggeredList({
    Key? key,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
    this.staggerDelay = const Duration(milliseconds: 100),
  }) : super(key: key);

  @override
  State<AnimatedStaggeredList> createState() => _AnimatedStaggeredListState();
}

class _AnimatedStaggeredListState extends State<AnimatedStaggeredList> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = widget.children.asMap().entries.map((entry) {
      return AnimationController(
        duration: widget.duration,
        vsync: this,
      );
    }).toList();

    _animations = _controllers.asMap().entries.map((entry) {
      return CurvedAnimation(
        parent: entry.value,
        curve: Curves.easeOutCubic,
      );
    }).toList();

    Future.forEach<_controllers.isEmpty ? dynamic : dynamic>(_controllers.asMap().entries, (controllerEntry) async {
      await Future.delayed(widget.staggerDelay * controllerEntry.key);
      controllerEntry.value.forward();
    });
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.children.asMap().entries.map((entry) {
        int index = entry.key;
        Widget child = entry.value;
        return FadeTransition(
          opacity: _animations[index],
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(_animations[index]),
            child: child,
          ),
        );
      }).toList(),
    );
  }
}

/// Animated Pulse
class AnimatedPulse extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const AnimatedPulse({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<AnimatedPulse> createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<AnimatedPulse> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.95, end: 1.05).animate(_animation),
      child: widget.child,
    );
  }
}

/// Shimmer Loading Effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const ShimmerLoading({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  }) : super(key: key);

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: const [
            Color(0xFFE0E0E0),
            Color(0xFFF5F5F5),
            Color(0xFFE0E0E0),
          ],
          stops: const [0.0, 0.5, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.topRight,
          transform: _ShimmerGradientTransform(_controller),
        ).createShader(bounds);
      },
      child: widget.child,
    );
  }
}

class _ShimmerGradientTransform extends GradientTransform {
  final Animation<double> _animation;

  _ShimmerGradientTransform(this._animation);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(
      -bounds.width + (_animation.value * bounds.width * 3),
      0,
      0,
    );
  }
}
