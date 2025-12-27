import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that cycles through a list of images with fade transition and pan effect
class FadingImageCarousel extends StatefulWidget {
  /// List of image URLs to cycle through
  final List<String> imageUrls;

  /// Duration to display each image before fading to the next
  final Duration displayDuration;

  /// Duration of the fade transition
  final Duration fadeDuration;

  /// How to fit the images
  final BoxFit fit;

  /// Alignment of the images
  final Alignment alignment;

  /// Optional overlay widget (e.g., dark overlay)
  final Widget? overlay;

  /// Enable panning effect
  final bool enablePan;

  /// Scale factor for pan effect (how much to zoom in for panning room)
  final double panScale;

  const FadingImageCarousel({
    super.key,
    required this.imageUrls,
    this.displayDuration = const Duration(seconds: 8),
    this.fadeDuration = const Duration(milliseconds: 1200),
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.overlay,
    this.enablePan = true,
    this.panScale = 1.25,
  });

  @override
  State<FadingImageCarousel> createState() => _FadingImageCarouselState();
}

class _FadingImageCarouselState extends State<FadingImageCarousel>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  Timer? _timer;
  final Map<int, AnimationController> _panControllers = {};
  final Random _random = Random();
  
  // Random pan directions for each image slot
  final Map<int, Offset> _startOffsets = {};
  final Map<int, Offset> _endOffsets = {};
  
  // Shuffled order of images
  late List<String> _shuffledUrls;

  @override
  void initState() {
    super.initState();
    _shuffleImages();
    _initializePanControllers();
    
    if (_shuffledUrls.length > 1) {
      _startTimer();
    }
    
    // Start the first image's pan animation after frame is built
    if (_shuffledUrls.isNotEmpty && widget.enablePan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _panControllers[0]?.forward();
        }
      });
    }
  }

  void _shuffleImages() {
    _shuffledUrls = List<String>.from(widget.imageUrls)..shuffle(_random);
  }

  void _initializePanControllers() {
    for (int i = 0; i < _shuffledUrls.length; i++) {
      _panControllers[i] = AnimationController(
        vsync: this,
        duration: widget.displayDuration + widget.fadeDuration, // Pan continues through fade
      );
      _generateRandomPanDirection(i);
    }
  }

  void _generateRandomPanDirection(int index) {
    // Random direction for X: -1 (left to right) or 1 (right to left)
    final xDirection = _random.nextBool() ? 1.0 : -1.0;
    // Random direction for Y: -1 (top to bottom) or 1 (bottom to top)
    final yDirection = _random.nextBool() ? 1.0 : -1.0;
    
    _startOffsets[index] = Offset(xDirection, yDirection);
    _endOffsets[index] = Offset(-xDirection, -yDirection);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _panControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    // Transition starts BEFORE pan completes (displayDuration only, not including fade time)
    _timer = Timer.periodic(widget.displayDuration, (_) {
      if (mounted) {
        final nextIndex = (_currentIndex + 1) % _shuffledUrls.length;
        
        // Generate new random direction for this image
        _generateRandomPanDirection(nextIndex);
        
        // Reset and start the next image's pan animation
        _panControllers[nextIndex]?.reset();
        _panControllers[nextIndex]?.forward();
        
        setState(() {
          _currentIndex = nextIndex;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_shuffledUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // All images stacked with animated opacity and pan
          ..._shuffledUrls.asMap().entries.map((entry) {
            final index = entry.key;
            final url = entry.value;
            final isActive = index == _currentIndex;
            final controller = _panControllers[index];

            return AnimatedOpacity(
              opacity: isActive ? 1.0 : 0.0,
              duration: widget.fadeDuration,
              curve: Curves.linear, // No ease in/out for fade
              child: controller != null && widget.enablePan
                  ? _buildPanningImage(url, controller, index)
                  : _buildStaticImage(url),
            );
          }),

          // Overlay
          if (widget.overlay != null) widget.overlay!,
        ],
      ),
    );
  }

  Widget _buildStaticImage(String url) {
    return Image.network(
      url,
      fit: widget.fit,
      alignment: widget.alignment,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPanningImage(
    String url,
    AnimationController controller,
    int index,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate how much we can pan based on the extra size from scaling
        final extraWidth = constraints.maxWidth * (widget.panScale - 1);
        final extraHeight = constraints.maxHeight * (widget.panScale - 1);
        
        // Horizontal pan range (less movement)
        final horizontalPan = extraWidth * 0.3;
        // Vertical pan range (more movement)
        final verticalPan = extraHeight * 1.0;
        
        final startDir = _startOffsets[index] ?? const Offset(1, 1);
        final endDir = _endOffsets[index] ?? const Offset(-1, -1);
        
        final startOffset = Offset(
          startDir.dx * horizontalPan / 2,
          startDir.dy * verticalPan / 2,
        );
        final endOffset = Offset(
          endDir.dx * horizontalPan / 2,
          endDir.dy * verticalPan / 2,
        );

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // Linear progress - no easing
            final progress = controller.value;
            final currentOffset = Offset.lerp(startOffset, endOffset, progress)!;
            
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..translate(currentOffset.dx, currentOffset.dy)
                ..scale(widget.panScale),
              child: child,
            );
          },
          child: Image.network(
            url,
            fit: widget.fit,
            alignment: widget.alignment,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}
