import 'dart:math';
import 'package:flutter/material.dart';

/// A playful animated Shizzie character that peeks in from the bottom of the screen.
///
/// Usage: Add `ShizziePeep()` to a Stack at the bottom of your page.
///
/// Example:
/// ```dart
/// Stack(
///   children: [
///     // Your page content
///     SafeArea(child: YourContent()),
///     // Shizzie peeping animation
///     const ShizziePeep(),
///   ],
/// )
/// ```
class ShizziePeep extends StatefulWidget {
  /// Initial delay before the first animation starts
  final Duration initialDelay;

  /// Duration for the slide-in animation
  final Duration slideInDuration;

  /// Duration for the slide-out animation
  final Duration slideOutDuration;

  /// How long Shizzie stays visible before sliding out
  final Duration visibleDuration;

  /// How long to wait after sliding out before looping
  final Duration loopDelay;

  /// Height of the Shizzie image
  final double imageHeight;

  const ShizziePeep({
    super.key,
    this.initialDelay = const Duration(seconds: 2),
    this.slideInDuration = const Duration(milliseconds: 3000),
    this.slideOutDuration = const Duration(milliseconds: 200),
    this.visibleDuration = const Duration(seconds: 3),
    this.loopDelay = const Duration(seconds: 3),
    this.imageHeight = 120,
  });

  @override
  State<ShizziePeep> createState() => _ShizziePeepState();
}

enum _PeepPosition { bottomLeft, bottomCenter, bottomRight }

class _ShizziePeepState extends State<ShizziePeep>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  final _random = Random();

  _PeepPosition _currentPosition = _PeepPosition.bottomRight;
  bool _isBlinking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.slideInDuration,
      vsync: this,
    );

    _pickRandomPosition();
    _setupAnimation();

    // Start animation after initial delay
    Future.delayed(widget.initialDelay, () {
      _startLoop();
    });
  }

  void _pickRandomPosition() {
    final positions = _PeepPosition.values;
    _currentPosition = positions[_random.nextInt(positions.length)];
  }

  Offset _getStartOffset() {
    switch (_currentPosition) {
      case _PeepPosition.bottomLeft:
        return const Offset(-1, 1); // From bottom-left
      case _PeepPosition.bottomCenter:
        return const Offset(0, 1); // From bottom
      case _PeepPosition.bottomRight:
        return const Offset(1, 1); // From bottom-right
    }
  }

  double _getRotation() {
    switch (_currentPosition) {
      case _PeepPosition.bottomLeft:
        return 0.785398; // 45 degrees
      case _PeepPosition.bottomCenter:
        return 0; // No rotation
      case _PeepPosition.bottomRight:
        return -0.785398; // -45 degrees
    }
  }

  void _setupAnimation() {
    _slideAnimation = Tween<Offset>(
      begin: _getStartOffset(),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      ),
    );
  }

  void _startLoop() {
    if (!mounted) return;

    // Pick a new random position for this loop
    setState(() {
      _pickRandomPosition();
      _setupAnimation();
      _isBlinking = false;
    });

    // Slide in
    _controller.duration = widget.slideInDuration;
    _controller.forward().then((_) {
      if (!mounted) return;

      // Trigger blink 1 second before slide out
      final blinkDelay = widget.visibleDuration - const Duration(seconds: 1);
      if (blinkDelay.inMilliseconds > 0) {
        Future.delayed(blinkDelay, () {
          if (!mounted) return;
          setState(() => _isBlinking = true);
          // Hide blink after 300ms
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) setState(() => _isBlinking = false);
          });
        });
      }

      // Wait, then slide out
      Future.delayed(widget.visibleDuration, () {
        if (!mounted) return;

        // Slide out
        _controller.duration = widget.slideOutDuration;
        _controller.reverse().then((_) {
          if (!mounted) return;

          // Wait, then loop
          Future.delayed(widget.loopDelay, () {
            _startLoop();
          });
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (_currentPosition) {
      case _PeepPosition.bottomLeft:
        return Positioned(
          left: -25,
          bottom: 10,
          child: _buildAnimatedShizzie(),
        );
      case _PeepPosition.bottomCenter:
        return Positioned(
          left: 0,
          right: 0,
          bottom: -20,
          child: Center(child: _buildAnimatedShizzie()),
        );
      case _PeepPosition.bottomRight:
        return Positioned(
          right: -25,
          bottom: 10,
          child: _buildAnimatedShizzie(),
        );
    }
  }

  Widget _buildAnimatedShizzie() {
    return SlideTransition(
      position: _slideAnimation,
      child: Transform.rotate(
        angle: _getRotation(),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/Shizzie-peep.png',
              height: widget.imageHeight,
              fit: BoxFit.contain,
            ),
            if (_isBlinking)
              Image.asset(
                'assets/images/Shizzie-peep-blink.png',
                height: widget.imageHeight,
                fit: BoxFit.contain,
              ),
          ],
        ),
      ),
    );
  }
}
