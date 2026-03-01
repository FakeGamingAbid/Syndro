import 'package:flutter/material.dart';

/// Slide direction enum
enum SlideDirection { up, down, left, right }

/// Slide-in animation wrapper widget
class SlideAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Curve curve;
  final SlideDirection direction;
  final double offset;

  const SlideAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.direction = SlideDirection.up,
    this.offset = 30.0,
  });

  @override
  State<SlideAnimation> createState() => _SlideAnimationState();
}

class _SlideAnimationState extends State<SlideAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    Offset beginOffset;
    switch (widget.direction) {
      case SlideDirection.up:
        beginOffset = Offset(0, widget.offset / 100);
        break;
      case SlideDirection.down:
        beginOffset = Offset(0, -widget.offset / 100);
        break;
      case SlideDirection.left:
        beginOffset = Offset(widget.offset / 100, 0);
        break;
      case SlideDirection.right:
        beginOffset = Offset(-widget.offset / 100, 0);
        break;
    }

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: widget.curve));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}
