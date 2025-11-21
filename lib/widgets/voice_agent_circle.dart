import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/dimensions.dart';

/// Voice agent circle widget with breathing animation and audio-reactive effects
class VoiceAgentCircle extends StatefulWidget {
  final double size;
  final double audioLevel;
  final bool isActive;
  final AppColorScheme? colors;

  const VoiceAgentCircle({
    super.key,
    this.size = AppDimensions.voiceAgentCircleSize,
    this.audioLevel = 0.0,
    this.isActive = false,
    this.colors,
  });

  @override
  State<VoiceAgentCircle> createState() => _VoiceAgentCircleState();
}

class _VoiceAgentCircleState extends State<VoiceAgentCircle>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;
  late AnimationController _activationController;
  late Animation<double> _colorTransition;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  // For smooth audio level transitions
  double _smoothedAudioLevel = 0.0;

  @override
  void initState() {
    super.initState();

    // Setup breathing animation
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Start infinite breathing animation
    _breathingController.repeat(reverse: true);

    // Setup activation animation (color transition + rotation pulse + scale)
    _activationController = AnimationController(
      duration: const Duration(milliseconds: 450), // 25% faster (600 * 0.75)
      vsync: this,
    );

    _colorTransition = CurvedAnimation(
      parent: _activationController,
      curve: Curves.easeInOut,
    );

    // Rotation: pulse from 0 to 360 degrees during activation
    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _activationController, curve: Curves.easeInOut),
    );

    // Scale: grow to 1.15x and back to 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_activationController);

    // Set initial state
    if (widget.isActive) {
      _activationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(VoiceAgentCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Smooth the audio level transitions
    _smoothedAudioLevel = _smoothedAudioLevel * 0.7 + widget.audioLevel * 0.3;

    // Handle activation state change
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _activationController.forward(from: 0.0);
      } else {
        _activationController.reverse(from: 1.0);
      }
    }
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _activationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate audio-reactive scale (adds to breathing animation)
    final audioScale = 1.0 + (_smoothedAudioLevel * 0.15);
    final colors = widget.colors ?? const AppColorScheme();

    return AnimatedBuilder(
      animation: Listenable.merge([_breathingAnimation, _activationController]),
      builder: (context, child) {
        final totalScale =
            _breathingAnimation.value * audioScale * _scaleAnimation.value;
        final activationValue = _colorTransition.value;

        // Interpolate colors based on activation
        final gradientStart = Color.lerp(
          colors.voiceAgentGradientStartInactive,
          colors.voiceAgentGradientStart,
          activationValue,
        )!;

        final gradientEnd = Color.lerp(
          colors.voiceAgentGradientEndInactive,
          Color.lerp(
            colors.voiceAgentGradientEnd,
            colors.primaryBlue,
            _smoothedAudioLevel * 0.5,
          )!,
          activationValue,
        )!;

        final borderColor = Color.lerp(
          colors.voiceAgentBorderInactive,
          Color.lerp(
            colors.voiceAgentBorder,
            colors.primaryBlue,
            _smoothedAudioLevel,
          )!,
          activationValue,
        )!;

        final shadowColor = Color.lerp(
          colors.buttonGray.withValues(alpha: 0.1),
          colors.primaryBlue.withValues(alpha: 0.1 + _smoothedAudioLevel * 0.3),
          activationValue,
        )!;

        final iconColor = Color.lerp(
          colors.voiceAgentIconInactive,
          colors.voiceAgentIcon,
          activationValue,
        )!;

        return Transform.scale(
          scale: totalScale,
          child: Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159, // Full rotation
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [gradientStart, gradientEnd],
                ),
                border: Border.all(
                  color: borderColor,
                  width:
                      AppDimensions.voiceAgentBorderWidth +
                      (_smoothedAudioLevel * 2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8 + (_smoothedAudioLevel * 20),
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: _SmileyFace(
                  size: AppDimensions.voiceAgentIconSize,
                  color: iconColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple smiley face widget with two eyes and a smile
class _SmileyFace extends StatelessWidget {
  final double size;
  final Color color;

  const _SmileyFace({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    // Calculate proportional sizes
    final eyeSize = size * 0.15;
    final eyeSpacing = size * 0.25;
    final smileWidth = size * 0.4;
    final smileHeight = size * 0.15;
    final smileTopOffset = size * 0.15;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SmileyFacePainter(
          eyeSize: eyeSize,
          eyeSpacing: eyeSpacing,
          smileWidth: smileWidth,
          smileHeight: smileHeight,
          smileTopOffset: smileTopOffset,
          color: color,
        ),
      ),
    );
  }
}

class _SmileyFacePainter extends CustomPainter {
  final double eyeSize;
  final double eyeSpacing;
  final double smileWidth;
  final double smileHeight;
  final double smileTopOffset;
  final Color color;

  _SmileyFacePainter({
    required this.eyeSize,
    required this.eyeSpacing,
    required this.smileWidth,
    required this.smileHeight,
    required this.smileTopOffset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw left eye
    canvas.drawCircle(
      Offset(centerX - eyeSpacing, centerY - eyeSize),
      eyeSize / 2,
      paint,
    );

    // Draw right eye
    canvas.drawCircle(
      Offset(centerX + eyeSpacing, centerY - eyeSize),
      eyeSize / 2,
      paint,
    );

    // Draw smile (curved line)
    final smilePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = eyeSize * 0.3
      ..strokeCap = StrokeCap.round;

    final smilePath = Path();
    final smileStartX = centerX - smileWidth / 2;
    final smileEndX = centerX + smileWidth / 2;
    final smileY = centerY + smileTopOffset;

    // Create a curved smile
    smilePath.moveTo(smileStartX, smileY);
    smilePath.quadraticBezierTo(
      centerX,
      smileY + smileHeight,
      smileEndX,
      smileY,
    );

    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
